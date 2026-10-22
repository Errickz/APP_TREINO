import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/exercise.dart';
import '../widgets/gif_view.dart';
import 'catalog_cubit.dart';
import 'catalog_state.dart';
import 'exercise_detail_page.dart';

/// Tela do catálogo de exercícios (Requirement 1).
///
/// Comportamento:
/// - Dispara [CatalogCubit.loadFirstPage] ao montar.
/// - [CatalogLoading] exibe um indicador de carregamento centralizado
///   (Requirement 1.2).
/// - [CatalogLoaded] exibe uma lista rolável e paginada de exercícios com nome
///   e miniatura do GIF (Requirements 1.1, 1.3). Ao se aproximar do final da
///   lista, solicita a próxima página via [CatalogCubit.loadNextPage] (scroll
///   infinito, Requirement 1.4), exibindo um indicador no rodapé enquanto
///   [CatalogLoaded.isLoadingMore] for verdadeiro. Tocar em um item navega para
///   a [ExerciseDetailPage] correspondente (Requirement 2.1).
/// - [CatalogError] exibe a mensagem de erro e, quando aplicável, um botão
///   "Tentar novamente" que aciona [CatalogCubit.retry] (Requirements 1.6, 1.7).
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final ScrollController _scrollController = ScrollController();

  /// Distância do final da lista (em pixels) a partir da qual a próxima página
  /// é pré-carregada.
  static const double _loadMoreThreshold = 300;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Dispara a primeira requisição ao montar a tela (Requirements 1.1, 1.2).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CatalogCubit>().loadFirstPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Próximo do final da lista => carrega a próxima página (Requirement 1.4).
    // O próprio Cubit ignora a chamada quando não há mais páginas ou já está
    // carregando (Requirement 1.5).
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      context.read<CatalogCubit>().loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de exercícios'),
      ),
      body: SafeArea(
        child: BlocBuilder<CatalogCubit, CatalogState>(
          builder: (context, state) {
            return switch (state) {
              CatalogLoading() => const _CatalogLoadingView(),
              CatalogLoaded() => _CatalogListView(
                  state: state,
                  scrollController: _scrollController,
                ),
              CatalogError() => _CatalogErrorView(state: state),
            };
          },
        ),
      ),
    );
  }
}

/// Indicador de carregamento inicial centralizado (Requirement 1.2).
class _CatalogLoadingView extends StatelessWidget {
  const _CatalogLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('catalog_loading'),
      child: CircularProgressIndicator.adaptive(),
    );
  }
}

/// Lista rolável e paginada de exercícios (Requirements 1.1, 1.3, 1.4).
class _CatalogListView extends StatelessWidget {
  const _CatalogListView({
    required this.state,
    required this.scrollController,
  });

  final CatalogLoaded state;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final items = state.items;

    if (items.isEmpty && !state.isLoadingMore) {
      return const Center(
        key: Key('catalog_empty'),
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum exercício disponível no momento.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Um item extra no final para o indicador de "carregar mais".
    final itemCount = items.length + (state.isLoadingMore ? 1 : 0);

    return ListView.separated(
      key: const Key('catalog_list'),
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            key: Key('catalog_load_more'),
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator.adaptive()),
          );
        }
        return _ExerciseListItem(exercise: items[index]);
      },
    );
  }
}

/// Item da lista: miniatura do GIF + nome do exercício. Toca navega para
/// [ExerciseDetailPage] (Requirements 1.1, 2.1).
class _ExerciseListItem extends StatelessWidget {
  const _ExerciseListItem({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      key: Key('catalog_item_${exercise.id}'),
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: GifView(
            gifUrl: exercise.gifUrl,
            fit: BoxFit.cover,
            semanticLabel: 'Demonstração do exercício ${exercise.name}',
          ),
        ),
      ),
      title: Text(
        exercise.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${exercise.bodyPart} · ${exercise.equipment}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ExerciseDetailPage(exercise: exercise),
          ),
        );
      },
    );
  }
}

/// Estado de erro com mensagem e opção de nova tentativa (Requirements 1.6, 1.7).
class _CatalogErrorView extends StatelessWidget {
  const _CatalogErrorView({required this.state});

  final CatalogError state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      key: const Key('catalog_error'),
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
              state.message,
              key: const Key('catalog_error_message'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (state.retryable) ...<Widget>[
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('catalog_retry_button'),
                onPressed: () => context.read<CatalogCubit>().retry(),
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
