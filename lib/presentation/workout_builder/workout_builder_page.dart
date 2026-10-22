import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/exercise.dart';
import 'workout_builder_cubit.dart';
import 'workout_builder_state.dart';

/// Tela de montagem de um treino (Requirement 4).
///
/// Conecta o [WorkoutBuilderCubit] à UI permitindo:
/// - nomear o treino via um [TextField] -> [WorkoutBuilderCubit.setName]
///   (Requirement 4.4);
/// - visualizar a lista ordenada de exercícios adicionados, preservando a
///   ordem de inserção (Requirement 4.1), com uma ação de remover por item
///   -> [WorkoutBuilderCubit.removeAt] (Requirement 4.2);
/// - adicionar exercícios por meio de um callback [onAddExercise] fornecido
///   pela composição de telas (ex.: abrir um seletor/busca). Quando ausente,
///   o botão de adicionar fica oculto, pois não há wiring de seletor neste
///   nível (mantido mínimo e documentado);
/// - salvar o treino -> [WorkoutBuilderCubit.save], exibindo uma confirmação
///   "Treino salvo" via [SnackBar] em sucesso (Requirement 4.3) ou a mensagem
///   de erro de validação/persistência (Requirements 4.5, 4.6, 4.7).
///
/// O botão "Salvar" exibe um indicador de progresso e fica desabilitado
/// enquanto [WorkoutBuilderState.isSaving] é `true` (Requirement 4.3).
class WorkoutBuilderPage extends StatefulWidget {
  const WorkoutBuilderPage({
    super.key,
    this.onAddExercise,
    this.title = 'Montar treino',
  });

  /// Callback acionado quando o usuário solicita adicionar um exercício.
  ///
  /// A composição que hospeda esta página é responsável por apresentar um
  /// seletor/busca e retornar o [Exercise] escolhido (ou `null` se cancelado).
  /// O exercício retornado é adicionado ao final da lista via
  /// [WorkoutBuilderCubit.addExercise] (Requirement 4.1). Quando `null`, a
  /// ação de adicionar não é exibida.
  final Future<Exercise?> Function(BuildContext context)? onAddExercise;

  /// Título exibido na [AppBar].
  final String title;

  @override
  State<WorkoutBuilderPage> createState() => _WorkoutBuilderPageState();
}

class _WorkoutBuilderPageState extends State<WorkoutBuilderPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final initialName = context.read<WorkoutBuilderCubit>().state.name;
    _nameController = TextEditingController(text: initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleAddExercise() async {
    final onAddExercise = widget.onAddExercise;
    if (onAddExercise == null) return;

    final cubit = context.read<WorkoutBuilderCubit>();
    final exercise = await onAddExercise(context);
    if (exercise != null) {
      cubit.addExercise(exercise);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutBuilderCubit, WorkoutBuilderState>(
      // Reage apenas a transições relevantes para feedback transitório
      // (confirmação de salvamento ou mensagem de erro).
      listenWhen: (previous, current) =>
          previous.isSaved != current.isSaved ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state.isSaved) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text('Treino salvo')),
            );
        } else if (state.errorMessage != null) {
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
        }
      },
      builder: (context, state) {
        final cubit = context.read<WorkoutBuilderCubit>();
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          floatingActionButton: widget.onAddExercise == null
              ? null
              : FloatingActionButton.extended(
                  key: const Key('workout_builder_add_fab'),
                  onPressed: _handleAddExercise,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar exercício'),
                ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  key: const Key('workout_builder_name_field'),
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do treino',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 60,
                  // Requirement 4.4: o nome em edição é propagado ao cubit.
                  onChanged: cubit.setName,
                ),
              ),
              Expanded(
                child: _ExerciseList(
                  exercises: state.exercises,
                  onRemove: cubit.removeAt,
                ),
              ),
              _SaveBar(
                isSaving: state.isSaving,
                onSave: state.isSaving ? null : cubit.save,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Lista ordenada dos exercícios adicionados ao treino em edição.
///
/// Exibe os itens na ordem de inserção (Requirement 4.1). Cada item possui
/// uma ação de remover que chama [onRemove] com a respectiva posição
/// (Requirement 4.2). Quando vazia, exibe uma orientação ao usuário.
class _ExerciseList extends StatelessWidget {
  const _ExerciseList({
    required this.exercises,
    required this.onRemove,
  });

  final List<Exercise> exercises;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) {
      return const Center(
        key: Key('workout_builder_empty'),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum exercício adicionado ainda.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('workout_builder_exercise_list'),
      itemCount: exercises.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return ListTile(
          key: ValueKey<String>('workout_builder_item_${exercise.id}_$index'),
          leading: CircleAvatar(child: Text('${index + 1}')),
          title: Text(exercise.name),
          subtitle: Text('${exercise.bodyPart} • ${exercise.equipment}'),
          trailing: IconButton(
            key: Key('workout_builder_remove_$index'),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Remover',
            onPressed: () => onRemove(index),
          ),
        );
      },
    );
  }
}

/// Barra inferior com o botão "Salvar".
///
/// Exibe um indicador de progresso e desabilita o botão enquanto o salvamento
/// está em andamento (Requirement 4.3).
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.isSaving,
    required this.onSave,
  });

  final bool isSaving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          key: const Key('workout_builder_save_button'),
          onPressed: onSave,
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ),
    );
  }
}
