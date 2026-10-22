import '../exercise.dart';
import 'normalize.dart';

/// Matchers e filtros puros de busca sobre listas de [Exercise].
///
/// Estas funções são **puras**: não realizam efeitos colaterais, não dependem
/// de rede e não modificam a lista de entrada. Elas preservam a ordem relativa
/// dos exercícios de entrada no resultado.
///
/// Cobrem os Requirements:
/// - 3.1 — busca por nome parcial, insensível a maiúsculas e acentos;
/// - 3.2 — filtro por grupo muscular (`bodyPart`);
/// - 3.3 — filtro por equipamento (`equipment`).

/// Retorna os exercícios de [exercises] cujo nome, após [normalize], contém o
/// [term] normalizado como subcadeia (correspondência parcial).
///
/// A comparação é insensível a maiúsculas/minúsculas e a acentos, pois tanto o
/// nome quanto o termo passam pela função [normalize]
/// (`toLowerCase` + `trim` + remoção de diacríticos).
///
/// Casos de borda:
/// - Se o termo normalizado for vazio (ex.: `''` ou apenas espaços), toda
///   string contém a subcadeia vazia, então todos os exercícios são retornados.
/// - A ordem relativa dos exercícios de entrada é preservada no resultado.
///
/// Atende ao Requirement 3.1 e à Property 2 do design.
List<Exercise> searchByName(List<Exercise> exercises, String term) {
  final normalizedTerm = normalize(term);
  return exercises
      .where((e) => normalize(e.name).contains(normalizedTerm))
      .toList();
}

/// Retorna os exercícios de [exercises] cujo campo `bodyPart` é exatamente
/// igual a [bodyPart].
///
/// A comparação é por igualdade estrita de string (o filtro de grupo muscular
/// da ExerciseDB usa valores categóricos fixos). A ordem relativa é preservada.
///
/// Atende ao Requirement 3.2 e à Property 3 do design.
List<Exercise> filterByBodyPart(List<Exercise> exercises, String bodyPart) {
  return exercises.where((e) => e.bodyPart == bodyPart).toList();
}

/// Retorna os exercícios de [exercises] cujo campo `equipment` é exatamente
/// igual a [equipment].
///
/// A comparação é por igualdade estrita de string (o filtro de equipamento da
/// ExerciseDB usa valores categóricos fixos). A ordem relativa é preservada.
///
/// Atende ao Requirement 3.3 e à Property 3 do design.
List<Exercise> filterByEquipment(List<Exercise> exercises, String equipment) {
  return exercises.where((e) => e.equipment == equipment).toList();
}
