import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../widgets/gif_view.dart';
import 'workout_runner_cubit.dart';
import 'workout_runner_state.dart';

/// Tela de execução guiada de um treino (Requirement 5).
///
/// Conecta o [WorkoutRunnerCubit] à UI, renderizando dois estados:
/// - [RunnerInProgress]: exibe o exercício atual com seu GIF de demonstração
///   ([GifView], que trata o placeholder em caso de indisponibilidade —
///   Requirement 5.6), o rótulo de posição "k de N" (Requirement 5.1), um
///   botão "Voltar" desabilitado no primeiro exercício (Requirement 5.3) e um
///   botão "Próximo" que avança (Requirement 5.2) ou conclui o treino a partir
///   do último exercício (Requirement 5.5);
/// - [RunnerCompleted]: exibe a tela de conclusão "Treino concluído"
///   (Requirement 5.5).
class WorkoutRunnerPage extends StatelessWidget {
  const WorkoutRunnerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutRunnerCubit, WorkoutRunnerState>(
      builder: (context, state) {
        return switch (state) {
          RunnerInProgress() => _RunnerInProgressView(state: state),
          RunnerCompleted() => _RunnerCompletedView(state: state),
        };
      },
    );
  }
}

/// Exibição de um exercício durante a execução (Requirements 5.1–5.4, 5.6).
class _RunnerInProgressView extends StatelessWidget {
  const _RunnerInProgressView({required this.state});

  final RunnerInProgress state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkoutRunnerCubit>();
    final exercise = state.currentExercise;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.workout.name),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Rótulo de posição "k de N" (Requirement 5.1).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                state.positionLabel,
                key: const Key('workout_runner_position'),
                style: theme.textTheme.labelLarge,
                textAlign: TextAlign.center,
              ),
            ),
            // Área do GIF de demonstração. O GifView trata placeholder e
            // mensagem de indisponibilidade (Requirement 5.6).
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GifView(
                  key: ValueKey<String>('workout_runner_gif_${exercise.id}'),
                  gifUrl: exercise.gifUrl,
                  semanticLabel: exercise.name,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                exercise.name,
                key: const Key('workout_runner_exercise_name'),
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${exercise.bodyPart} • ${exercise.equipment}',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            _NavigationBar(
              // Voltar é desabilitado no primeiro exercício (Requirement 5.3).
              onPrevious: state.canGoBack ? cubit.previous : null,
              onNext: cubit.next,
              isLast: state.isLast,
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de navegação com as ações "Voltar" e "Próximo".
///
/// "Voltar" fica desabilitado quando [onPrevious] é `null` (primeiro
/// exercício — Requirement 5.3). No último exercício, o rótulo de avanço muda
/// para "Concluir", pois avançar leva à conclusão (Requirement 5.5).
class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.onPrevious,
    required this.onNext,
    required this.isLast,
  });

  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('workout_runner_previous_button'),
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Voltar'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              key: const Key('workout_runner_next_button'),
              onPressed: onNext,
              icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
              label: Text(isLast ? 'Concluir' : 'Próximo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tela de conclusão do treino (Requirement 5.5).
class _RunnerCompletedView extends StatelessWidget {
  const _RunnerCompletedView({required this.state});

  final RunnerCompleted state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(state.workout.name)),
      body: Center(
        key: const Key('workout_runner_completed'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.check_circle_outline,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Treino concluído',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
