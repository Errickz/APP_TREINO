import 'package:glados/glados.dart';
import 'package:gym_workout_app/domain/app_failure.dart';
import 'package:gym_workout_app/domain/cached_exercise.dart';
import 'package:gym_workout_app/domain/exercise.dart';
import 'package:gym_workout_app/domain/workout.dart';
import 'package:gym_workout_app/data/cache/cache_store.dart';
import 'package:gym_workout_app/data/connectivity/connectivity_service.dart';
import 'package:gym_workout_app/data/exercise_repository_impl.dart';
import 'package:gym_workout_app/data/remote/exercise_db_client.dart';
import 'package:gym_workout_app/data/remote/exercise_dto.dart';

Exercise _ex(String id, {String name = 'Exercise'}) => Exercise(
      id: id,
      name: name,
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$id.gif',
    );

ExerciseDto _dto(String id, {String name = 'Exercise'}) => ExerciseDto(
      id: id,
      name: name,
      bodyPart: 'chest',
      target: 'pectorals',
      equipment: 'barbell',
      gifUrl: 'https://example.com/$id.gif',
    );

/// CacheStore falso em memória, suficiente para a política de origem.
class _FakeCacheStore implements CacheStore {
  final Map<String, CachedExercise> _store = {};
  int upserts = 0;

  void seed(CachedExercise cached) => _store[cached.exercise.id] = cached;

  @override
  Future<CachedExercise?> getExercise(String id) async => _store[id];

  @override
  Future<List<CachedExercise>> getAllExercises() async =>
      _store.values.toList();

  @override
  Future<void> upsertExercise(Exercise exercise, DateTime storedAt) async {
    upserts++;
    _store[exercise.id] = CachedExercise(
      exercise: exercise,
      storedAt: storedAt,
      accessedAt: storedAt,
    );
  }

  @override
  Future<void> touchExercise(String id, DateTime accessedAt) async {
    final c = _store[id];
    if (c != null) {
      _store[id] = c.copyWith(accessedAt: accessedAt);
    }
  }

  @override
  Future<int> countExercises() async => _store.length;

  @override
  Future<void> evictLeastRecentlyAccessed(int howMany) async {}

  @override
  Future<void> saveWorkout(Workout workout) async {}

  @override
  Future<List<Workout>> getWorkouts() async => const [];

  @override
  Future<Workout?> getWorkout(String id) async => null;

  @override
  Future<void> close() async {}
}

class _FakeConnectivity implements ConnectivityService {
  _FakeConnectivity(this.online);
  final bool online;

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> onConnectivityChanged() => Stream<bool>.value(online);
}

/// Cliente falso que conta as chamadas e devolve DTOs configurados por nome.
class _FakeClient implements ExerciseDbClient {
  _FakeClient({this.byName = const {}});
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

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1000000000);

  // Feature: gym-workout-app, Property 15: A resolução da origem dos dados
  // respeita expiração e conectividade.
  //
  // Para um exercício em cache, varia-se a conectividade e a idade (em horas)
  // em torno do limite de 24h e verifica-se a origem servida.
  Glados2<bool, int>(any.bool, any.intInRange(0, 49)).test(
    'Property 15: offline serve cache (qualquer idade); online <=24h serve '
    'cache sem API; online >24h chama a API e atualiza o cache',
    (online, ageHours) async {
      final cache = _FakeCacheStore();
      final storedAt = now.subtract(Duration(hours: ageHours));
      cache.seed(CachedExercise(
        exercise: _ex('e1', name: 'Antigo'),
        storedAt: storedAt,
        accessedAt: storedAt,
      ));

      final client = _FakeClient(byName: {
        'e1': [_dto('e1', name: 'Atualizado')],
      });

      final repo = ExerciseRepositoryImpl(
        client: client,
        cache: cache,
        connectivity: _FakeConnectivity(online),
        now: () => now,
      );

      final result = await repo.getExercise('e1');

      final expired = ageHours > 24;
      if (!online) {
        // Offline: serve o cache independentemente da idade, sem chamar a API.
        expect(client.fetchByNameCalls, 0);
        expect(result.name, 'Antigo');
      } else if (!expired) {
        // Online e fresco (<=24h): serve o cache sem chamar a API.
        expect(client.fetchByNameCalls, 0);
        expect(result.name, 'Antigo');
      } else {
        // Online e expirado (>24h): chama a API e atualiza o cache.
        expect(client.fetchByNameCalls, greaterThanOrEqualTo(1));
        expect(result.name, 'Atualizado');
        final refreshed = await cache.getExercise('e1');
        expect(refreshed!.exercise.name, 'Atualizado');
      }
    },
  );

  // Feature: gym-workout-app, Property 16: Offline sem cache sinaliza
  // indisponibilidade preservando o cache.
  Glados<String>(any.nonEmptyLetters).test(
    'Property 16: offline + exercício ausente lança OfflineUnavailableError e '
    'não modifica o cache',
    (missingId) async {
      final cache = _FakeCacheStore();
      // Semeia um exercício diferente para checar que o cache permanece intacto.
      cache.seed(CachedExercise(
        exercise: _ex('other'),
        storedAt: now,
        accessedAt: now,
      ));
      final client = _FakeClient();
      final repo = ExerciseRepositoryImpl(
        client: client,
        cache: cache,
        connectivity: _FakeConnectivity(false),
        now: () => now,
      );

      final countBefore = await cache.countExercises();

      Object? caught;
      try {
        await repo.getExercise('missing_$missingId');
      } on AppFailure catch (e) {
        caught = e;
      }

      expect(caught, isA<OfflineUnavailableError>());
      // Cache preservado: nenhum upsert, mesma contagem.
      expect(cache.upserts, 0);
      expect(await cache.countExercises(), countBefore);
    },
  );
}
