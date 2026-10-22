import 'package:glados/glados.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/domain/workout.dart';
import 'package:gym_workout_app/presentation/workout_runner/workout_runner_cubit.dart';
import 'package:gym_workout_app/presentation/workout_runner/workout_runner_state.dart';

Exercise _ex(int i) => Exercise(
      id: 'e$i',
      name: 'Exercise $i',
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$i.gif',
    );

/// Cria um treino não vazio com [n] exercícios (n >= 1).
Workout _workout(int n) => Workout(
      id: 'w',
      name: 'Treino',
      exercises: List<Exercise>.generate(n, _ex),
      savedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );

void main() {
  // Feature: gym-workout-app, Property 10: Estado inicial da execução aponta
  // para o primeiro exercício.
  Glados<int>(any.intInRange(1, 30)).test(
    'Property 10: iniciar posiciona no índice 0, primeiro exercício, "1 de N"',
    (n) {
      final cubit = WorkoutRunnerCubit(_workout(n));
      final state = cubit.state as RunnerInProgress;
      expect(state.currentIndex, 0);
      expect(state.currentExercise, _ex(0));
      expect(state.positionLabel, '1 de $n');
      expect(state.total, n);
      cubit.close();
    },
  );

  // Feature: gym-workout-app, Property 11: Navegação avançar/voltar é
  // consistente e é round-trip na posição.
  Glados2<int, int>(any.intInRange(1, 30), any.intInRange(0, 29)).test(
    'Property 11: next em k<N-1 vai para k+1; previous em k>0 vai para k-1; '
    'next seguido de previous retorna à posição k',
    (n, rawK) {
      final k = n == 1 ? 0 : rawK % n;
      final cubit = WorkoutRunnerCubit(_workout(n));

      // Avança até a posição k.
      for (var i = 0; i < k; i++) {
        cubit.next();
      }
      final atK = cubit.state as RunnerInProgress;
      expect(atK.currentIndex, k);

      if (k < n - 1) {
        // next leva a k+1.
        cubit.next();
        final afterNext = cubit.state as RunnerInProgress;
        expect(afterNext.currentIndex, k + 1);
        // previous retorna a k (round-trip).
        cubit.previous();
        final back = cubit.state as RunnerInProgress;
        expect(back.currentIndex, k);
      }

      if (k > 0) {
        // previous leva a k-1.
        cubit.previous();
        final afterPrev = cubit.state as RunnerInProgress;
        expect(afterPrev.currentIndex, k - 1);
        // next retorna a k (round-trip).
        cubit.next();
        final back = cubit.state as RunnerInProgress;
        expect(back.currentIndex, k);
      }
      cubit.close();
    },
  );

  // Feature: gym-workout-app, Property 12: Ação de voltar é desabilitada
  // apenas no primeiro exercício.
  Glados2<int, int>(any.intInRange(1, 30), any.intInRange(0, 29)).test(
    'Property 12: canGoBack é false sse currentIndex == 0',
    (n, rawK) {
      final k = n == 1 ? 0 : rawK % n;
      final cubit = WorkoutRunnerCubit(_workout(n));
      for (var i = 0; i < k; i++) {
        cubit.next();
      }
      final state = cubit.state as RunnerInProgress;
      expect(state.canGoBack, k != 0);

      // previous no índice 0 é no-op.
      if (k == 0) {
        cubit.previous();
        expect(cubit.state, isA<RunnerInProgress>());
        expect((cubit.state as RunnerInProgress).currentIndex, 0);
      }
      cubit.close();
    },
  );

  // Feature: gym-workout-app, Property 13: Avançar a partir do último
  // exercício conclui o treino.
  Glados<int>(any.intInRange(1, 30)).test(
    'Property 13: next a partir da última posição transiciona para concluído',
    (n) {
      final cubit = WorkoutRunnerCubit(_workout(n));
      // Avança até a última posição (N-1).
      for (var i = 0; i < n - 1; i++) {
        cubit.next();
      }
      expect((cubit.state as RunnerInProgress).currentIndex, n - 1);
      // Avançar do último conclui o treino.
      cubit.next();
      expect(cubit.state, isA<RunnerCompleted>());
      cubit.close();
    },
  );
}
