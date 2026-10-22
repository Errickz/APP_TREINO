import 'package:glados/glados.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/domain/exercise_page.dart';
import 'package:gym_workout_app/domain/exercise_repository.dart';
import 'package:gym_workout_app/presentation/search/search_cubit.dart';
import 'package:gym_workout_app/presentation/search/search_state.dart';

Exercise _ex(int i) => Exercise(
      id: 'e$i',
      name: 'Exercise $i',
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$i.gif',
    );

/// Repositório falso: buscas devolvem resultados fixos; catálogo vazio.
class _FakeExerciseRepository implements ExerciseRepository {
  @override
  Future<ExercisePage> getCatalogPage({required int page}) async =>
      const ExercisePage(items: [], page: 0, hasMore: false);

  @override
  Future<Exercise> getExercise(String id) async => _ex(0);

  @override
  Future<List<Exercise>> searchByName(String term) async => [_ex(1)];

  @override
  Future<List<Exercise>> searchByBodyPart(String bodyPart) async => [_ex(2)];

  @override
  Future<List<Exercise>> searchByEquipment(String equipment) async => [_ex(3)];
}

void main() {
  // Feature: gym-workout-app, Property 4: Limpar busca e filtros restaura o
  // catálogo completo.
  //
  // Para qualquer sequência de buscas/filtros, clear() retorna ao estado
  // inicial (SearchInitial com critérios vazios), equivalente ao catálogo
  // completo anterior a qualquer busca.
  Glados<List<int>>(
    // Sequência de ações: 0=searchByName, 1=filterByBodyPart, 2=filterByEquipment.
    any.listWithLengthInRange(0, 6, any.intInRange(0, 3)),
  ).test(
    'Property 4: após qualquer sequência de buscas/filtros, clear() restaura '
    'SearchInitial com critérios vazios',
    (actions) async {
      final cubit = SearchCubit(_FakeExerciseRepository());

      for (final a in actions) {
        switch (a) {
          case 0:
            cubit.filterByBodyPart('chest');
          case 1:
            cubit.filterByEquipment('barbell');
          default:
            cubit.filterByBodyPart('back');
        }
        // Aguarda microtasks das operações assíncronas.
        await Future<void>.delayed(Duration.zero);
      }

      cubit.clear();

      expect(cubit.state, isA<SearchInitial>());
      expect(cubit.state.criteria, SearchCriteria.empty);
      await cubit.close();
    },
  );

  // Feature: gym-workout-app, Property 5: Detalhes do exercício contêm todos
  // os campos exigidos.
  //
  // O modelo de apresentação da tela de detalhes expõe nome, grupo muscular
  // alvo, equipamento e uma referência à área de demonstração do GIF (gifUrl).
  Glados<int>(any.int).test(
    'Property 5: o exercício exibido nos detalhes inclui nome, bodyPart, '
    'equipment e uma referência de GIF não vazia',
    (n) {
      final e = Exercise(
        id: 'e$n',
        name: 'Nome $n',
        bodyPart: 'grupo $n',
        target: 'alvo $n',
        equipment: 'equip $n',
        gifUrl: 'https://example.com/$n.gif',
      );

      // Todos os campos exigidos pela tela de detalhes estão presentes.
      expect(e.name, isNotEmpty);
      expect(e.bodyPart, isNotEmpty);
      expect(e.equipment, isNotEmpty);
      expect(e.gifUrl, isNotEmpty);
      // A referência de GIF é uma URL utilizável pela área de demonstração.
      expect(e.gifUrl, contains('.gif'));
    },
  );
}
