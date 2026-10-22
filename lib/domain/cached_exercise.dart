import 'exercise.dart';

/// Modelo de persistência que envolve um [Exercise] com metadados de cache.
///
/// - [storedAt]: instante em que o exercício foi obtido da API, usado para a
///   expiração de 24 horas (Requirements 6.2, 6.3).
/// - [accessedAt]: instante do último acesso, usado para a ordenação LRU ao
///   aplicar o limite de 1.500 registros (Requirement 6.1).
///
/// A classe é imutável e define igualdade estrutural por todos os seus campos.
class CachedExercise {
  const CachedExercise({
    required this.exercise,
    required this.storedAt,
    required this.accessedAt,
  });

  /// Exercício armazenado em cache.
  final Exercise exercise;

  /// Quando o exercício foi obtido da API (expiração de 24h).
  final DateTime storedAt;

  /// Último acesso ao exercício (ordenação LRU).
  final DateTime accessedAt;

  /// Retorna uma cópia com os campos informados substituídos.
  CachedExercise copyWith({
    Exercise? exercise,
    DateTime? storedAt,
    DateTime? accessedAt,
  }) {
    return CachedExercise(
      exercise: exercise ?? this.exercise,
      storedAt: storedAt ?? this.storedAt,
      accessedAt: accessedAt ?? this.accessedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CachedExercise &&
        other.exercise == exercise &&
        other.storedAt == storedAt &&
        other.accessedAt == accessedAt;
  }

  @override
  int get hashCode => Object.hash(exercise, storedAt, accessedAt);

  @override
  String toString() => 'CachedExercise(exercise: $exercise, '
      'storedAt: $storedAt, accessedAt: $accessedAt)';
}
