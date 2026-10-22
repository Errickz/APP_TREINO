import 'workout.dart';

/// Limites de validação de um [Workout] no momento do salvamento.
///
/// Derivados dos Requirements 4.3 (1..50 exercícios), 4.4 e 4.6 (nome 1..60
/// após `trim`).
const int kWorkoutNameMinLength = 1;
const int kWorkoutNameMaxLength = 60;
const int kWorkoutMinExercises = 1;
const int kWorkoutMaxExercises = 50;

/// Motivos pelos quais o salvamento de um [Workout] pode ser rejeitado.
///
/// Permite que o `WorkoutBuilderCubit` apresente mensagens orientativas
/// específicas sem realizar chamadas externas (Requirements 4.5, 4.6).
enum WorkoutSaveViolation {
  /// O treino não possui nenhum exercício (Requirement 4.5).
  emptyExercises,

  /// O treino possui mais de 50 exercícios (Requirement 4.3).
  tooManyExercises,

  /// O nome é vazio (ou só espaços) após `trim`, ou excede 60 caracteres
  /// (Requirements 4.4, 4.6).
  invalidName,
}

/// Resultado puro da validação de salvamento de um [Workout] (Property 9).
///
/// Contrato:
/// - [isValid] é `true` se, e somente se, [violations] estiver vazio.
/// - Quando [isValid] é `true`, [trimmedName] contém o nome com `trim`
///   aplicado — exatamente o nome que deve ser persistido (Requirement 4.4).
/// - Quando [isValid] é `false`, [violations] lista todos os motivos
///   encontrados e [trimmedName] ainda reflete o nome com `trim` (útil para
///   a UI), mas o treino **não** deve ser persistido.
///
/// Esta classe é imutável e define igualdade estrutural.
class WorkoutSaveValidation {
  const WorkoutSaveValidation._({
    required this.violations,
    required this.trimmedName,
  });

  /// Conjunto (sem ordem semântica) de violações encontradas. Vazio quando o
  /// treino é válido para salvamento.
  final Set<WorkoutSaveViolation> violations;

  /// Nome com `trim` aplicado. É o nome a ser persistido quando [isValid].
  final String trimmedName;

  /// `true` se, e somente se, não houver nenhuma violação.
  bool get isValid => violations.isEmpty;

  /// `true` se há violação de nome (vazio/apenas espaços ou > 60 caracteres).
  bool get hasInvalidName =>
      violations.contains(WorkoutSaveViolation.invalidName);

  /// `true` se o treino não possui nenhum exercício.
  bool get hasEmptyExercises =>
      violations.contains(WorkoutSaveViolation.emptyExercises);

  /// `true` se o treino excede o limite de 50 exercícios.
  bool get hasTooManyExercises =>
      violations.contains(WorkoutSaveViolation.tooManyExercises);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkoutSaveValidation &&
        other.trimmedName == trimmedName &&
        _setEquals(other.violations, violations);
  }

  @override
  int get hashCode => Object.hash(
        trimmedName,
        Object.hashAllUnordered(violations),
      );

  @override
  String toString() => 'WorkoutSaveValidation(isValid: $isValid, '
      'trimmedName: "$trimmedName", violations: $violations)';

  static bool _setEquals(
    Set<WorkoutSaveViolation> a,
    Set<WorkoutSaveViolation> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

/// Valida um [Workout] candidato para salvamento (Property 9 / Requirements
/// 4.3, 4.4, 4.5, 4.6).
///
/// Função **pura**: não realiza persistência nem chamadas externas; apenas
/// inspeciona [workout] e retorna um [WorkoutSaveValidation].
///
/// Regras:
/// - O nome é normalizado com `trim`. É inválido se ficar vazio após o `trim`
///   ou se exceder 60 caracteres (Requirements 4.4, 4.6).
/// - A lista de exercícios deve conter entre 1 e 50 itens; menos de 1
///   produz [WorkoutSaveViolation.emptyExercises] e mais de 50 produz
///   [WorkoutSaveViolation.tooManyExercises] (Requirements 4.3, 4.5).
///
/// O salvamento é aceito se, e somente se, todas as regras forem satisfeitas,
/// caso em que [WorkoutSaveValidation.trimmedName] é o nome a persistir.
WorkoutSaveValidation validateWorkoutForSave(Workout workout) {
  return validateWorkoutFields(
    name: workout.name,
    exerciseCount: workout.exercises.length,
  );
}

/// Variante de [validateWorkoutForSave] que opera diretamente sobre os campos
/// relevantes, útil ao `WorkoutBuilderCubit` quando ainda não há um [Workout]
/// construído (validação em edição).
WorkoutSaveValidation validateWorkoutFields({
  required String name,
  required int exerciseCount,
}) {
  final trimmedName = name.trim();
  final violations = <WorkoutSaveViolation>{};

  if (trimmedName.length < kWorkoutNameMinLength ||
      trimmedName.length > kWorkoutNameMaxLength) {
    violations.add(WorkoutSaveViolation.invalidName);
  }

  if (exerciseCount < kWorkoutMinExercises) {
    violations.add(WorkoutSaveViolation.emptyExercises);
  } else if (exerciseCount > kWorkoutMaxExercises) {
    violations.add(WorkoutSaveViolation.tooManyExercises);
  }

  return WorkoutSaveValidation._(
    violations: Set.unmodifiable(violations),
    trimmedName: trimmedName,
  );
}
