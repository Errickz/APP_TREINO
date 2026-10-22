import 'dart:async';

import 'package:dio/dio.dart';

import '../../domain/app_failure.dart';

/// Assinatura de uma função de atraso injetável.
///
/// Recebe a [Duration] a aguardar e devolve um [Future] concluído após o
/// intervalo. O padrão usa [Future.delayed]; os testes (Property 19) injetam
/// um relógio/temporizador falso para evitar esperas reais.
typedef DelayFn = Future<void> Function(Duration duration);

/// Assinatura de um executor de nova tentativa, que refaz a requisição
/// descrita por [options] e devolve a [Response] correspondente (ou lança
/// [DioException] em caso de falha). Injetável para testes determinísticos da
/// política de retry (Property 19).
typedef RetryExecutor = Future<Response<dynamic>> Function(
  RequestOptions options,
);

/// Interceptor de [Dio] responsável pela política de retry de rede e pelo
/// mapeamento de status HTTP para erros de domínio ([AppFailure]).
///
/// Comportamento (Requirements 7.3, 7.4, 7.5, 7.6 — design "Política de retry
/// e autenticação" e Property 19):
///
/// - **Erros de rede** (`connectionTimeout`, `receiveTimeout`, `sendTimeout`,
///   `connectionError` e falhas de transporte transitórias): realiza até
///   [maxRetries] novas tentativas (padrão 2, totalizando 3 chamadas),
///   aguardando no máximo [maxDelay] (padrão 3s) entre tentativas. Esgotadas
///   as tentativas, rejeita com [DioException] cujo `error` é um
///   [NetworkError] (Requirements 7.5, 7.6).
/// - **Respostas HTTP** (`badResponse`): **não** são retentadas. Os códigos de
///   status são mapeados: 401/403 → [AuthError] (Requirement 7.3); 429 →
///   [RateLimitError] (Requirement 7.4). Demais status seguem o fluxo normal.
/// - **`AuthConfigurationError`** proveniente do `AuthInterceptor` (chave
///   ausente) é propagado sem retry.
///
/// A contagem de tentativas, o atraso máximo e a função de atraso são
/// injetáveis via construtor para permitir testes determinísticos com um
/// temporizador falso (Property 19).
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    this.maxRetries = 2,
    this.maxDelay = const Duration(seconds: 3),
    DelayFn? delay,
    RetryExecutor? retryExecutor,
  })  : assert(maxRetries >= 0, 'maxRetries não pode ser negativo'),
        assert(!maxDelay.isNegative, 'maxDelay não pode ser negativo'),
        _delay = delay ?? Future.delayed,
        _retryExecutor = retryExecutor ?? _defaultRetryExecutor;

  /// Executor usado para refazer a requisição em uma nova tentativa.
  ///
  /// Por padrão ([_defaultRetryExecutor]), usa uma instância [Dio] descartável
  /// que compartilha as [BaseOptions] da requisição original. Os testes podem
  /// injetar um executor que usa um transporte mockado para validar a política
  /// de retry de forma determinística (Property 19).
  final RetryExecutor _retryExecutor;

  /// Número máximo de novas tentativas após a chamada original (padrão 2).
  final int maxRetries;

  /// Intervalo máximo aguardado entre tentativas (padrão 3 segundos —
  /// Requirement 7.5).
  final Duration maxDelay;

  final DelayFn _delay;

  /// Chave usada para contar tentativas em [RequestOptions.extra].
  static const String _attemptKey = 'retry_attempt';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // 1) Respostas HTTP não são retentadas; mapeia status para AppFailure.
    final mappedFailure = _mapStatusFailure(err);
    if (mappedFailure != null) {
      return handler.reject(_withError(err, mappedFailure));
    }

    // 2) Propaga erros que já carregam um AppFailure (ex.: AuthConfigurationError
    //    vindo do AuthInterceptor) sem nova tentativa.
    if (err.error is AppFailure) {
      return handler.reject(err);
    }

    // 3) Erros de rede transitórios: retenta até esgotar as tentativas.
    if (_isNetworkError(err)) {
      final attempt = (err.requestOptions.extra[_attemptKey] as int?) ?? 0;

      if (attempt < maxRetries) {
        await _delay(maxDelay);
        try {
          final options = err.requestOptions;
          options.extra[_attemptKey] = attempt + 1;
          final response = await _retry(err, options);
          return handler.resolve(response);
        } on DioException catch (retryErr) {
          // Reencaminha o erro da nova tentativa pela cadeia de interceptors,
          // permitindo tentativas subsequentes e o mapeamento final.
          return onError(retryErr, handler);
        }
      }

      // Tentativas esgotadas: propaga falha de comunicação (Requirement 7.6).
      return handler.reject(
        _withError(err, const NetworkError('Falha de comunicação com o serviço de exercícios.')),
      );
    }

    // 4) Demais erros seguem inalterados.
    return handler.reject(err);
  }

  /// Executa uma nova tentativa da requisição original, delegando ao
  /// [_retryExecutor] injetado (ou ao executor padrão).
  Future<Response<dynamic>> _retry(
    DioException err,
    RequestOptions options,
  ) {
    return _retryExecutor(options);
  }

  /// Executor padrão: usa uma instância [Dio] descartável que compartilha as
  /// mesmas [BaseOptions] do emissor original, preservando `baseUrl` e
  /// timeouts.
  static Future<Response<dynamic>> _defaultRetryExecutor(
    RequestOptions options,
  ) {
    final dio = Dio(BaseOptions(
      baseUrl: options.baseUrl,
      connectTimeout: options.connectTimeout,
      receiveTimeout: options.receiveTimeout,
      sendTimeout: options.sendTimeout,
      responseType: options.responseType,
      headers: options.headers,
    ));
    return dio.fetch<dynamic>(options);
  }

  /// Mapeia o status HTTP de uma resposta de erro para um [AppFailure], quando
  /// aplicável. Retorna `null` quando não há status a mapear (erro de rede).
  AppFailure? _mapStatusFailure(DioException err) {
    final status = err.response?.statusCode;
    if (status == null) return null;

    switch (status) {
      case 401:
      case 403:
        return const AuthError('Falha de autenticação com o serviço de exercícios.');
      case 429:
        return const RateLimitError('Limite de requisições excedido.');
      default:
        return null;
    }
  }

  /// Indica se o erro corresponde a uma falha de rede/transporte transitória
  /// elegível para nova tentativa.
  bool _isNetworkError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.unknown:
        // `unknown` com causa de SocketException também é falha de transporte.
        return err.response == null;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
        return false;
      default:
        // Outros tipos (ex.: transformTimeout em versões mais novas do dio)
        // não são falhas de transporte retentáveis.
        return false;
    }
  }

  /// Cria uma cópia de [err] substituindo apenas o campo `error`.
  DioException _withError(DioException err, AppFailure failure) {
    return err.copyWith(error: failure);
  }
}
