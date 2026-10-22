import 'package:flutter_test/flutter_test.dart';
import 'package:gym_workout_app/domain/app_failure.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/domain/exercise_page.dart';
import 'package:gym_workout_app/domain/exercise_repository.dart';
import 'package:gym_workout_app/presentation/catalog/catalog_cubit.dart';
import 'package:gym_workout_app/presentation/catalog/catalog_state.dart';
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

/// Repositório configurável para simular sucesso, vazio ou falha.
class _ConfigurableRepo implements ExerciseRepository {
  _ConfigurableRepo({
    this.catalogResult,
    this.searchResult,
    this.failure,
  });

  ExercisePage? catalogResult;
  List<Exercise>? searchResult;
  AppFailure? failure;

  @override
  Future<ExercisePage> getCatalogPage({required int page}) async {
    if (failure != null) throw failure!;
    return catalogResult ??
        const ExercisePage(items: [], page: 0, hasMore: false);
  }

  @override
  Future<Exercise> getExercise(String id) async => _ex(0);

  @override
  Future<List<Exercise>> searchByName(String term) async {
    if (failure != null) throw failure!;
    return searchResult ?? const [];
  }

  @override
  Future<List<Exercise>> searchByBodyPart(String bodyPart) async {
    if (failure != null) throw failure!;
    return searchResult ?? const [];
  }

  @override
  Future<List<Exercise>> searchByEquipment(String equipment) async {
    if (failure != null) throw failure!;
    return searchResult ?? const [];
  }
}

void main() {
  group('CatalogCubit estados de UI (Requirements 1.2, 1.6, 1.7)', () {
    test('loadFirstPage emite CatalogLoading e depois CatalogLoaded', () async {
      final repo = _ConfigurableRepo(
        catalogResult: ExercisePage(
          items: <Exercise>[_ex(0), _ex(1)],
          page: 0,
          hasMore: true,
        ),
      );
      final cubit = CatalogCubit(repo);
      // Estado inicial é de carregamento (Req 1.2).
      expect(cubit.state, isA<CatalogLoading>());
      final emitted = <CatalogState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.loadFirstPage();
      // Dá uma volta no event loop para garantir a entrega dos eventos.
      await Future<void>.delayed(Duration.zero);

      // Durante o carregamento, um CatalogLoading foi emitido, terminando em
      // CatalogLoaded (Req 1.1, 1.3).
      expect(emitted.any((s) => s is CatalogLoading), isTrue);
      expect(cubit.state, isA<CatalogLoaded>());
      final loaded = cubit.state as CatalogLoaded;
      expect(loaded.items.length, 2);
      expect(loaded.hasMore, isTrue);

      await sub.cancel();
      await cubit.close();
    });

    test('timeout emite CatalogError retryable; retry recarrega (Req 1.6/1.7)',
        () async {
      final repo = _ConfigurableRepo(failure: const TimeoutError());
      final cubit = CatalogCubit(repo);

      await cubit.loadFirstPage();
      expect(cubit.state, isA<CatalogError>());
      expect((cubit.state as CatalogError).retryable, isTrue);

      // Corrige a condição e aciona retry: deve carregar com sucesso.
      repo.failure = null;
      repo.catalogResult = ExercisePage(
        items: <Exercise>[_ex(0)],
        page: 0,
        hasMore: false,
      );
      await cubit.retry();
      expect(cubit.state, isA<CatalogLoaded>());

      await cubit.close();
    });
  });

  group('SearchCubit estados de UI (Requirements 3.4, 3.6)', () {
    test('resultado vazio produz SearchLoaded com isEmpty (Req 3.4)', () async {
      final repo = _ConfigurableRepo(searchResult: const <Exercise>[]);
      final cubit = SearchCubit(repo);

      cubit.filterByBodyPart('chest');
      // Aguarda a operação assíncrona concluir.
      await cubit.stream.firstWhere((s) => s is SearchLoaded || s is SearchError);

      expect(cubit.state, isA<SearchLoaded>());
      expect((cubit.state as SearchLoaded).isEmpty, isTrue);

      await cubit.close();
    });

    test('falha preserva critérios em SearchError (Req 3.6)', () async {
      final repo = _ConfigurableRepo(failure: const NetworkError());
      final cubit = SearchCubit(repo);

      cubit.filterByEquipment('barbell');
      await cubit.stream.firstWhere((s) => s is SearchError);

      final error = cubit.state as SearchError;
      // Critério aplicado é preservado no estado de erro.
      expect(error.criteria.equipment, 'barbell');
      expect(error.retryable, isTrue);

      await cubit.close();
    });
  });
}
