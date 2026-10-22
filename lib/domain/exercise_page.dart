import 'exercise.dart';

/// Resultado paginado do catálogo de exercícios.
///
/// Cada página contém no máximo 20 itens (Requirement 1.3). A flag [hasMore]
/// indica a existência de uma próxima página (Requirements 1.4, 1.5).
///
/// A classe é imutável e define igualdade estrutural, considerando a ordem da
/// lista de itens.
class ExercisePage {
  const ExercisePage({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  /// Exercícios da página (no máximo 20 — Requirement 1.3).
  final List<Exercise> items;

  /// Índice da página (0-based).
  final int page;

  /// Indica se existe pelo menos uma página subsequente não vazia.
  final bool hasMore;

  /// Retorna uma cópia com os campos informados substituídos.
  ExercisePage copyWith({
    List<Exercise>? items,
    int? page,
    bool? hasMore,
  }) {
    return ExercisePage(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExercisePage &&
        other.page == page &&
        other.hasMore == hasMore &&
        _listEquals(other.items, items);
  }

  @override
  int get hashCode => Object.hash(page, hasMore, Object.hashAll(items));

  @override
  String toString() =>
      'ExercisePage(items: ${items.length} itens, page: $page, '
      'hasMore: $hasMore)';

  static bool _listEquals(List<Exercise> a, List<Exercise> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
