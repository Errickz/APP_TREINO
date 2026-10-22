import 'package:glados/glados.dart';
import 'package:gym_workout_app/domain/workout_validation.dart';

void main() {
  // Feature: gym-workout-app, Property 9: Validação de salvamento aceita
  // somente nome e quantidade válidos.
  Glados2<String, int>(
    // Nomes variados: vazios, só espaços, curtos, no limite e acima de 60.
    any.oneOf([
      any.choose(<String>['', '   ', ' a ', 'Treino A', '  Peito  ']),
      any.letters,
      any.nonEmptyLetters,
    ]),
    any.intInRange(-1, 55),
  ).test(
    'Property 9: salvamento é aceito sse nome (1..60 após trim) e quantidade '
    '(1..50) válidos; o nome persistido é o nome com trim',
    (name, exerciseCount) {
      // intInRange pode gerar negativos a partir de -1; normaliza para >= 0.
      final count = exerciseCount < 0 ? 0 : exerciseCount;

      final validation = validateWorkoutFields(
        name: name,
        exerciseCount: count,
      );

      final trimmed = name.trim();
      final nameOk = trimmed.isNotEmpty && trimmed.length <= 60;
      final countOk = count >= 1 && count <= 50;

      // Aceito se, e somente se, nome e quantidade válidos.
      expect(validation.isValid, nameOk && countOk);

      // trimmedName é sempre o nome com trim aplicado.
      expect(validation.trimmedName, trimmed);

      // Violações refletem exatamente as regras.
      expect(validation.hasInvalidName, !nameOk);
      expect(validation.hasEmptyExercises, count < 1);
      expect(validation.hasTooManyExercises, count > 50);
    },
  );
}
