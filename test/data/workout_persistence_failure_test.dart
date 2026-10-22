import 'package:flutter_test/flutter_test.dart';
import 'package:gym_workout_app/domain/app_failure.dart';
import 'package:gym_workout_app/domain/cached_exercise.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/domain/workout.dart';
import 'package:gym_workout_app/data/cache/cache_store.dart';
import 'package:gym_workout_app/data/workout_repository_impl.dart';

/// CacheStore que lança uma exceção ao salvar, simulando falha de persistência.
class _ThrowingCacheStore implements CacheStore {
  @override
  Future<void> saveWorkout(Workout workout) async {
    throw Exception('disco cheio');
  }

  // Demais operações não são usadas neste teste.
  @override
  Future<CachedExercise?> getExercise(String id) async => null;
  @override
  Future<List<CachedExercise>> getAllExercises() async => const [];
  @override
  Future<void> upsertExercise(Exercise exercise, DateTime storedAt) async {}
  @override
  Future<void> touchExercise(String id, DateTime accessedAt) async {}
  @override
  Future<int> countExercises() async => 0;
  @override
  Future<void> evictLeastRecentlyAccessed(int howMany) async {}
  @override
  Future<List<Workout>> getWorkouts() async => const [];
  @override
  Future<Workout?> getWorkout(String id) async => null;
  @override
  Future<void> close() async {}
}

Exercise _ex(int i) => Exercise(
      id: 'e$i',
      name: 'Exercise $i',
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$i.gif',
    );

void main() {
  // Requirement 4.7: falha ao persistir mantém o treino em edição e sinaliza
  // PersistenceError.
  test(
    'save mapeia falha do CacheStore para PersistenceError e não altera o '
    'treino informado',
    () async {
      final repo = WorkoutRepositoryImpl(cacheStore: _ThrowingCacheStore());
      final workout = Workout(
        id: 'w1',
        name: 'Treino Peito',
        exercises: <Exercise>[_ex(0), _ex(1)],
        savedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      Object? caught;
      try {
        await repo.save(workout);
      } on AppFailure catch (e) {
        caught = e;
      }

      // Falha de persistência sinalizada como PersistenceError (Req 4.7).
      expect(caught, isA<PersistenceError>());

      // O treino em edição permanece intacto (não foi mutado pelo repositório).
      expect(workout.name, 'Treino Peito');
      expect(workout.exercises, <Exercise>[_ex(0), _ex(1)]);
    },
  );
}
