import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_workout_app/domain/app_failure.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/presentation/search/search_cubit.dart';
import 'package:gym_workout_app/presentation/search/search_page.dart';
import 'package:gym_workout_app/presentation/search/search_state.dart';

/// Cubit de teste que permite forçar estados arbitrários sem depender de um
/// repositório real. Reaproveita a API pública do [SearchCubit] apenas para
/// expor os estados que a UI deve renderizar (Requirement 3).
class _FakeSearchCubit extends Cubit<SearchState> implements SearchCubit {
  _FakeSearchCubit() : super(const SearchInitial());

  final List<String> searchByNameCalls = <String>[];
  final List<String> bodyPartCalls = <String>[];
  final List<String> equipmentCalls = <String>[];
  int clearCalls = 0;
  int retryCalls = 0;

  void setState(SearchState state) => emit(state);

  @override
  void searchByName(String term) => searchByNameCalls.add(term);

  @override
  void filterByBodyPart(String bodyPart) => bodyPartCalls.add(bodyPart);

  @override
  void filterByEquipment(String equipment) => equipmentCalls.add(equipment);

  @override
  void clear() => clearCalls++;

  @override
  Future<void> retry() async => retryCalls++;
}

Exercise _exercise(String id) => Exercise(
      id: id,
      name: 'Supino $id',
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$id.gif',
    );

Widget _wrap(_FakeSearchCubit cubit) {
  return MaterialApp(
    // Desabilita o splash de tinta (ink_sparkle) para que os testes de widget
    // não precisem carregar o shader `ink_sparkle.frag` como asset ao tocar em
    // ChoiceChips. Isso mantém os testes independentes do pipeline de shaders.
    theme: ThemeData(splashFactory: NoSplash.splashFactory),
    home: BlocProvider<SearchCubit>.value(
      value: cubit,
      child: const SearchPage(),
    ),
  );
}

void main() {
  group('SearchPage', () {
    testWidgets('estado inicial exibe a dica de busca', (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      expect(find.byKey(const Key('search_initial_hint')), findsOneWidget);
      expect(find.byKey(const Key('search_term_field')), findsOneWidget);
    });

    testWidgets('digitar no campo delega a searchByName (Req 3.1)',
        (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      await tester.enterText(
        find.byKey(const Key('search_term_field')),
        'sup',
      );

      expect(cubit.searchByNameCalls, contains('sup'));
    });

    testWidgets('selecionar chip de grupo muscular chama filterByBodyPart '
        '(Req 3.2)', (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      await tester.tap(find.byKey(const Key('body_part_chip_chest')));
      await tester.pump();

      expect(cubit.bodyPartCalls, <String>['chest']);
    });

    testWidgets('selecionar chip de equipamento chama filterByEquipment '
        '(Req 3.3)', (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      await tester.tap(find.byKey(const Key('equipment_chip_barbell')));
      await tester.pump();

      expect(cubit.equipmentCalls, <String>['barbell']);
    });

    testWidgets('loading exibe indicador de progresso', (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      cubit.setState(const SearchLoading(SearchCriteria.empty));
      await tester.pump();

      expect(find.byKey(const Key('search_loading')), findsOneWidget);
    });

    testWidgets('resultado vazio exibe mensagem dedicada (Req 3.4)',
        (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      cubit.setState(
        const SearchLoaded(
          results: <Exercise>[],
          criteria: SearchCriteria(term: 'xyz'),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('search_empty')), findsOneWidget);
      expect(
        find.text('Nenhum exercício encontrado para os critérios aplicados'),
        findsOneWidget,
      );
    });

    testWidgets('resultados exibem a lista com nomes', (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      cubit.setState(
        SearchLoaded(
          results: <Exercise>[_exercise('1'), _exercise('2')],
          criteria: const SearchCriteria(term: 'su'),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('search_results_list')), findsOneWidget);
      expect(find.text('Supino 1'), findsOneWidget);
      expect(find.text('Supino 2'), findsOneWidget);
    });

    testWidgets('limpar chama clear (Req 3.5)', (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      await tester.tap(find.byKey(const Key('search_clear_button')));
      await tester.pump();

      expect(cubit.clearCalls, 1);
    });

    testWidgets('erro retryable exibe botão e chama retry (Req 3.6)',
        (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      cubit.setState(
        const SearchError(
          failure: NetworkError(),
          message: 'Falha de comunicação. Tente novamente.',
          criteria: SearchCriteria(term: 'su'),
          retryable: true,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('search_error')), findsOneWidget);
      expect(find.byKey(const Key('search_retry_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('search_retry_button')));
      await tester.pump();

      expect(cubit.retryCalls, 1);
    });

    testWidgets('erro não-retryable não exibe botão de nova tentativa',
        (tester) async {
      final cubit = _FakeSearchCubit();
      await tester.pumpWidget(_wrap(cubit));

      cubit.setState(
        const SearchError(
          failure: AuthError(),
          message: 'Falha de autenticação.',
          criteria: SearchCriteria.empty,
          retryable: false,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('search_error')), findsOneWidget);
      expect(find.byKey(const Key('search_retry_button')), findsNothing);
    });
  });
}
