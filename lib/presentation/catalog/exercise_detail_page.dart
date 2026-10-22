import 'package:flutter/material.dart';

import '../../domain/exercise.dart';
import '../widgets/gif_view.dart';

/// Tela de detalhes de um exercício (Requirement 2).
///
/// Exibe o nome, o grupo muscular alvo (bodyPart), o equipamento necessário e a
/// área de demonstração do GIF animado (Requirements 2.1, 2.2, 2.3, 2.4).
///
/// Como não há um `ExerciseDetailCubit` em escopo nesta tarefa, a página recebe
/// o [Exercise] diretamente pelo construtor e renderiza o [GifView] com a URL
/// do GIF. Os textos (nome, grupo muscular e equipamento) permanecem visíveis
/// ao lado da área do GIF, de modo que continuam exibidos mesmo quando a
/// demonstração está indisponível (Requirement 2.4).
class ExerciseDetailPage extends StatelessWidget {
  const ExerciseDetailPage({
    super.key,
    required this.exercise,
  });

  /// Exercício cujos detalhes serão exibidos.
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Área de demonstração do GIF (Requirements 2.2, 2.3, 2.4).
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GifView(
                    key: const Key('exercise_detail_gif'),
                    gifUrl: exercise.gifUrl,
                    semanticLabel: 'Demonstração do exercício ${exercise.name}',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Nome do exercício (Requirement 2.1).
              Text(
                exercise.name,
                key: const Key('exercise_detail_name'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              // Grupo muscular alvo (Requirement 2.1).
              _DetailRow(
                key: const Key('exercise_detail_body_part'),
                icon: Icons.accessibility_new,
                label: 'Grupo muscular',
                value: exercise.bodyPart,
              ),
              const SizedBox(height: 12),
              // Músculo alvo específico (contexto adicional).
              _DetailRow(
                key: const Key('exercise_detail_target'),
                icon: Icons.center_focus_strong,
                label: 'Músculo alvo',
                value: exercise.target,
              ),
              const SizedBox(height: 12),
              // Equipamento necessário (Requirement 2.1).
              _DetailRow(
                key: const Key('exercise_detail_equipment'),
                icon: Icons.fitness_center,
                label: 'Equipamento',
                value: exercise.equipment,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Linha de detalhe rotulada (ícone + rótulo + valor).
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
