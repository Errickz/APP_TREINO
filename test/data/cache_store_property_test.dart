import 'package:glados/glados.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/domain/workout.dart';
import 'package:gym_workout_app/data/cache/cache_store.dart';

Exercise _ex(int i) => Exercise(
      id: 'e$i',
      name: 'Exercise $i',
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$i.gif',
    );

/// Abre um banco SQLite **em memória** usando sqflite_common_ffi, para testes.
Future<Database> _openInMemory(OpenDatabaseOptions options) {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: options,
  );
}

SqfliteCacheStore _newStore() => SqfliteCacheStore(opener: _openInMemory);

void main() {
  // Inicializa o FFI uma vez para toda a suíte.
  sqfliteFfiInit();

  // Feature: gym-workout-app, Property 8: Persistência de treino é um
  // round-trip fiel.
  Glados2<String, int>(
    any.choose(<String>['Treino A', 'Peito e Tríceps', 'Full Body', 'X']),
    any.intInRange(1, 50),
  ).test(
    'Property 8: salvar e recarregar um treino reconstitui nome e sequência '
    'ordenada de exercícios',
    (name, n) async {
      final store = _newStore();
      final exercises = <Exercise>[for (var i = 0; i < n; i++) _ex(i)];
      final workout = Workout(
        id: 'w1',
        name: name,
        exercises: exercises,
        savedAt: DateTime.fromMillisecondsSinceEpoch(123456),
      );

      await store.saveWorkout(workout);
      final loaded = await store.getWorkout('w1');

      expect(loaded, isNotNull);
      expect(loaded!.name, name);
      expect(loaded.exercises, equals(exercises));
      await store.close();
    },
  );

  // Feature: gym-workout-app, Property 14: O cache respeita o limite de 1500
  // com remoção LRU.
  //
  // Para manter o teste rápido, parametriza-se o limite via uma sequência de
  // inserções/toques e aplica-se a eviction até um limite pequeno `cap`,
  // verificando que: (a) a contagem nunca excede `cap`; (b) os removidos são
  // exatamente os de menor accessed_at.
  Glados<int>(any.intInRange(1, 10)).test(
    'Property 14: após inserir mais que o limite e remover os LRU, a contagem '
    'fica no limite e os remanescentes são os mais recentemente acessados',
    (cap) async {
      final store = _newStore();
      const total = 20;

      // Insere `total` exercícios; upsert define accessed_at = stored_at.
      // Usa instantes crescentes para dar uma ordem de acesso determinística:
      // e0 é o mais antigo (menor accessed_at), e(total-1) o mais recente.
      for (var i = 0; i < total; i++) {
        await store.upsertExercise(
          _ex(i),
          DateTime.fromMillisecondsSinceEpoch(1000 + i),
        );
      }
      expect(await store.countExercises(), total);

      // Aplica a eviction LRU para manter no máximo `cap` registros.
      final count = await store.countExercises();
      if (count > cap) {
        await store.evictLeastRecentlyAccessed(count - cap);
      }

      // (a) contagem no limite.
      expect(await store.countExercises(), cap);

      // (b) os remanescentes são os `cap` com maior accessed_at, isto é,
      // e(total-cap) .. e(total-1).
      final remaining = await store.getAllExercises();
      final remainingIds = remaining.map((c) => c.exercise.id).toSet();
      final expectedIds = <String>{
        for (var i = total - cap; i < total; i++) 'e$i',
      };
      expect(remainingIds, equals(expectedIds));
      await store.close();
    },
  );
}
