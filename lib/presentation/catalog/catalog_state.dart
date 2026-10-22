import '../../domain/app_failure.dart';
import '../../domain/exercise.dart';

/// Estados do [CatalogCubit] que modelam o carregamento do catálogo de
/// exercícios (Requirement 1).
///
/// Por ser uma `sealed class`, o compilador garante exaustividade ao usar
/// `switch` sobre um [CatalogState] na camada de UI.
sealed class CatalogState {
  const CatalogState();
}

/// Carregamento inicial em andamento (Requirement 1.2).
///
/// Emitido enquanto a primeira página está sendo solicitada ao repositório.
/// A UI exibe um indicador de carregamento.
class CatalogLoading extends CatalogState {
  const CatalogLoading();

  @override
  bool operator ==(Object other) => other is CatalogLoading;

  @override
  int get hashCode => (CatalogLoading).hashCode;

  @override
  String toString() => 'CatalogLoading()';
}

/// Catálogo carregado com sucesso (Requirements 1.1, 1.3, 1.4, 1.5).
///
/// [items] acumula os exercícios de todas as páginas já carregadas na ordem
/// em que foram recebidas. [page] é o índice (0-based) da última página
/// carregada. [hasMore] indica se existe ao menos uma página subsequente
/// (Requirements 1.4, 1.5). [isLoadingMore] indica que a próxima página está
/// sendo carregada (scroll infinito).
class CatalogLoaded extends CatalogState {
  const CatalogLoaded({
    required this.items,
    required this.page,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  /// Exercícios acumulados de todas as páginas carregadas.
  final List<Exercise> items;

  /// Índice (0-based) da última página carregada.
  final int page;

  /// Indica se há ao menos uma página subsequente disponível.
  final bool hasMore;

  /// Indica que a próxima página está sendo carregada no momento.
  final bool isLoadingMore;

  CatalogLoaded copyWith({
    List<Exercise>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CatalogLoaded(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CatalogLoaded &&
        other.page == page &&
        other.hasMore == hasMore &&
        other.isLoadingMore == isLoadingMore &&
        _listEquals(other.items, items);
  }

  @override
  int get hashCode =>
      Object.hash(page, hasMore, isLoadingMore, Object.hashAll(items));

  @override
  String toString() =>
      'CatalogLoaded(items: ${items.length} itens, page: $page, '
      'hasMore: $hasMore, isLoadingMore: $isLoadingMore)';

  static bool _listEquals(List<Exercise> a, List<Exercise> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Falha ao carregar o catálogo (Requirements 1.6, 7.x).
///
/// [failure] é o erro de domínio original; [message] é a mensagem amigável a
/// ser exibida ao usuário; [retryable] indica se a UI deve oferecer a opção de
/// "tentar novamente" (Requirements 1.6, 1.7).
class CatalogError extends CatalogState {
  const CatalogError({
    required this.failure,
    required this.message,
    required this.retryable,
  });

  /// Erro de domínio que originou a falha.
  final AppFailure failure;

  /// Mensagem amigável para exibição na UI.
  final String message;

  /// Indica se a falha permite nova tentativa.
  final bool retryable;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CatalogError &&
        other.failure.runtimeType == failure.runtimeType &&
        other.message == message &&
        other.retryable == retryable;
  }

  @override
  int get hashCode => Object.hash(failure.runtimeType, message, retryable);

  @override
  String toString() =>
      'CatalogError(failure: ${failure.runtimeType}, message: $message, '
      'retryable: $retryable)';
}
