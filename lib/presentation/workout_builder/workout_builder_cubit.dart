import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/workout_repository_impl.dart';
import '../../domain/app_failure.dart';
import '../../domain/exercise.dart';
import '../../domain/workout.dart';
import '../../domain/workout_repository.dart';
import '../../domain/workout_validation.dart';
import 'workout_builder_state.dart';

/// Gera um identificador para o treino a ser persistido.
typedef WorkoutIdGenerator = String Function();

/// Fornece o instante de salvamento (`savedAt`) do treino.
typedef Clock = DateTime Function();

/// Mensagens de orientação/erro apresentadas pela UI.
///
/// Centralizadas para consistência e para facilitar testes (Requirements 4.5,
/// 4.6, 4.7).
class WorkoutBuilderMessages {
  const WorkoutBuilderMessages._();

  /// Sem nenhum exercício (Requirement 4.5).
  static const String emptyExercises =
      'Adicione ao menos um exercício ao treino.';

  /// Nome vazio/apenas espaços ou fora do limite de 1..60 (Requirement 4.6).
  static const String invalidName = 'Informe um nome válido para o treino.';

  /// Mais de 50 exercícios (Requirement 4.3).
  static const String tooManyExercises =
      'O treino pode ter no máximo 50 exercícios.';

  /// Falha ao persistir o treino (Requirement 4.7).
  static const String persistenceFailure =
      'Não foi possível salvar o treino. Tente novamente.';
}

/// Cubit responsável pela montagem de um treino em edição (Requirement 4).
///
/// Gerencia a lista ordenada de exercícios (adicionar ao final / remover com
/// reordenação contígua), a validação de salvamento e a persistência via
/// [WorkoutRepository].
///
/// As operações [addExercise] e [removeAt] são puras e determinísticas sobre a
/// lista de exercícios do estado — alvos das Properties 6 e 7.
///
/// Um [WorkoutIdGenerator] e um [Clock] são injetáveis para tornar o
/// salvamento determinístico e testável (id e `savedAt`).
class WorkoutBuilderCubit extends Cubit<WorkoutBuilderState> {
  WorkoutBuilderCubit({
    required WorkoutRepository repository,
    WorkoutIdGenerator? idGenerator,
    Clock? clock,
  })  : _repository = repository,
        _idGenerator = idGenerator ?? _defaultIdGenerator,
        _clock = clock ?? DateTime.now,
        super(WorkoutBuilderState.initial());

  final WorkoutRepository _repository;
  final WorkoutIdGenerator _idGenerator;
  final Clock _clock;

  static String _defaultIdGenerator() =>
      DateTime.now().microsecondsSinceEpoch.toString();

  /// Adiciona [exercise] ao **final** da lista, preservando a ordem dos
  /// exercícios já existentes (Property 6, Requirement 4.1).
  void addExercise(Exercise exercise) {
    final updated = <Exercise>[...state.exercises, exercise];
    _emitWithExercises(updated);
  }

  /// Remove o exercício na posição [index] e mantém a ordem contígua
  /// (posições 0..n-2) preservando a ordem relativa dos remanescentes
  /// (Property 7, Requirement 4.2).
  ///
  /// Índices fora dos limites são ignorados (nenhuma mudança de estado).
  void removeAt(int index) {
    if (index < 0 || index >= state.exercises.length) {
      return;
    }
    final updated = <Exercise>[...state.exercises]..removeAt(index);
    _emitWithExercises(updated);
  }

  /// Atualiza o nome em edição e recomputa o snapshot de validação.
  void setName(String name) {
    emit(
      state.copyWith(
        name: name,
        validation: validateWorkoutFields(
          name: name,
          exerciseCount: state.exercises.length,
        ),
        isSaved: false,
        clearErrorMessage: true,
      ),
    );
  }

  /// Revalida o treino em edição expondo as violações para a UI, **sem**
  /// persistir (Requirements 4.5, 4.6).
  ///
  /// Retorna o [WorkoutSaveValidation] resultante por conveniência.
  WorkoutSaveValidation validate() {
    final validation = validateWorkoutFields(
      name: state.name,
      exerciseCount: state.exercises.length,
    );
    emit(
      state.copyWith(
        validation: validation,
        isSaved: false,
        errorMessage: validation.isValid ? null : _messageFor(validation),
        clearErrorMessage: validation.isValid,
      ),
    );
    return validation;
  }

  /// Valida e, se válido, persiste o treino (Requirements 4.3, 4.5, 4.6, 4.7).
  ///
  /// - Se inválido: não persiste, preserva o estado em edição e emite a
  ///   mensagem orientativa (Requirements 4.5, 4.6).
  /// - Se válido: constrói um [Workout] com o nome `trim` aplicado e chama
  ///   [WorkoutRepository.save]. Em sucesso, emite estado de confirmação
  ///   (Requirement 4.3). Em [PersistenceError], mantém o treino em edição
  ///   intacto e emite a mensagem de erro (Requirement 4.7).
  Future<void> save() async {
    final validation = validateWorkoutFields(
      name: state.name,
      exerciseCount: state.exercises.length,
    );

    if (!validation.isValid) {
      // Não persiste; preserva o estado em edição e sinaliza a violação.
      emit(
        state.copyWith(
          validation: validation,
          isSaving: false,
          isSaved: false,
          errorMessage: _messageFor(validation),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        validation: validation,
        isSaving: true,
        isSaved: false,
        clearErrorMessage: true,
      ),
    );

    final workout = Workout(
      id: _idGenerator(),
      name: validation.trimmedName,
      exercises: List<Exercise>.from(state.exercises),
      savedAt: _clock(),
    );

    try {
      await _repository.save(workout);
      // Sucesso: confirmação de treino salvo (Requirement 4.3).
      emit(
        state.copyWith(
          isSaving: false,
          isSaved: true,
          clearErrorMessage: true,
        ),
      );
    } on PersistenceError {
      // Falha de infraestrutura: mantém o treino em edição intacto
      // (Requirement 4.7).
      emit(
        state.copyWith(
          isSaving: false,
          isSaved: false,
          errorMessage: WorkoutBuilderMessages.persistenceFailure,
        ),
      );
    } on WorkoutValidationException catch (e) {
      // Salvaguarda defensiva: o repositório rejeitou por validação.
      emit(
        state.copyWith(
          validation: e.validation,
          isSaving: false,
          isSaved: false,
          errorMessage: _messageFor(e.validation),
        ),
      );
    }
  }

  /// Emite um novo estado com [exercises], recomputando a validação e
  /// limpando flags transitórias de confirmação/erro.
  void _emitWithExercises(List<Exercise> exercises) {
    emit(
      state.copyWith(
        exercises: exercises,
        validation: validateWorkoutFields(
          name: state.name,
          exerciseCount: exercises.length,
        ),
        isSaved: false,
        clearErrorMessage: true,
      ),
    );
  }

  /// Seleciona a mensagem apropriada para o primeiro motivo relevante da
  /// validação (prioriza nome inválido, depois exercícios vazios/excedentes).
  String _messageFor(WorkoutSaveValidation validation) {
    if (validation.hasInvalidName) {
      return WorkoutBuilderMessages.invalidName;
    }
    if (validation.hasEmptyExercises) {
      return WorkoutBuilderMessages.emptyExercises;
    }
    if (validation.hasTooManyExercises) {
      return WorkoutBuilderMessages.tooManyExercises;
    }
    return '';
  }
}
