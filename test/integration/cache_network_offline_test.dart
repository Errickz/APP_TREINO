import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gym_workout_app/domain/app_failure.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/data/cache/cache_store.dart';
import 'package:gym_workout_app/data/connectivity/connectivity_service.dart';
import 'package:gym_workout_app/data/exercise_repository_impl.dart';
import 'package:gym_workout_app/data/remote/exercise_db_client.dart';
import 'package:gym_workout_app/data/remote/exercise_dto.dart';

ExerciseDto _dto(String id, {String name = 'Exercise'}) => ExerciseDto(
      id: id,
      name: name,
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$id.gif',
    );

/// Cliente mockado que conta chamadas e devolve DTOs por nome.
class _MockClient implements ExerciseDbClient {
  _MockClient(this.byName);
  final Map<String, List<ExerciseDto>> byName;
  int fetchByNameCalls = 0;

  @override
  Future<List<ExerciseDto>> fetchExercises({
    required int offset,
    required int limit,
  }) async =>
      const [];

  @override
  Future<List<ExerciseDto>> fetchByName(String name) async {
    fetchByNameCalls++;
    return byName[name] ?? const [];
  }

  @override
  Future<List<ExerciseDto>> fetchByBodyPart(String bodyPart) async => const [];

  @override
  Future<List<ExerciseDto>> fetchByEquipment(String equipment) async =>
      const [];
}

/// Conectividade controlável para o teste de integração.
class _ToggleConnectivity implements ConnectivityService {
  bool online = true;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> onConnectivityChanged() => Stream<bool>.value(online);
}

Future<Database> _openInMemory(OpenDatabaseOptions options) =>
    databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: options);

void main() {
  sqfliteFfiInit();

  // Requirements 6.2, 6.3, 6.4, 6.5: fluxo cache→rede→offline de ponta a ponta
  // com CacheStore real (SQLite em memória), ConnectivityService real (toggle)
  // e ExerciseDbClient mockado.
  test('fluxo cache→rede→offline resolve a origem corretamente', () async {
    final cache = SqfliteCacheStore(opener: _openInMemory);
    final connectivity = _ToggleConnectivity();
    final client = _MockClient({
      'e1': [_dto('e1', name: 'Da API')],
    });

    var clock = DateTime.fromMillisecondsSinceEpoch(1000000000);
    final repo = ExerciseRepositoryImpl(
      client: client,
      cache: cache,
      connectivity: connectivity,
      now: () => clock,
    );

    // 1) Online, ausente no cache: busca na API e armazena (Req 6.1/6.3).
    final first = await repo.getExercise('e1');
    expect(first.name, 'Da API');
    expect(client.fetchByNameCalls, 1);

    // 2) Online, presente e fresco (<=24h): serve do cache sem nova chamada
    //    à API (Req 6.2).
    final cached = await repo.getExercise('e1');
    expect(cached.name, 'Da API');
    expect(client.fetchByNameCalls, 1, reason: 'cache fresco não chama a API');

    // 3) Offline, presente no cache: serve do cache independentemente da idade
    //    (Req 6.4).
    connectivity.online = false;
    clock = clock.add(const Duration(days: 3)); // mesmo expirado...
    final offlineHit = await repo.getExercise('e1');
    expect(offlineHit.name, 'Da API');
    expect(client.fetchByNameCalls, 1, reason: 'offline não chama a API');

    // 4) Offline, ausente no cache: indisponibilidade por falta de conexão,
    //    preservando o cache (Req 6.5).
    Object? caught;
    try {
      await repo.getExercise('inexistente');
    } on AppFailure catch (e) {
      caught = e;
    }
    expect(caught, isA<OfflineUnavailableError>());
    expect(await cache.countExercises(), 1, reason: 'cache preservado');

    await cache.close();
  });
}
