import 'exercise.dart';
import 'exercise_page.dart';

/// Contrato de domínio que orquestra cache, rede e conectividade para obter
/// exercícios da ExerciseDB_API.
///
/// Centraliza as regras dos Requirements 1 (catálogo + paginação), 3 (busca),
/// 6 (cache/expiração/offline) e 7 (erros de integração). As implementações
/// mapeiam falhas de infraestrutura para `AppFailure` (lançado), de modo que
/// os Cubits possam consumi-las de forma consistente.
abstract class ExerciseRepository {
  /// Requirement 1: retorna uma página de no máximo 20 exercícios.
  ///
  /// Quando online, obtém a página correspondente da API, atualiza o cache
  /// (upsert + LRU) e devolve o resultado paginado. Quando offline, pagina
  /// sobre os exercícios presentes no cache.
  Future<ExercisePage> getCatalogPage({required int page});

  /// Requirement 2/6: obtém um exercício aplicando a política de origem
  /// (cache/rede/offline) e a expiração de 24 horas.
  Future<Exercise> getExercise(String id);

  /// Requirement 3.1: busca por nome (parcial, insensível a maiúsculas/acentos).
  Future<List<Exercise>> searchByName(String term);

  /// Requirement 3.2: busca por grupo muscular alvo.
  Future<List<Exercise>> searchByBodyPart(String bodyPart);

  /// Requirement 3.3: busca por equipamento.
  Future<List<Exercise>> searchByEquipment(String equipment);
}
