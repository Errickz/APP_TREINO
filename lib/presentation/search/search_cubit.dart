import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/app_failure.dart';
import '../../domain/exercise.dart';
import '../../domain/exercise_repository.dart';
import 'search_state.dart';

/// Gerencia o estado da tela de busca de exercícios (Requirement 3).
///
/// Responsabilidades:
/// - Buscar por nome somente quando o termo tiver ao menos 2 caracteres,
///   aplicando debounce para evitar requisições a cada tecla (Requirement 3.1).
/// - Filtrar por grupo muscular e por equipamento de forma imediata
///   (Requirements 3.2, 3.3).
/// - Expor resultado vazio para a UI exibir "nenhum exercício encontrado"
///   (Requirement 3.4).
/// - Limpar termo e filtros restaurando o catálogo completo (Requirement 3.5).
/// - Em caso de falha, preservar os critérios e oferecer nova tentativa
///   (Requirement 3.6).
///
/// Os critérios atuais são sempre propagados nos estados emitidos, garantindo
/// que sejam preservados ao longo das transições.
class SearchCubit extends Cubit<SearchState> {
  SearchCubit(
    this._repository, {
    Duration debounceDuration = const Duration(milliseconds: 300),
  })  : _debounceDuration = debounceDuration,
        super(const SearchInitial());

  final ExerciseRepository _repository;

  /// Intervalo de debounce aplicado à busca por nome (Requirement 3.1).
  final Duration _debounceDuration;

  /// Temporizador de debounce pendente para a busca por nome. É cancelado a
  /// cada nova entrada e no [close].
  Timer? _debounceTimer;

  /// Número mínimo de caracteres (após `trim`) para disparar a busca por nome
  /// (Requirement 3.1).
  static const int _minTermLength = 2;

  SearchCriteria get _criteria => state.criteria;

  /// Atualiza o termo de busca e agenda a busca por nome com debounce
  /// (Requirement 3.1).
  ///
  /// A requisição só é disparada quando o termo, após `trim`, possui ao menos
  /// [_minTermLength] caracteres. Chamadas rápidas sucessivas cancelam o
  /// temporizador anterior, de modo que apenas a última entrada dentro da
  /// janela de debounce resulte em uma requisição.
  ///
  /// Se o termo ficar abaixo do mínimo (incluindo vazio) e não houver filtros
  /// ativos, o estado retorna para [SearchInitial] (catálogo completo). Havendo
  /// filtros ativos, a última busca por filtro é mantida e apenas o critério de
  /// termo é atualizado sem disparar nova requisição por nome.
  void searchByName(String term) {
    _debounceTimer?.cancel();

    final criteria = _criteria.copyWith(term: term);
    final trimmed = term.trim();

    if (trimmed.length < _minTermLength) {
      // Requirement 3.1: abaixo do mínimo não dispara busca por nome.
      if (criteria.bodyPart == null && criteria.equipment == null) {
        // Sem filtros ativos: volta ao catálogo completo (Requirement 3.5).
        emit(SearchInitial(criteria.copyWith(term: '')));
      } else {
        // Mantém o estado atual, apenas atualizando o termo nos critérios.
        emit(_withCriteria(criteria));
      }
      return;
    }

    _debounceTimer = Timer(_debounceDuration, () {
      _runSearch(
        criteria,
        () => _repository.searchByName(trimmed),
      );
    });
  }

  /// Aplica o filtro por grupo muscular de forma imediata (Requirement 3.2).
  void filterByBodyPart(String bodyPart) {
    _debounceTimer?.cancel();
    final criteria = _criteria.copyWith(bodyPart: bodyPart);
    _runSearch(
      criteria,
      () => _repository.searchByBodyPart(bodyPart),
    );
  }

  /// Aplica o filtro por equipamento de forma imediata (Requirement 3.3).
  void filterByEquipment(String equipment) {
    _debounceTimer?.cancel();
    final criteria = _criteria.copyWith(equipment: equipment);
    _runSearch(
      criteria,
      () => _repository.searchByEquipment(equipment),
    );
  }

  /// Limpa o termo e todos os filtros, restaurando o catálogo completo
  /// (Requirement 3.5).
  ///
  /// Cancela qualquer busca por nome pendente e emite [SearchInitial] com
  /// critérios vazios, equivalente ao estado inicial anterior a qualquer busca.
  void clear() {
    _debounceTimer?.cancel();
    emit(const SearchInitial());
  }

  /// Reexecuta a última busca preservando os critérios atuais (Requirement 3.6).
  ///
  /// Prioriza o termo de nome (quando válido), depois o filtro por grupo
  /// muscular e, por fim, o filtro por equipamento. Sem critérios ativos,
  /// retorna ao catálogo completo.
  Future<void> retry() async {
    final criteria = _criteria;
    final trimmed = criteria.term.trim();

    if (trimmed.length >= _minTermLength) {
      await _runSearch(criteria, () => _repository.searchByName(trimmed));
    } else if (criteria.bodyPart != null) {
      await _runSearch(
        criteria,
        () => _repository.searchByBodyPart(criteria.bodyPart!),
      );
    } else if (criteria.equipment != null) {
      await _runSearch(
        criteria,
        () => _repository.searchByEquipment(criteria.equipment!),
      );
    } else {
      emit(const SearchInitial());
    }
  }

  /// Executa uma operação de busca emitindo [SearchLoading] e, em seguida,
  /// [SearchLoaded] (sucesso) ou [SearchError] (falha), sempre preservando os
  /// [criteria] informados (Requirements 3.4, 3.6).
  Future<void> _runSearch(
    SearchCriteria criteria,
    Future<List<Exercise>> Function() operation,
  ) async {
    emit(SearchLoading(criteria));
    try {
      final results = await operation();
      emit(
        SearchLoaded(
          results: List<Exercise>.unmodifiable(results),
          criteria: criteria,
        ),
      );
    } on AppFailure catch (failure) {
      emit(_mapFailure(failure, criteria));
    }
  }

  /// Reconstrói o estado atual preservando seu tipo, substituindo apenas os
  /// critérios. Usado quando o termo muda sem disparar uma nova requisição.
  SearchState _withCriteria(SearchCriteria criteria) {
    final current = state;
    return switch (current) {
      SearchInitial() => SearchInitial(criteria),
      SearchLoading() => SearchLoading(criteria),
      SearchLoaded() => SearchLoaded(results: current.results, criteria: criteria),
      SearchError() => SearchError(
          failure: current.failure,
          message: current.message,
          criteria: criteria,
          retryable: current.retryable,
        ),
    };
  }

  /// Mapeia um [AppFailure] para o estado [SearchError] correspondente,
  /// preservando os [criteria] (Requirement 3.6) e definindo a mensagem
  /// amigável e se a falha permite nova tentativa.
  ///
  /// `retryable` é verdadeiro para falhas transitórias (timeout, rede, limite,
  /// offline) e falso para falhas de autenticação/configuração.
  SearchError _mapFailure(AppFailure failure, SearchCriteria criteria) {
    final (message, retryable) = switch (failure) {
      TimeoutError() => (
          'Não foi possível concluir a busca. Verifique sua conexão e tente '
              'novamente.',
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
      OfflineUnavailableError() => (
          'Busca indisponível no momento por falta de conexão.',
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
      PersistenceError() => (
          'Ocorreu um erro inesperado ao realizar a busca.',
          true,
        ),
    };

    return SearchError(
      failure: failure,
      message: message,
      criteria: criteria,
      retryable: retryable,
    );
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
