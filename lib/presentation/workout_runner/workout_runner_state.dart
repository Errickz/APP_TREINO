import '../../domain/exercise.dart';
import '../../domain/workout.dart';

/// Estados da execução guiada de um treino (Requirement 5).
///
/// A hierarquia é selada: a execução está ou **em andamento**
/// ([RunnerInProgress]) exibindo um exercício na posição atual, ou
/// **concluída** ([RunnerCompleted]) exibindo a tela de conclusão
/// (Requirement 5.5).
sealed class WorkoutRunnerState {
  const WorkoutRunnerState();
}

/// Execução em andamento, posicionada em [currentIndex] dentro de [workout].
///
/// Expõe getters derivados para a UI: o exercício atual, o total de
/// exercícios, o rótulo de posição "k de N" (Requirement 5.1), se é possível
/// voltar (Requirement 5.3 / Property 12) e se é o último exercício.
class RunnerInProgress extends WorkoutRunnerState {
  const RunnerInProgress({
    required this.workout,
    required this.currentIndex,
  });

  /// Treino em execução (não vazio).
  final Workout workout;

  /// Índice do exercício atual (0-based), sempre em `0..total-1`.
  final int currentIndex;

  /// Exercício exibido na posição atual.
  Exercise get currentExercise => workout.exercises[currentIndex];

  /// Total de exercícios do treino.
  int get total => workout.exercises.length;

  /// Rótulo de posição "k de N", 1-based (Requirement 5.1).
  String get positionLabel => '${currentIndex + 1} de $total';

  /// `true` se a ação de voltar está disponível; desabilitada apenas no
  /// índice 0 (Requirement 5.3, Property 12).
  bool get canGoBack => currentIndex > 0;

  /// `true` quando o exercício atual é o último na ordem do treino.
  bool get isLast => currentIndex == total - 1;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RunnerInProgress &&
        other.workout == workout &&
        other.currentIndex == currentIndex;
  }

  @override
  int get hashCode => Object.hash(workout, currentIndex);

  @override
  String toString() =>
      'RunnerInProgress(workout: ${workout.id}, currentIndex: $currentIndex)';
}

/// Tela de conclusão do treino, alcançada ao avançar a partir do último
/// exercício (Requirement 5.5, Property 13).
class RunnerCompleted extends WorkoutRunnerState {
  const RunnerCompleted({required this.workout});

  /// Treino que foi concluído.
  final Workout workout;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RunnerCompleted && other.workout == workout;
  }

  @override
  int get hashCode => workout.hashCode;

  @override
  String toString() => 'RunnerCompleted(workout: ${workout.id})';
}
