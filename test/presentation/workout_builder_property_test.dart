import 'package:glados/glados.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/domain/workout.dart';
import 'package:gym_workout_app/domain/workout_repository.dart';
import 'package:gym_workout_app/presentation/workout_builder/workout_builder_cubit.dart';

/// Repositório falso que não persiste nada (os testes de add/remove não salvam).
class _NoopWorkoutRepository implements WorkoutRepository {
  @override
  Future<void> save(Workout workout) async {}

  @override
  Future<List<Workout>> getAll() async => const <Workout>[];

  @override
  Future<Workout?> getById(String id) async => null;
}

Exercise _ex(int i) => Exercise(
      id: 'e$i',
      name: 'Exercise $i',
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$i.gif',
    );

WorkoutBuilderCubit _cubit() =>
    WorkoutBuilderCubit(repository: _NoopWorkoutRepository());

void main() {
  // Feature: gym-workout-app, Property 6: Adicionar exercício insere ao final
  // preservando a ordem existente.
  Glados2<int, int>(any.intInRange(0, 20), any.int).test(
    'Property 6: addExercise aumenta o tamanho em 1, mantém o prefixo e põe o '
    'novo exercício no final',
    (existing, newId) {
      final cubit = _cubit();
      final before = <Exercise>[
        for (var i = 0; i < existing; i++) _ex(i),
      ];
      for (final e in before) {
        cubit.addExercise(e);
      }
      final newExercise = _ex(1000 + (newId.abs() % 100000));

      cubit.addExercise(newExercise);

      final after = cubit.state.exercises;
      expect(after.length, before.length + 1);
      expect(after.sublist(0, before.length), equals(before));
      expect(after.last, newExercise);
      cubit.close();
    },
  );

  // Feature: gym-workout-app, Property 7: Remover exercício mantém ordem
  // contígua sem lacunas.
  Glados2<int, int>(any.intInRange(1, 20), any.int).test(
    'Property 7: removeAt remove a posição e preserva a ordem relativa dos '
    'remanescentes sem lacunas',
    (count, rawIndex) {
      final cubit = _cubit();
      final before = <Exercise>[
        for (var i = 0; i < count; i++) _ex(i),
      ];
      for (final e in before) {
        cubit.addExercise(e);
      }
      final index = rawIndex.abs() % count;

      cubit.removeAt(index);

      final after = cubit.state.exercises;
      final expected = <Exercise>[...before]..removeAt(index);
      expect(after, equals(expected));
      expect(after.length, before.length - 1);
      cubit.close();
    },
  );
}
