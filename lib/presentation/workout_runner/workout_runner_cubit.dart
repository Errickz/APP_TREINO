import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/workout.dart';
import 'workout_runner_state.dart';

/// Cubit que controla a execução guiada de um treino (Requirement 5).
///
/// Mantém o índice do exercício atual e a navegação determinística entre
/// exercícios:
/// - inicia no primeiro exercício, posição "1 de N" (Requirement 5.1,
///   Property 10);
/// - [next] avança para o próximo exercício ou conclui o treino a partir do
///   último (Requirements 5.2, 5.5; Properties 11, 13);
/// - [previous] retorna ao exercício anterior; é um no-op no índice 0, pois a
///   ação de voltar é desabilitada no primeiro exercício (Requirements 5.3,
///   5.4; Properties 11, 12).
///
/// A combinação [next] seguida de [previous] (quando ambas são permitidas)
/// retorna à posição original (Property 11).
class WorkoutRunnerCubit extends Cubit<WorkoutRunnerState> {
  /// Inicia a execução de [workout] no primeiro exercício.
  ///
  /// Lança [ArgumentError] se o treino não possuir exercícios, pois a
  /// execução guiada pressupõe um treino não vazio (Requirement 5.1).
  WorkoutRunnerCubit(Workout workout)
      : assert(
          workout.exercises.isNotEmpty,
          'A execução requer um treino com ao menos um exercício.',
        ),
        super(RunnerInProgress(workout: workout, currentIndex: 0)) {
    if (workout.exercises.isEmpty) {
      throw ArgumentError.value(
        workout,
        'workout',
        'A execução requer um treino com ao menos um exercício.',
      );
    }
  }

  /// Avança para o próximo exercício na ordem do treino.
  ///
  /// Se o exercício atual não for o último, move para o índice seguinte
  /// (Requirement 5.2). Se já for o último, transiciona para o estado de
  /// conclusão (Requirement 5.5, Property 13). Ignorada quando o treino já
  /// está concluído.
  void next() {
    final current = state;
    if (current is! RunnerInProgress) return;

    if (current.isLast) {
      emit(RunnerCompleted(workout: current.workout));
    } else {
      emit(
        RunnerInProgress(
          workout: current.workout,
          currentIndex: current.currentIndex + 1,
        ),
      );
    }
  }

  /// Retorna ao exercício anterior na ordem do treino.
  ///
  /// Move para o índice anterior quando não está no primeiro exercício
  /// (Requirement 5.4). No índice 0 é um no-op, pois a ação de voltar está
  /// desabilitada (Requirement 5.3, Property 12). Ignorada quando o treino
  /// já está concluído.
  void previous() {
    final current = state;
    if (current is! RunnerInProgress) return;
    if (!current.canGoBack) return;

    emit(
      RunnerInProgress(
        workout: current.workout,
        currentIndex: current.currentIndex - 1,
      ),
    );
  }
}
