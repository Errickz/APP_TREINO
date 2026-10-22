import 'package:dio/dio.dart';
import 'package:glados/glados.dart';
import 'package:gym_workout_app/data/config/api_config.dart';
import 'package:gym_workout_app/data/remote/auth_interceptor.dart';
import 'package:gym_workout_app/data/remote/retry_interceptor.dart';
import 'package:gym_workout_app/domain/app_failure.dart';

/// Adaptador que sempre falha com um erro de rede (connectionError) e conta
/// quantas vezes foi invocado. Usado para validar a política de retry.
class _FailingAdapter implements HttpClientAdapter {
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: 'network down',
    );
  }
}

/// Adaptador que captura os cabeçalhos da requisição e devolve 200.
class _CapturingAdapter implements HttpClientAdapter {
  Map<String, List<String>>? capturedHeaders;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedHeaders = {
      for (final entry in options.headers.entries)
        entry.key: <String>[entry.value.toString()],
    };
    return ResponseBody.fromString('[]', 200, headers: {
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });
  }
}

void main() {
  // Feature: gym-workout-app, Property 17: Toda requisição à API inclui os
  // cabeçalhos de autenticação da RapidAPI.
  Glados2<String, String>(
    any.nonEmptyLetters,
    any.nonEmptyLetters,
  ).test(
    'Property 17: com a chave configurada, toda requisição carrega '
    'X-RapidAPI-Key e X-RapidAPI-Host com os valores configurados',
    (key, host) async {
      final config = ApiConfig(
        rapidApiKey: key,
        rapidApiHost: host,
        baseUrl: 'https://$host',
      );
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://$host'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(config));

      await dio.get<dynamic>('/exercises');

      final headers = adapter.capturedHeaders!;
      expect(headers[AuthInterceptor.keyHeader]?.single, key);
      expect(headers[AuthInterceptor.hostHeader]?.single, host);
    },
  );

  // Feature: gym-workout-app, Property 18: Ausência de chave aborta a
  // requisição com falha de configuração.
  Glados<String>(
    // Chaves "ausentes": vazia ou apenas espaços.
    any.choose(<String>['', ' ', '   ', '\t']),
  ).test(
    'Property 18: sem chave configurada, nenhuma requisição é enviada e o '
    'resultado é AuthConfigurationError',
    (emptyKey) async {
      const host = 'exercisedb.p.rapidapi.com';
      final config = ApiConfig(
        rapidApiKey: emptyKey,
        rapidApiHost: host,
        baseUrl: 'https://$host',
      );
      final adapter = _CapturingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://$host'))
        ..httpClientAdapter = adapter
        ..interceptors.add(AuthInterceptor(config));

      Object? caught;
      try {
        await dio.get<dynamic>('/exercises');
      } on DioException catch (e) {
        caught = e.error;
      }

      // Nenhuma requisição foi despachada ao adaptador.
      expect(adapter.capturedHeaders, isNull);
      // O erro é uma falha de configuração de autenticação.
      expect(caught, isA<AuthConfigurationError>());
    },
  );

  // Feature: gym-workout-app, Property 19: Falha de rede dispara no máximo 2
  // novas tentativas e propaga erro de comunicação.
  //
  // A política de retry é determinística e não depende de entradas geradas
  // (a invariante é sobre a contagem de tentativas), então é validada por um
  // único caso determinístico, conforme permitido pelo design.
  test(
    'Property 19: em falha persistente de rede, são feitas 3 chamadas no total '
    '(1 + 2 retries) e o resultado é NetworkError',
    () async {
      final adapter = _FailingAdapter();
      // Dio de retry que compartilha o MESMO adaptador falho, de modo que as
      // novas tentativas sejam contabilizadas pelo adaptador.
      final retryDio = Dio(BaseOptions(baseUrl: 'https://example.com'))
        ..httpClientAdapter = adapter;

      final dio = Dio(BaseOptions(baseUrl: 'https://example.com'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          RetryInterceptor(
            maxRetries: 2,
            // Delay instantâneo para não atrasar o teste (relógio falso).
            delay: (_) async {},
            // Executor de retry usa o mesmo adaptador falho.
            retryExecutor: (options) => retryDio.fetch<dynamic>(options),
          ),
        );

      Object? caught;
      try {
        await dio.get<dynamic>('/exercises');
      } on DioException catch (e) {
        caught = e.error;
      }

      // 1 chamada original + 2 novas tentativas = 3 chamadas ao transporte.
      expect(adapter.calls, 3);
      // Resultado final é falha de comunicação.
      expect(caught, isA<NetworkError>());
    },
  );
}
