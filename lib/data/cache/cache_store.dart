import 'package:sqflite/sqflite.dart';

import '../../domain/cached_exercise.dart';
import '../../domain/exercise.dart';
import '../../domain/workout.dart';

/// Abstração sobre o SQLite para o cache de exercícios e a persistência de
/// treinos (Requirement 6 e Requirement 4.3).
///
/// As operações de exercícios dão suporte à política de cache do
/// `ExerciseRepository`: expiração de 24h ([getExercise]/[upsertExercise]) e
/// limite de 1.500 registros com remoção LRU ([countExercises],
/// [evictLeastRecentlyAccessed], [touchExercise]).
///
/// As operações de treino preservam o nome e a sequência ordenada de
/// exercícios (round-trip fiel — Property 8 / Requirement 4.3).
abstract class CacheStore {
  // --- Exercícios ---

  /// Retorna o exercício em cache identificado por [id], ou `null` se ausente.
  Future<CachedExercise?> getExercise(String id);

  /// Retorna todos os exercícios presentes no cache.
  Future<List<CachedExercise>> getAllExercises();

  /// Insere ou atualiza [exercise] no cache com o instante [storedAt].
  ///
  /// Em uma inserção nova, `accessed_at` é igualado a [storedAt]. Em uma
  /// atualização de um registro existente, `accessed_at` é preservado.
  Future<void> upsertExercise(Exercise exercise, DateTime storedAt);

  /// Atualiza o instante de último acesso (LRU) do exercício [id] para
  /// [accessedAt]. Não tem efeito se o exercício não existir.
  Future<void> touchExercise(String id, DateTime accessedAt);

  /// Retorna a quantidade de exercícios atualmente em cache.
  Future<int> countExercises();

  /// Remove os [howMany] exercícios acessados há mais tempo (menor
  /// `accessed_at`), mantendo o limite de registros do cache.
  Future<void> evictLeastRecentlyAccessed(int howMany);

  // --- Treinos ---

  /// Persiste [workout] (cabeçalho + exercícios ordenados por posição).
  Future<void> saveWorkout(Workout workout);

  /// Retorna todos os treinos persistidos, cada um com seus exercícios na
  /// ordem original (por `position`).
  Future<List<Workout>> getWorkouts();

  /// Retorna o treino [id] com seus exercícios na ordem original, ou `null`.
  Future<Workout?> getWorkout(String id);

  /// Libera recursos (fecha a conexão com o banco).
  Future<void> close();
}

/// Assinatura para abrir/criar o banco. Permite injetar um banco em memória
/// nos testes (`sqflite_common_ffi`).
typedef DatabaseOpener = Future<Database> Function(OpenDatabaseOptions options);

/// Implementação de [CacheStore] baseada em `sqflite` (SQLite).
///
/// O caminho de abertura do banco é injetável via [opener] para que os testes
/// possam usar um banco em memória. As chaves estrangeiras com
/// `ON DELETE CASCADE` são habilitadas via `PRAGMA foreign_keys = ON`.
class SqfliteCacheStore implements CacheStore {
  SqfliteCacheStore({
    required DatabaseOpener opener,
    this.path = 'gym_workout_cache.db',
  }) : _opener = opener;

  /// Versão do esquema do banco.
  static const int schemaVersion = 1;

  /// Caminho (ou nome) do arquivo de banco. Para bancos em memória use
  /// `inMemoryDatabasePath` do `sqflite_common_ffi`.
  final String path;

  final DatabaseOpener _opener;

  Database? _db;

  /// Abre o banco sob demanda, aplicando o esquema e as pragmas necessárias.
  Future<Database> _database() async {
    final existing = _db;
    if (existing != null) return existing;

    final db = await _opener(
      OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: _onConfigure,
        onCreate: _onCreate,
      ),
    );
    _db = db;
    return db;
  }

  /// Habilita o enforcement de chaves estrangeiras (ON DELETE CASCADE).
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Cria o esquema do banco conforme a seção "Esquema do banco SQLite" do
  /// documento de design.
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        id          TEXT PRIMARY KEY,
        name        TEXT NOT NULL,
        body_part   TEXT NOT NULL,
        target      TEXT NOT NULL,
        equipment   TEXT NOT NULL,
        gif_url     TEXT NOT NULL,
        stored_at   INTEGER NOT NULL,
        accessed_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_exercises_accessed_at ON exercises(accessed_at)',
    );

    await db.execute('''
      CREATE TABLE workouts (
        id       TEXT PRIMARY KEY,
        name     TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )
    ''');

    // A tabela workout_exercises guarda um *snapshot* completo do exercício
    // para garantir um round-trip fiel (Property 8), independentemente da
    // presença do registro na tabela `exercises` (que está sujeita a
    // expiração/eviction LRU).
    await db.execute('''
      CREATE TABLE workout_exercises (
        workout_id  TEXT NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
        position    INTEGER NOT NULL,
        exercise_id TEXT NOT NULL,
        name        TEXT NOT NULL,
        body_part   TEXT NOT NULL,
        target      TEXT NOT NULL,
        equipment   TEXT NOT NULL,
        gif_url     TEXT NOT NULL,
        PRIMARY KEY (workout_id, position)
      )
    ''');
  }

  // --- Exercícios ---

  @override
  Future<CachedExercise?> getExercise(String id) async {
    final db = await _database();
    final rows = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _cachedExerciseFromRow(rows.first);
  }

  @override
  Future<List<CachedExercise>> getAllExercises() async {
    final db = await _database();
    final rows = await db.query('exercises');
    return rows.map(_cachedExerciseFromRow).toList();
  }

  @override
  Future<void> upsertExercise(Exercise exercise, DateTime storedAt) async {
    final db = await _database();
    final storedMs = storedAt.millisecondsSinceEpoch;

    // Em uma inserção nova, accessed_at = stored_at. Em uma atualização,
    // preservamos o accessed_at existente (LRU). Fazemos isso dentro de uma
    // transação para garantir atomicidade entre a leitura e a escrita.
    await db.transaction((txn) async {
      final existing = await txn.query(
        'exercises',
        columns: ['accessed_at'],
        where: 'id = ?',
        whereArgs: [exercise.id],
        limit: 1,
      );
      final accessedMs = existing.isEmpty
          ? storedMs
          : existing.first['accessed_at'] as int;

      await txn.insert(
        'exercises',
        {
          'id': exercise.id,
          'name': exercise.name,
          'body_part': exercise.bodyPart,
          'target': exercise.target,
          'equipment': exercise.equipment,
          'gif_url': exercise.gifUrl,
          'stored_at': storedMs,
          'accessed_at': accessedMs,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> touchExercise(String id, DateTime accessedAt) async {
    final db = await _database();
    await db.update(
      'exercises',
      {'accessed_at': accessedAt.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<int> countExercises() async {
    final db = await _database();
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM exercises');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> evictLeastRecentlyAccessed(int howMany) async {
    if (howMany <= 0) return;
    final db = await _database();
    // Remove os `howMany` exercícios com menor accessed_at (acessados há mais
    // tempo). O desempate por `id` torna a seleção determinística.
    await db.execute(
      '''
      DELETE FROM exercises
      WHERE id IN (
        SELECT id FROM exercises
        ORDER BY accessed_at ASC, id ASC
        LIMIT ?
      )
      ''',
      [howMany],
    );
  }

  // --- Treinos ---

  @override
  Future<void> saveWorkout(Workout workout) async {
    final db = await _database();
    await db.transaction((txn) async {
      // Substitui completamente o treino e seus exercícios (idempotente).
      await txn.delete(
        'workout_exercises',
        where: 'workout_id = ?',
        whereArgs: [workout.id],
      );
      await txn.insert(
        'workouts',
        {
          'id': workout.id,
          'name': workout.name,
          'saved_at': workout.savedAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final batch = txn.batch();
      for (var position = 0; position < workout.exercises.length; position++) {
        final exercise = workout.exercises[position];
        batch.insert(
          'workout_exercises',
          {
            'workout_id': workout.id,
            'position': position,
            'exercise_id': exercise.id,
            'name': exercise.name,
            'body_part': exercise.bodyPart,
            'target': exercise.target,
            'equipment': exercise.equipment,
            'gif_url': exercise.gifUrl,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<Workout>> getWorkouts() async {
    final db = await _database();
    final workoutRows = await db.query('workouts', orderBy: 'saved_at ASC');
    final workouts = <Workout>[];
    for (final row in workoutRows) {
      workouts.add(await _workoutFromRow(db, row));
    }
    return workouts;
  }

  @override
  Future<Workout?> getWorkout(String id) async {
    final db = await _database();
    final rows = await db.query(
      'workouts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _workoutFromRow(db, rows.first);
  }

  @override
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }

  // --- Mapeadores ---

  CachedExercise _cachedExerciseFromRow(Map<String, Object?> row) {
    return CachedExercise(
      exercise: Exercise(
        id: row['id'] as String,
        name: row['name'] as String,
        bodyPart: row['body_part'] as String,
        target: row['target'] as String,
        equipment: row['equipment'] as String,
        gifUrl: row['gif_url'] as String,
      ),
      storedAt: DateTime.fromMillisecondsSinceEpoch(row['stored_at'] as int),
      accessedAt:
          DateTime.fromMillisecondsSinceEpoch(row['accessed_at'] as int),
    );
  }

  Future<Workout> _workoutFromRow(Database db, Map<String, Object?> row) async {
    final id = row['id'] as String;
    final exerciseRows = await db.query(
      'workout_exercises',
      where: 'workout_id = ?',
      whereArgs: [id],
      orderBy: 'position ASC',
    );
    final exercises = exerciseRows
        .map(
          (e) => Exercise(
            id: e['exercise_id'] as String,
            name: e['name'] as String,
            bodyPart: e['body_part'] as String,
            target: e['target'] as String,
            equipment: e['equipment'] as String,
            gifUrl: e['gif_url'] as String,
          ),
        )
        .toList();
    return Workout(
      id: id,
      name: row['name'] as String,
      exercises: exercises,
      savedAt: DateTime.fromMillisecondsSinceEpoch(row['saved_at'] as int),
    );
  }
}
