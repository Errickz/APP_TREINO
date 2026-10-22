import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/exercise.dart';
import '../widgets/gif_view.dart';
import 'search_cubit.dart';
import 'search_state.dart';

/// Tela de busca de exercícios (Requirement 3).
///
/// Combina três controles de entrada que acionam o [SearchCubit]:
/// - Um campo de texto para busca por nome, que delega ao
///   [SearchCubit.searchByName] a cada alteração. O cubit é responsável por
///   aplicar o mínimo de 2 caracteres e o debounce (Requirement 3.1), de modo
///   que a página não implementa nenhuma dessas regras.
/// - Controles de filtro (chips de seleção) para grupo muscular
///   ([SearchCubit.filterByBodyPart] — Requirement 3.2) e equipamento
///   ([SearchCubit.filterByEquipment] — Requirement 3.3).
/// - Um botão "Limpar" que delega a [SearchCubit.clear] (Requirement 3.5).
///
/// O corpo reage ao [SearchState] via [BlocBuilder], exibindo dica inicial,
/// carregamento, resultados (ou mensagem de vazio — Requirement 3.4) e erro com
/// opção de nova tentativa quando aplicável (Requirement 3.6).
///
/// As opções de grupo muscular e equipamento abaixo são um conjunto fixo e
/// razoável derivado dos valores típicos da ExerciseDB_API. Como os valores do
/// catálogo vêm da API, estas listas podem ser tornadas dinâmicas no futuro
/// (por exemplo, obtendo-as de endpoints de metadados `/bodyPartList` e
/// `/equipmentList`), sem alterar o restante desta página.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  /// Opções fixas de grupo muscular (rótulos PT-BR → valor enviado à API).
  ///
  /// Os valores (direita) correspondem aos termos esperados pela
  /// ExerciseDB_API; os rótulos (esquerda) são apresentados ao usuário em
  /// PT-BR. Podem ser carregados dinamicamente da API no futuro.
  static const List<({String label, String value})> bodyPartOptions =
      <({String label, String value})>[
    (label: 'Costas', value: 'back'),
    (label: 'Cardio', value: 'cardio'),
    (label: 'Peito', value: 'chest'),
    (label: 'Braços inferiores', value: 'lower arms'),
    (label: 'Pernas inferiores', value: 'lower legs'),
    (label: 'Pescoço', value: 'neck'),
    (label: 'Ombros', value: 'shoulders'),
    (label: 'Braços superiores', value: 'upper arms'),
    (label: 'Pernas superiores', value: 'upper legs'),
    (label: 'Cintura', value: 'waist'),
  ];

  /// Opções fixas de equipamento (rótulos PT-BR → valor enviado à API).
  ///
  /// Conjunto reduzido e representativo dos equipamentos mais comuns da
  /// ExerciseDB_API. Pode ser carregado dinamicamente da API no futuro.
  static const List<({String label, String value})> equipmentOptions =
      <({String label, String value})>[
    (label: 'Peso corporal', value: 'body weight'),
    (label: 'Barra', value: 'barbell'),
    (label: 'Halteres', value: 'dumbbell'),
    (label: 'Cabo', value: 'cable'),
    (label: 'Máquina', value: 'leverage machine'),
    (label: 'Kettlebell', value: 'kettlebell'),
    (label: 'Faixa elástica', value: 'band'),
    (label: 'Bola suíça', value: 'stability ball'),
    (label: 'Anilha', value: 'weighted'),
    (label: 'Barra Smith', value: 'smith machine'),
  ];

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _termController = TextEditingController();

  @override
  void dispose() {
    _termController.dispose();
    super.dispose();
  }

  SearchCubit get _cubit => context.read<SearchCubit>();

  /// Sincroniza o campo de texto com o termo presente nos critérios do estado.
  ///
  /// Necessário para refletir a limpeza (Requirement 3.5) e a preservação de
  /// critérios (Requirement 3.6) sem perder a posição do cursor quando o texto
  /// já corresponde ao termo.
  void _syncTermField(String term) {
    if (_termController.text != term) {
      _termController.value = TextEditingValue(
        text: term,
        selection: TextSelection.collapsed(offset: term.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar exercícios'),
      ),
      body: BlocBuilder<SearchCubit, SearchState>(
        builder: (BuildContext context, SearchState state) {
          final SearchCriteria criteria = state.criteria;
          _syncTermField(criteria.term);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SearchControls(
                termController: _termController,
                criteria: criteria,
                onTermChanged: _cubit.searchByName,
                onBodyPartSelected: _cubit.filterByBodyPart,
                onEquipmentSelected: _cubit.filterByEquipment,
                onClear: _cubit.clear,
              ),
              const Divider(height: 1),
              Expanded(
                child: _SearchBody(
                  state: state,
                  onRetry: _cubit.retry,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Controles de entrada da busca: campo de nome, filtros e botão "Limpar".
class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.termController,
    required this.criteria,
    required this.onTermChanged,
    required this.onBodyPartSelected,
    required this.onEquipmentSelected,
    required this.onClear,
  });

  final TextEditingController termController;
  final SearchCriteria criteria;
  final ValueChanged<String> onTermChanged;
  final ValueChanged<String> onBodyPartSelected;
  final ValueChanged<String> onEquipmentSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            key: const Key('search_term_field'),
            controller: termController,
            textInputAction: TextInputAction.search,
            onChanged: onTermChanged,
            decoration: const InputDecoration(
              labelText: 'Nome do exercício',
              hintText: 'Digite ao menos 2 caracteres',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _FilterSection(
            title: 'Grupo muscular',
            options: SearchPage.bodyPartOptions,
            selectedValue: criteria.bodyPart,
            onSelected: onBodyPartSelected,
            chipKeyPrefix: 'body_part_chip_',
          ),
          const SizedBox(height: 12),
          _FilterSection(
            title: 'Equipamento',
            options: SearchPage.equipmentOptions,
            selectedValue: criteria.equipment,
            onSelected: onEquipmentSelected,
            chipKeyPrefix: 'equipment_chip_',
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('search_clear_button'),
              onPressed: onClear,
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpar'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Seção de filtro apresentada como uma linha rolável de [ChoiceChip].
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.chipKeyPrefix,
  });

  final String title;
  final List<({String label, String value})> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final String chipKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: textTheme.titleSmall),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final ({String label, String value}) option in options)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('$chipKeyPrefix${option.value}'),
                    label: Text(option.label),
                    selected: selectedValue == option.value,
                    onSelected: (_) => onSelected(option.value),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Corpo reativo da busca, selecionado conforme o [SearchState] atual.
class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.state,
    required this.onRetry,
  });

  final SearchState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      // Estado inicial: sem critérios aplicados; dica para o usuário buscar ou
      // navegar pelo catálogo completo (Requirement 3.5).
      SearchInitial() => const _CenteredMessage(
          key: Key('search_initial_hint'),
          icon: Icons.fitness_center,
          message:
              'Busque por nome ou aplique filtros de grupo muscular e '
              'equipamento para encontrar exercícios. Sem filtros, o catálogo '
              'completo é exibido.',
        ),
      // Busca em andamento (Requirements 3.1–3.3).
      SearchLoading() => const Center(
          key: Key('search_loading'),
          child: CircularProgressIndicator.adaptive(),
        ),
      // Resultado: lista de exercícios ou mensagem de vazio (Requirement 3.4).
      SearchLoaded(:final results, :final isEmpty) => isEmpty
          ? const _CenteredMessage(
              key: Key('search_empty'),
              icon: Icons.search_off,
              message:
                  'Nenhum exercício encontrado para os critérios aplicados',
            )
          : _ResultsList(results: results),
      // Falha: mensagem e, quando aplicável, botão de nova tentativa
      // (Requirement 3.6).
      SearchError(:final message, :final retryable) => _ErrorView(
          message: message,
          retryable: retryable,
          onRetry: onRetry,
        ),
    };
  }
}

/// Lista dos exercícios resultantes, cada item com nome e miniatura em GIF.
class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results});

  final List<Exercise> results;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('search_results_list'),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final Exercise exercise = results[index];
        return ListTile(
          key: Key('search_result_${exercise.id}'),
          leading: SizedBox(
            width: 56,
            height: 56,
            child: GifView(
              gifUrl: exercise.gifUrl,
              semanticLabel: exercise.name,
            ),
          ),
          title: Text(exercise.name),
          subtitle: Text('${exercise.bodyPart} • ${exercise.equipment}'),
        );
      },
    );
  }
}

/// Mensagem centralizada com ícone, usada nos estados inicial e vazio.
class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Visualização de erro da busca com mensagem e, quando [retryable], ação de
/// nova tentativa (Requirement 3.6).
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.retryable,
    required this.onRetry,
  });

  final String message;
  final bool retryable;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      key: const Key('search_error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            if (retryable) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('search_retry_button'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
