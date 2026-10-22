import 'package:dio/dio.dart';

import '../../domain/app_failure.dart';
import '../config/api_config.dart';

/// Interceptor de autenticação para as requisições à ExerciseDB_API (RapidAPI).
///
/// Responsabilidades (ver design, seção "Política de retry e autenticação"):
/// - **Requirement 7.2 / Property 18**: antes de cada requisição, verifica se a
///   chave da RapidAPI está configurada. Se não estiver, aborta a requisição
///   **sem** enviá-la pela rede e sinaliza [AuthConfigurationError].
/// - **Requirement 7.1 / Property 17**: quando a chave está configurada, injeta
///   os cabeçalhos `X-RapidAPI-Key` e `X-RapidAPI-Host` com os valores de
///   [ApiConfig] em toda requisição antes de prosseguir.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._config);

  final ApiConfig _config;

  /// Nome do cabeçalho que transporta a chave de autenticação da RapidAPI.
  static const String keyHeader = 'X-RapidAPI-Key';

  /// Nome do cabeçalho que identifica o host alvo na RapidAPI.
  static const String hostHeader = 'X-RapidAPI-Host';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // Requirement 7.2 / Property 18: sem chave configurada, aborta antes de
    // qualquer tráfego de rede. `handler.reject` interrompe a cadeia e NÃO
    // despacha a requisição; `DioException` do tipo `unknown` carrega o
    // `AuthConfigurationError` para ser mapeado pela camada de dados.
    if (!_config.isConfigured) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: const AuthConfigurationError(
            'Chave da RapidAPI não configurada.',
          ),
        ),
      );
      return;
    }

    // Requirement 7.1 / Property 17: injeta os cabeçalhos de autenticação em
    // toda requisição que prossegue.
    options.headers[keyHeader] = _config.rapidApiKey;
    options.headers[hostHeader] = _config.rapidApiHost;

    handler.next(options);
  }
}
