import '../../domain/exercise.dart';
import '../../domain/workout_validation.dart';

/// Estado imutável do fluxo de montagem de treino (`WorkoutBuilderCubit`).
///
/// Mantém o treino em edição (nome e lista ordenada de exercícios) junto com
/// um snapshot de validação ([WorkoutSaveValidation]) e flags transitórias que
/// a UI usa para refletir salvamento em andamento, confirmação de sucesso e
/// mensagens de erro (Requirements 4.1, 4.2, 4.3, 4.5, 4.6, 4.7).
///
/// A classe é imutável; mutações produzem um novo estado via [copyWith]. A
/// lista [exercises] é tratada como imutável — o cubit sempre cria uma nova
/// lista ao adicionar/remover, preservando determinismo (Properties 6 e 7).
class WorkoutBuilderState {
  WorkoutBuilderState({
    required this.name,
    required List<Exercise> exercises,
    required this.validation,
    this.isSaving = false,
    this.isSaved = false,
    this.errorMessage,
  }) : exercises = List.unmodifiable(exercises);

  /// Estado inicial: sem nome, sem exercícios, validação já computada.
  factory WorkoutBuilderState.initial() {
    const name = '';
    return WorkoutBuilderState(
      name: name,
      exercises: const <Exercise>[],
      validation: validateWorkoutFields(name: name, exerciseCount: 0),
    );
  }

  /// Nome em edição (ainda sem `trim` — a normalização ocorre na validação e
  /// no salvamento, Requirement 4.4).
  final String name;

  /// Lista ordenada de exercícios em edição (imutável, ordem contígua).
  final List<Exercise> exercises;

  /// Snapshot da validação de salvamento para a UI (Requirements 4.5, 4.6).
  final WorkoutSaveValidation validation;

  /// `true` enquanto o salvamento está em andamento (Requirement 4.3).
  final bool isSaving;

  /// `true` quando o último salvamento foi concluído com sucesso — usado para
  /// exibir a confirmação de treino salvo (Requirement 4.3).
  final bool isSaved;

  /// Mensagem de erro transitória (validação ou falha de persistência —
  /// Requirements 4.5, 4.6, 4.7). `null` quando não há erro.
  final String? errorMessage;

  /// Retorna uma cópia com os campos informados substituídos.
  ///
  /// Para [errorMessage], use [clearErrorMessage] para forçar a limpeza, já
  /// que `null` é indistinguível de "não informado" em [copyWith].
  WorkoutBuilderState copyWith({
    String? name,
    List<Exercise>? exercises,
    WorkoutSaveValidation? validation,
    bool? isSaving,
    bool? isSaved,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return WorkoutBuilderState(
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      validation: validation ?? this.validation,
      isSaving: isSaving ?? this.isSaving,
      isSaved: isSaved ?? this.isSaved,
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkoutBuilderState &&
        other.name == name &&
        other.validation == validation &&
        other.isSaving == isSaving &&
        other.isSaved == isSaved &&
        other.errorMessage == errorMessage &&
        _listEquals(other.exercises, exercises);
  }

  @override
  int get hashCode => Object.hash(
        name,
        Object.hashAll(exercises),
        validation,
        isSaving,
        isSaved,
        errorMessage,
      );

  @override
  String toString() => 'WorkoutBuilderState(name: "$name", '
      'exercises: ${exercises.length} itens, isValid: ${validation.isValid}, '
      'isSaving: $isSaving, isSaved: $isSaved, errorMessage: $errorMessage)';

  static bool _listEquals(List<Exercise> a, List<Exercise> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
