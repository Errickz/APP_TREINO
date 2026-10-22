import 'app_failure.dart';
import 'workout.dart';

/// Contrato de persistência de treinos (Requirement 4).
///
/// Abstrai o armazenamento local de treinos consumido pelo
/// `WorkoutBuilderCubit`. A implementação concreta
/// (`WorkoutRepositoryImpl`) delega ao `CacheStore` (SQLite) e mapeia falhas
/// de infraestrutura para [AppFailure].
///
/// Contrato de validação:
/// - [save] assume receber um [Workout] **já válido**. Ainda assim, revalida
///   defensivamente (nome 1..60 após `trim`; 1..50 exercícios — Property 9) e
///   recusa persistir um treino inválido. A camada de apresentação deve usar
///   `validateWorkoutForSave`/`validateWorkoutFields` para apresentar
///   mensagens específicas (nome inválido / sem exercícios) antes de chamar
///   [save] (Requirements 4.5, 4.6).
///
/// Contrato de erro:
/// - Em caso de falha ao persistir, [save] lança [PersistenceError]
///   (Requirement 4.7). O chamador mantém o treino em edição sem perda de
///   dados, pois [save] não muta o [Workout] informado.
abstract class WorkoutRepository {
  /// Persiste [workout] (nome com `trim` aplicado) no armazenamento local e
  /// retorna quando a operação é concluída com sucesso.
  ///
  /// Lança [PersistenceError] se a persistência falhar (Requirement 4.7).
  Future<void> save(Workout workout);

  /// Retorna todos os treinos persistidos, cada um com sua sequência ordenada
  /// de exercícios preservada (Requirement 4.3).
  Future<List<Workout>> getAll();

  /// Retorna o treino identificado por [id], ou `null` se não existir.
  Future<Workout?> getById(String id);
}
