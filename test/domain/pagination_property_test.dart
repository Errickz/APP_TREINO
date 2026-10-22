import 'package:glados/glados.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/domain/pagination.dart';

/// Gerador de [Exercise] com campos simples (o id é suficiente para checar
/// identidade/ordem na paginação).
Generator<Exercise> _anyExercise() {
  return any.int.map(
    (n) => Exercise(
      id: 'e$n',
      name: 'Exercise $n',
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$n.gif',
    ),
  );
}

void main() {
  // Feature: gym-workout-app, Property 1: Paginação produz páginas de no
  // máximo 20 itens cobrindo toda a lista.
  Glados2<List<Exercise>, int>(
    any.listWithLengthInRange(0, 65, _anyExercise()),
    any.intInRange(1, 25),
  ).test(
    'Property 1: paginação produz páginas de no máximo pageSize itens, '
    'a concatenação reconstitui a lista e hasMore é correto',
    (exercises, pageSize) {
      // Pagina a lista inteira acumulando as páginas.
      final collected = <Exercise>[];
      var page = 0;
      var sawHasMoreFalse = false;

      while (true) {
        final result = paginate(exercises, page, pageSize: pageSize);

        // Cada página tem no máximo pageSize itens.
        expect(result.items.length, lessThanOrEqualTo(pageSize));
        expect(result.page, page);

        collected.addAll(result.items);

        // hasMore é verdadeiro se, e somente se, ainda restarem itens após o
        // fim desta página.
        final consumed = (page + 1) * pageSize;
        final expectedHasMore = consumed < exercises.length;
        expect(result.hasMore, expectedHasMore);

        if (!result.hasMore) {
          sawHasMoreFalse = true;
          break;
        }
        page++;
      }

      // A concatenação ordenada de todas as páginas reconstitui exatamente a
      // lista original (sem duplicações nem omissões).
      expect(collected, equals(exercises));
      expect(sawHasMoreFalse, isTrue);
    },
  );
}
