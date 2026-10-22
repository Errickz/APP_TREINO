/// Hierarquia de erros de domínio consumida pelos Cubits e exibida de forma
/// consistente na UI.
///
/// Os repositórios mapeiam falhas de infraestrutura (rede, autenticação,
/// persistência) para estes tipos. Por ser uma `sealed class`, o compilador
/// garante que o `switch` sobre um [AppFailure] seja exaustivo, cobrindo todos
/// os casos de erro previstos no design.
///
/// Mapeamento de requisitos:
/// - [TimeoutError] — Requirement 1.6
/// - [AuthConfigurationError] — Requirement 7.2
/// - [AuthError] — Requirement 7.3
/// - [RateLimitError] — Requirement 7.4
/// - [NetworkError] — Requirement 7.6
/// - [OfflineUnavailableError] — Requirement 6.5
/// - [PersistenceError] — Requirement 4.7
sealed class AppFailure {
  const AppFailure([this.message]);

  /// Mensagem opcional com detalhes para diagnóstico/log.
  final String? message;
}

/// Tempo limite de 10 segundos excedido ao carregar dados da rede.
///
/// Requirement 1.6.
class TimeoutError extends AppFailure {
  const TimeoutError([super.message]);
}

/// A chave da RapidAPI não está configurada; a requisição é abortada sem
/// tráfego de rede.
///
/// Requirement 7.2.
class AuthConfigurationError extends AppFailure {
  const AuthConfigurationError([super.message]);
}

/// A ExerciseDB_API retornou erro de autenticação (HTTP 401/403).
///
/// Requirement 7.3.
class AuthError extends AppFailure {
  const AuthError([super.message]);
}

/// A ExerciseDB_API retornou erro de limite de requisições (HTTP 429).
///
/// Requirement 7.4.
class RateLimitError extends AppFailure {
  const RateLimitError([super.message]);
}

/// Falha de comunicação após esgotar as tentativas de retry de rede.
///
/// Requirement 7.6.
class NetworkError extends AppFailure {
  const NetworkError([super.message]);
}

/// Dispositivo offline e o exercício solicitado não está em cache.
///
/// Requirement 6.5.
class OfflineUnavailableError extends AppFailure {
  const OfflineUnavailableError([super.message]);
}

/// Falha ao persistir um treino no armazenamento local.
///
/// Requirement 4.7.
class PersistenceError extends AppFailure {
  const PersistenceError([super.message]);
}
