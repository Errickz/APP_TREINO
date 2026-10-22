/// Configuração de acesso à ExerciseDB_API (RapidAPI).
///
/// Os segredos NÃO são versionados. A chave e o host são lidos em tempo de
/// compilação via `--dart-define`:
///
/// ```sh
/// flutter run \
///   --dart-define=RAPIDAPI_KEY=suachaveaqui \
///   --dart-define=RAPIDAPI_HOST=exercisedb.p.rapidapi.com
/// ```
///
/// Requirement 7.1: a chave e o host são injetados nos cabeçalhos das
/// requisições à ExerciseDB_API pelo `AuthInterceptor`.
/// Requirement 7.2: quando a chave não está configurada, o cliente aborta a
/// requisição e reporta uma falha de configuração de autenticação.
class ApiConfig {
  const ApiConfig({
    required this.rapidApiKey,
    required this.rapidApiHost,
    required this.baseUrl,
  });

  /// Chave de autenticação da RapidAPI (cabeçalho `X-RapidAPI-Key`).
  final String rapidApiKey;

  /// Identificador de host da RapidAPI (cabeçalho `X-RapidAPI-Host`).
  final String rapidApiHost;

  /// URL base da ExerciseDB_API.
  final String baseUrl;

  /// Cria a configuração a partir das variáveis fornecidas por `--dart-define`.
  factory ApiConfig.fromEnvironment() {
    const host = String.fromEnvironment(
      'RAPIDAPI_HOST',
      defaultValue: 'exercisedb.p.rapidapi.com',
    );
    return const ApiConfig(
      rapidApiKey: String.fromEnvironment('RAPIDAPI_KEY'),
      rapidApiHost: host,
      baseUrl: 'https://$host',
    );
  }

  /// Indica se a chave da RapidAPI está configurada (não vazia após trim).
  bool get isConfigured => rapidApiKey.trim().isNotEmpty;
}
