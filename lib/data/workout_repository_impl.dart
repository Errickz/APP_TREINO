import '../domain/app_failure.dart';
import '../domain/workout.dart';
import '../domain/workout_repository.dart';
import '../domain/workout_validation.dart';
import 'cache/cache_store.dart';

/// Exceção lançada por [WorkoutRepositoryImpl.save] quando o treino recebido
/// é inválido para salvamento (Property 9 / Requirements 4.3, 4.4, 4.5, 4.6).
///
/// A hierarquia [AppFailure] do design não define um caso dedicado de
/// validação — por decisão de design, a validação é representada como um
/// resultado retornado por `validateWorkoutForSave`, consumido pela camada de
/// apresentação (`WorkoutBuilderCubit`) para exibir mensagens específicas
/// (sem exercícios / nome inválido) *antes* de chamar [WorkoutRepository.save].
///
/// Esta exceção existe apenas como salvaguarda defensiva do repositório: se um
/// treino inválido chegar ao [save], nada é persistido e esta exceção
/// (portadora do [validation]) é lançada, em vez de [PersistenceError] — pois
/// não houve falha de infraestrutura.
class WorkoutValidationException implements Exception {
  const WorkoutValidationException(this.validation);

  /// Resultado da validação, contendo os motivos ([WorkoutSaveViolation]).
  final WorkoutSaveValidation validation;

  @override
  String toString() =>
      'WorkoutValidationException(violations: ${validation.violations})';
}

/// Implementação de [WorkoutRepository] sobre o [CacheStore] (Requirement 4).
///
/// Responsabilidades:
/// - **Validação defensiva** antes de persistir (Property 9): recusa treinos
///   com nome inválido ou quantidade de exercícios fora de 1..50, lançando
///   [WorkoutValidationException] sem tocar no armazenamento.
/// - **Normalização**: persiste o treino com o nome `trim` aplicado
///   (Requirement 4.4).
/// - **Mapeamento de erro**: envolve qualquer exceção do [CacheStore] em
///   [PersistenceError] (Requirement 4.7), sem mutar o [Workout] informado —
///   o chamador mantém o treino em edição intacto.
class WorkoutRepositoryImpl implements WorkoutRepository {
  WorkoutRepositoryImpl({required CacheStore cacheStore})
      : _cacheStore = cacheStore;

  final CacheStore _cacheStore;

  @override
  Future<void> save(Workout workout) async {
    // 1) Validação pura (não persiste nada se inválido).
    final validation = validateWorkoutForSave(workout);
    if (!validation.isValid) {
      throw WorkoutValidationException(validation);
    }

    // 2) Normaliza o nome persistido (trim aplicado — Requirement 4.4).
    final toPersist = workout.name == validation.trimmedName
        ? workout
        : workout.copyWith(name: validation.trimmedName);

    // 3) Persiste, mapeando qualquer falha de infraestrutura para
    //    PersistenceError (Requirement 4.7). O `workout` informado não é
    //    mutado, de modo que o chamador preserva o treino em edição.
    try {
      await _cacheStore.saveWorkout(toPersist);
    } on PersistenceError {
      rethrow;
    } catch (error) {
      throw PersistenceError(error.toString());
    }
  }

  @override
  Future<List<Workout>> getAll() async {
    try {
      return await _cacheStore.getWorkouts();
    } on PersistenceError {
      rethrow;
    } catch (error) {
      throw PersistenceError(error.toString());
    }
  }

  @override
  Future<Workout?> getById(String id) async {
    try {
      return await _cacheStore.getWorkout(id);
    } on PersistenceError {
      rethrow;
    } catch (error) {
      throw PersistenceError(error.toString());
    }
  }
}
