import 'exercise.dart';
import 'exercise_page.dart';

/// Tamanho máximo padrão de uma página do catálogo (Requirement 1.3).
const int kDefaultPageSize = 20;

/// Divide uma lista de exercícios em uma [ExercisePage] de no máximo
/// [pageSize] itens, a partir do índice de página [page] (0-based).
///
/// Semântica (Property 1 do design — Requirements 1.3, 1.4, 1.5):
/// - Cada página contém no máximo [pageSize] itens (padrão 20).
/// - A concatenação ordenada de todas as páginas (page = 0, 1, 2, ...)
///   reconstitui exatamente a lista original, sem duplicações nem omissões.
/// - [ExercisePage.hasMore] é verdadeiro se, e somente se, existir pelo menos
///   uma página subsequente não vazia, isto é, se ainda restarem itens após
///   o fim da página atual.
///
/// Páginas fora do intervalo (índice cujo início ultrapassa o tamanho da
/// lista) resultam em uma página vazia com `hasMore == false`.
///
/// Lança [ArgumentError] se [page] for negativo ou [pageSize] não for
/// positivo.
ExercisePage paginate(
  List<Exercise> all,
  int page, {
  int pageSize = kDefaultPageSize,
}) {
  if (page < 0) {
    throw ArgumentError.value(page, 'page', 'deve ser maior ou igual a 0');
  }
  if (pageSize <= 0) {
    throw ArgumentError.value(pageSize, 'pageSize', 'deve ser maior que 0');
  }

  final start = page * pageSize;

  // Página inteiramente além do fim da lista: página vazia, sem mais dados.
  if (start >= all.length) {
    return ExercisePage(items: const [], page: page, hasMore: false);
  }

  final end = start + pageSize < all.length ? start + pageSize : all.length;
  final items = List<Exercise>.unmodifiable(all.sublist(start, end));

  // Há mais páginas se, e somente se, restarem itens após o fim desta página.
  final hasMore = end < all.length;

  return ExercisePage(items: items, page: page, hasMore: hasMore);
}
