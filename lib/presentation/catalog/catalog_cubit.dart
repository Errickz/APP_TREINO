import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_failure.dart';
import '../../domain/exercise.dart';
import '../../domain/exercise_page.dart';
import '../../domain/exercise_repository.dart';
import 'catalog_state.dart';

/// Gerencia o estado da tela de catálogo de exercícios (Requirement 1).
///
/// Responsabilidades:
/// - Carregar a primeira página exibindo um indicador de carregamento
///   (Requirements 1.1, 1.2).
/// - Implementar scroll infinito, carregando e acumulando páginas de no máximo
///   20 itens conforme o usuário rola a lista (Requirements 1.3, 1.4).
/// - Não solicitar novos dados quando não há mais páginas (Requirement 1.5).
/// - Tratar timeout/erros exibindo mensagem e opção de nova tentativa
///   (Requirements 1.6, 1.7).
class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit(this._repository) : super(const CatalogLoading());

  final ExerciseRepository _repository;

  /// Carrega a primeira página do catálogo (page 0).
  ///
  /// Emite [CatalogLoading] (Requirement 1.2) e, em caso de sucesso,
  /// [CatalogLoaded] com os itens da primeira página (Requirements 1.1, 1.3).
  /// Em caso de falha, emite [CatalogError] com a mensagem e a possibilidade de
  /// retry correspondentes ao erro (Requirement 1.6).
  Future<void> loadFirstPage() async {
    emit(const CatalogLoading());
    try {
      final ExercisePage result = await _repository.getCatalogPage(page: 0);
      emit(
        CatalogLoaded(
          items: List<Exercise>.unmodifiable(result.items),
          page: result.page,
          hasMore: result.hasMore,
        ),
      );
    } on AppFailure catch (failure) {
      emit(_mapFailure(failure));
    }
  }

  /// Carrega a próxima página e acumula os itens à lista atual (scroll infinito,
  /// Requirement 1.4).
  ///
  /// Só age quando o estado atual é [CatalogLoaded] com [hasMore] verdadeiro e
  /// nenhum carregamento de página em andamento. Quando não há mais páginas,
  /// não solicita novos dados (Requirement 1.5).
  ///
  /// Uma falha ao carregar a próxima página reverte [CatalogLoaded.isLoadingMore]
  /// para `false`, preservando os itens já exibidos.
  Future<void> loadNextPage() async {
    final current = state;
    // Requirement 1.5: sem mais páginas (ou sem dados carregados) => não faz nada.
    if (current is! CatalogLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }

    emit(current.copyWith(isLoadingMore: true));
    try {
      final nextPage = current.page + 1;
      final ExercisePage result =
          await _repository.getCatalogPage(page: nextPage);
      emit(
        CatalogLoaded(
          items: List<Exercise>.unmodifiable([
            ...current.items,
            ...result.items,
          ]),
          page: result.page,
          hasMore: result.hasMore,
          isLoadingMore: false,
        ),
      );
    } on AppFailure {
      // Preserva os itens já carregados; apenas encerra o indicador de "carregar mais".
      emit(current.copyWith(isLoadingMore: false));
    }
  }

  /// Reenvia a solicitação da primeira página após uma falha (Requirement 1.7).
  Future<void> retry() => loadFirstPage();

  /// Mapeia um [AppFailure] para o estado [CatalogError] correspondente,
  /// definindo a mensagem amigável e se a falha permite nova tentativa
  /// (Requirements 1.6, 7.3, 7.4, 7.6, 6.5).
  CatalogError _mapFailure(AppFailure failure) {
    final (message, retryable) = switch (failure) {
      TimeoutError() => (
          'Não foi possível carregar os exercícios. Verifique sua conexão e '
              'tente novamente.',
          true,
        ),
      NetworkError() => (
          'Falha de comunicação com o serviço de exercícios. Tente novamente.',
          true,
        ),
      RateLimitError() => (
          'Limite de uso atingido. Aguarde um momento e tente novamente mais '
              'tarde.',
          true,
        ),
      AuthError() => (
          'Falha de autenticação com o serviço de exercícios.',
          false,
        ),
      AuthConfigurationError() => (
          'Serviço de exercícios não configurado corretamente.',
          false,
        ),
      OfflineUnavailableError() => (
          'Conteúdo indisponível no momento por falta de conexão.',
          true,
        ),
      PersistenceError() => (
          'Ocorreu um erro inesperado ao carregar os exercícios.',
          true,
        ),
    };

    return CatalogError(
      failure: failure,
      message: message,
      retryable: retryable,
    );
  }
}
