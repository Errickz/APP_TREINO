import 'package:glados/glados.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/domain/search/exercise_filters.dart';
import 'package:gym_workout_app/domain/search/normalize.dart';

/// Conjunto pequeno de valores categóricos para gerar colisões de filtro.
const _bodyParts = <String>['chest', 'back', 'legs', 'arms'];
const _equipments = <String>['barbell', 'dumbbell', 'body weight', 'cable'];

/// Fragmentos de nome, incluindo acentos e variação de caixa, para exercitar
/// a normalização (Property 2).
const _nameParts = <String>[
  'Supino',
  'supino',
  'SÚPINO',
  'Rosca Direta',
  'agachamento',
  'Agachãmento',
  'Leg Press',
];

Generator<Exercise> _anyExercise() {
  return any.combine4(
    any.int,
    any.choose(_nameParts),
    any.choose(_bodyParts),
    any.choose(_equipments),
    (int n, String name, String bodyPart, String equipment) => Exercise(
      id: 'e$n',
      name: name,
      bodyPart: bodyPart,
      target: 'target',
      equipment: equipment,
      gifUrl: 'https://example.com/$n.gif',
    ),
  );
}

void main() {
  // Feature: gym-workout-app, Property 2: Busca por nome é parcial, insensível
  // a maiúsculas e a acentos.
  Glados2<List<Exercise>, String>(
    any.listWithLengthInRange(0, 30, _anyExercise()),
    any.choose(_nameParts),
  ).test(
    'Property 2: busca por nome retorna exatamente os exercícios cujo nome '
    'normalizado contém o termo normalizado',
    (exercises, term) {
      final result = searchByName(exercises, term);
      final nt = normalize(term);

      // Todo exercício do resultado satisfaz o critério.
      for (final e in result) {
        expect(normalize(e.name).contains(nt), isTrue);
      }
      // Nenhum exercício fora do critério foi omitido.
      final expected =
          exercises.where((e) => normalize(e.name).contains(nt)).toList();
      expect(result, equals(expected));
    },
  );

  // Feature: gym-workout-app, Property 3: Filtro por campo retorna o
  // subconjunto correto e completo.
  Glados2<List<Exercise>, String>(
    any.listWithLengthInRange(0, 30, _anyExercise()),
    any.choose(_bodyParts),
  ).test(
    'Property 3: filtro por bodyPart retorna todos e somente os exercícios '
    'com o bodyPart filtrado',
    (exercises, bodyPart) {
      final result = filterByBodyPart(exercises, bodyPart);
      final expected =
          exercises.where((e) => e.bodyPart == bodyPart).toList();
      expect(result, equals(expected));
      for (final e in result) {
        expect(e.bodyPart, bodyPart);
      }
    },
  );

  // Feature: gym-workout-app, Property 3: Filtro por campo retorna o
  // subconjunto correto e completo (equipamento).
  Glados2<List<Exercise>, String>(
    any.listWithLengthInRange(0, 30, _anyExercise()),
    any.choose(_equipments),
  ).test(
    'Property 3: filtro por equipment retorna todos e somente os exercícios '
    'com o equipment filtrado',
    (exercises, equipment) {
      final result = filterByEquipment(exercises, equipment);
      final expected =
          exercises.where((e) => e.equipment == equipment).toList();
      expect(result, equals(expected));
      for (final e in result) {
        expect(e.equipment, equipment);
      }
    },
  );
}
