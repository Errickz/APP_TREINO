import 'exercise.dart';

/// Entidade de domínio que representa um treino montado pelo usuário.
///
/// Um treino é uma coleção **ordenada** de exercícios (Requirement 4.1). A
/// ordem é significativa e contígua (sem lacunas) após remoções
/// (Requirement 4.2). As regras de validação de nome (1..60 após trim) e
/// quantidade de exercícios (1..50) são aplicadas no momento do salvamento
/// (Requirements 4.3, 4.4, 4.5, 4.6).
///
/// A classe é imutável e define igualdade estrutural, considerando a ordem da
/// lista de exercícios.
class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.exercises,
    required this.savedAt,
  });

  /// Identificador único do treino.
  final String id;

  /// Nome do treino (1..60 caracteres após `trim` — Requirements 4.4, 4.6).
  final String name;

  /// Lista ordenada de exercícios (1..50 itens — Requirements 4.3, 4.5).
  final List<Exercise> exercises;

  /// Instante em que o treino foi salvo.
  final DateTime savedAt;

  /// Retorna uma cópia com os campos informados substituídos.
  Workout copyWith({
    String? id,
    String? name,
    List<Exercise>? exercises,
    DateTime? savedAt,
  }) {
    return Workout(
      id: id ?? this.id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      savedAt: savedAt ?? this.savedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Workout &&
        other.id == id &&
        other.name == name &&
        other.savedAt == savedAt &&
        _listEquals(other.exercises, exercises);
  }

  @override
  int get hashCode =>
      Object.hash(id, name, savedAt, Object.hashAll(exercises));

  @override
  String toString() => 'Workout(id: $id, name: $name, '
      'exercises: ${exercises.length} itens, savedAt: $savedAt)';

  static bool _listEquals(List<Exercise> a, List<Exercise> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
