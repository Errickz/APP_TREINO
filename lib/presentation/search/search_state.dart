import '../../domain/app_failure.dart';
import '../../domain/exercise.dart';

/// Critérios de busca mantidos e preservados entre os estados do [SearchCubit]
/// (Requirement 3).
///
/// Representa o conjunto de parâmetros que o usuário aplicou: termo de busca por
/// nome ([term]), filtro por grupo muscular ([bodyPart]) e filtro por
/// equipamento ([equipment]). É um objeto de valor **imutável** com igualdade
/// estrutural, de modo que os critérios possam ser comparados e preservados ao
/// transitar entre estados (em especial no estado de erro — Requirement 3.6).
///
/// Um filtro ausente é representado por `null` (não aplicado). O [term] vazio
/// indica que nenhuma busca por nome está ativa.
class SearchCriteria {
  const SearchCriteria({
    this.term = '',
    this.bodyPart,
    this.equipment,
  });

  /// Termo de busca por nome do exercício (vazio quando não há busca ativa).
  final String term;

  /// Filtro por grupo muscular alvo, ou `null` quando não aplicado.
  final String? bodyPart;

  /// Filtro por equipamento, ou `null` quando não aplicado.
  final String? equipment;

  /// Critério vazio equivalente ao estado inicial (catálogo completo).
  static const SearchCriteria empty = SearchCriteria();

  /// Indica se nenhum critério está ativo (termo vazio e filtros ausentes).
  bool get isEmpty =>
      term.trim().isEmpty && bodyPart == null && equipment == null;

  /// Retorna uma cópia dos critérios com os campos informados substituídos.
  ///
  /// Como [bodyPart] e [equipment] são anuláveis, os parâmetros
  /// [clearBodyPart]/[clearEquipment] permitem **remover** explicitamente um
  /// filtro (defini-lo como `null`), já que passar `null` em um `copyWith`
  /// convencional não distingue "manter" de "limpar".
  SearchCriteria copyWith({
    String? term,
    String? bodyPart,
    String? equipment,
    bool clearBodyPart = false,
    bool clearEquipment = false,
  }) {
    return SearchCriteria(
      term: term ?? this.term,
      bodyPart: clearBodyPart ? null : (bodyPart ?? this.bodyPart),
      equipment: clearEquipment ? null : (equipment ?? this.equipment),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchCriteria &&
        other.term == term &&
        other.bodyPart == bodyPart &&
        other.equipment == equipment;
  }

  @override
  int get hashCode => Object.hash(term, bodyPart, equipment);

  @override
  String toString() =>
      'SearchCriteria(term: $term, bodyPart: $bodyPart, equipment: $equipment)';
}

/// Estados do [SearchCubit] que modelam a busca de exercícios (Requirement 3).
///
/// Por ser uma `sealed class`, o compilador garante exaustividade ao usar
/// `switch` sobre um [SearchState] na camada de UI. Todos os estados carregam
/// os [criteria] atuais, de modo que os critérios sejam preservados ao longo
/// das transições (Requirement 3.6).
sealed class SearchState {
  const SearchState(this.criteria);

  /// Critérios de busca associados a este estado.
  final SearchCriteria criteria;
}

/// Estado inicial: nenhum critério aplicado; a UI exibe o catálogo completo
/// (Requirement 3.5).
class SearchInitial extends SearchState {
  const SearchInitial([SearchCriteria criteria = SearchCriteria.empty])
      : super(criteria);

  @override
  bool operator ==(Object other) =>
      other is SearchInitial && other.criteria == criteria;

  @override
  int get hashCode => Object.hash((SearchInitial).hashCode, criteria);

  @override
  String toString() => 'SearchInitial(criteria: $criteria)';
}

/// Busca em andamento para os [criteria] informados.
///
/// Emitido enquanto a requisição ao repositório está pendente. A UI exibe um
/// indicador de carregamento.
class SearchLoading extends SearchState {
  const SearchLoading(super.criteria);

  @override
  bool operator ==(Object other) =>
      other is SearchLoading && other.criteria == criteria;

  @override
  int get hashCode => Object.hash((SearchLoading).hashCode, criteria);

  @override
  String toString() => 'SearchLoading(criteria: $criteria)';
}

/// Busca concluída com sucesso para os [criteria] informados.
///
/// [results] contém os exercícios retornados na ordem recebida. Quando
/// [results] está vazio, a UI exibe a mensagem "nenhum exercício encontrado
/// para os critérios aplicados" (Requirement 3.4).
class SearchLoaded extends SearchState {
  const SearchLoaded({
    required this.results,
    required SearchCriteria criteria,
  }) : super(criteria);

  /// Exercícios retornados pela busca (pode estar vazio — Requirement 3.4).
  final List<Exercise> results;

  /// Indica se a busca não retornou nenhum exercício (Requirement 3.4).
  bool get isEmpty => results.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchLoaded &&
        other.criteria == criteria &&
        _listEquals(other.results, results);
  }

  @override
  int get hashCode => Object.hash(criteria, Object.hashAll(results));

  @override
  String toString() =>
      'SearchLoaded(results: ${results.length} itens, criteria: $criteria)';

  static bool _listEquals(List<Exercise> a, List<Exercise> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Falha ao executar a busca (Requirement 3.6).
///
/// Os [criteria] informados são preservados para que a UI possa reexibi-los e
/// oferecer a opção de nova tentativa (Requirement 3.6). [failure] é o erro de
/// domínio original; [message] é a mensagem amigável; [retryable] indica se a
/// falha permite nova tentativa.
class SearchError extends SearchState {
  const SearchError({
    required this.failure,
    required this.message,
    required SearchCriteria criteria,
    required this.retryable,
  }) : super(criteria);

  /// Erro de domínio que originou a falha.
  final AppFailure failure;

  /// Mensagem amigável para exibição na UI.
  final String message;

  /// Indica se a falha permite nova tentativa.
  final bool retryable;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchError &&
        other.failure.runtimeType == failure.runtimeType &&
        other.message == message &&
        other.criteria == criteria &&
        other.retryable == retryable;
  }

  @override
  int get hashCode =>
      Object.hash(failure.runtimeType, message, criteria, retryable);

  @override
  String toString() =>
      'SearchError(failure: ${failure.runtimeType}, message: $message, '
      'criteria: $criteria, retryable: $retryable)';
}
