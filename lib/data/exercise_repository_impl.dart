import 'package:dio/dio.dart';

import '../domain/app_failure.dart';
import '../domain/cached_exercise.dart';
import '../domain/exercise.dart';
import '../domain/exercise_page.dart';
import '../domain/exercise_repository.dart';
import '../domain/pagination.dart';
import '../domain/search/exercise_filters.dart' as filters;
import 'cache/cache_store.dart';
import 'connectivity/connectivity_service.dart';
import 'remote/exercise_db_client.dart';
import 'remote/exercise_dto.dart';

/// Implementação de [ExerciseRepository] que orquestra o [ExerciseDbClient]
/// (rede), o [CacheStore] (persistência local) e o [ConnectivityService]
/// (estado de conexão).
///
/// Responsabilidades (Requirements 1, 3, 6, 7):
/// - Resolução de origem dos dados de [getExercise] conforme conectividade e
///   idade do cache (Property 15) e tratamento de offline sem cache
///   (Property 16).
/// - Política de upsert com limite LRU de 1.500 registros (Property 14) e
///   expiração de 24 horas.
/// - Paginação do catálogo (Requirement 1) e buscas (Requirement 3).
/// - Mapeamento de falhas de infraestrutura ([DioException]) para
///   [AppFailure] (lançado), consumível pelos Cubits.
///
/// O relógio [now] é injetável para tornar determinísticos os testes de idade
/// de cache (Property 15); por padrão usa `DateTime.now`.
class ExerciseRepositoryImpl implements ExerciseRepository {
  ExerciseRepositoryImpl({
    required ExerciseDbClient client,
    required CacheStore cache,
    required ConnectivityService connectivity,
    DateTime Function() now = DateTime.now,
  })  : _client = client,
        _cache = cache,
        _connectivity = connectivity,
        _now = now;

  final ExerciseDbClient _client;
  final CacheStore _cache;
  final ConnectivityService _connectivity;
  final DateTime Function() _now;

  /// Limite máximo de exercícios no cache (Requirement 6.1).
  static const int maxCacheEntries = 1500;

  /// Janela de expiração do cache (Requirements 6.2, 6.3).
  static const Duration cacheTtl = Duration(hours: 24);

  /// Tamanho da página do catálogo (Requirement 1.3).
  static const int pageSize = kDefaultPageSize;

  // --- Catálogo (Requirement 1) ---

  @override
  Future<ExercisePage> getCatalogPage({required int page}) async {
    if (page < 0) {
      throw ArgumentError.value(page, 'page', 'deve ser maior ou igual a 0');
    }

    final online = await _connectivity.isOnline();

    if (!online) {
      // Offline: pagina sobre o cache (Requirement 6.4).
      final cached = await _cache.getAllExercises();
      final exercises = cached.map((c) => c.exercise).toList();
      return paginate(exercises, page, pageSize: pageSize);
    }

    // Online: busca a página correspondente da API (offset = page * pageSize).
    final dtos = await _guardNetwork(
      () => _client.fetchExercises(
        offset: page * pageSize,
        limit: pageSize,
      ),
    );
    final exercises = dtos.map((d) => d.toDomain()).toList();

    // Atualiza o cache (upsert + LRU) para cada exercício recebido.
    for (final exercise in exercises) {
      await _upsertWithLru(exercise);
    }

    // A API já retorna no máximo `pageSize` itens; `paginate` garante a forma
    // da página (<= 20 itens) e calcula `hasMore` com base no preenchimento.
    // Se a página veio cheia, assume-se que pode haver uma próxima página.
    final hasMore = exercises.length == pageSize;
    return ExercisePage(items: exercises, page: page, hasMore: hasMore);
  }

  // --- Obtenção de exercício com política de cache (Requirements 2, 6) ---

  @override
  Future<Exercise> getExercise(String id) async {
    final cached = await _cache.getExercise(id);
    final online = await _connectivity.isOnline();

    if (cached != null) {
      if (!online) {
        // Em cache + offline: serve o cache independentemente da idade e
        // atualiza o último acesso (Property 15, Requirement 6.4).
        await _cache.touchExercise(id, _now());
        return cached.exercise;
      }

      // Em cache + online: decide pela idade (expiração de 24h).
      if (!_isExpired(cached)) {
        // Fresco (<= 24h): serve o cache sem chamar a API (Requirement 6.2).
        await _cache.touchExercise(id, _now());
        return cached.exercise;
      }

      // Expirado (> 24h): busca atualizado na API (Requirement 6.3).
      final fresh = await _fetchByIdAndCache(id);
      // Caso a API não retorne o exercício, degrada para o cache existente.
      return fresh ?? cached.exercise;
    }

    // Ausente no cache.
    if (!online) {
      // Offline sem cache: sinaliza indisponibilidade sem modificar o cache
      // (Property 16, Requirement 6.5).
      throw const OfflineUnavailableError(
        'Exercício indisponível: sem conexão e ausente no cache.',
      );
    }

    // Online sem cache: busca na API e armazena (upsert + LRU).
    final fresh = await _fetchByIdAndCache(id);
    if (fresh == null) {
      throw const NetworkError('Exercício não encontrado na ExerciseDB_API.');
    }
    return fresh;
  }

  // --- Buscas (Requirement 3) ---

  @override
  Future<List<Exercise>> searchByName(String term) {
    return _search(
      online: () => _client.fetchByName(term),
      offline: (cached) => filters.searchByName(cached, term),
    );
  }

  @override
  Future<List<Exercise>> searchByBodyPart(String bodyPart) {
    return _search(
      online: () => _client.fetchByBodyPart(bodyPart),
      offline: (cached) => filters.filterByBodyPart(cached, bodyPart),
    );
  }

  @override
  Future<List<Exercise>> searchByEquipment(String equipment) {
    return _search(
      online: () => _client.fetchByEquipment(equipment),
      offline: (cached) => filters.filterByEquipment(cached, equipment),
    );
  }

  /// Orquestra uma busca: quando online, consulta a API, atualiza o cache e
  /// retorna o resultado; quando offline, aplica o filtro [offline] sobre os
  /// exercícios em cache.
  Future<List<Exercise>> _search({
    required Future<List<ExerciseDto>> Function() online,
    required List<Exercise> Function(List<Exercise> cached) offline,
  }) async {
    final isOnline = await _connectivity.isOnline();

    if (!isOnline) {
      final cached = await _cache.getAllExercises();
      return offline(cached.map((c) => c.exercise).toList());
    }

    final dtos = await _guardNetwork(online);
    final exercises = dtos.map((d) => d.toDomain()).toList();
    for (final exercise in exercises) {
      await _upsertWithLru(exercise);
    }
    return exercises;
  }

  // --- Internos ---

  /// Busca um único exercício por id a partir da listagem da API, armazena no
  /// cache (upsert + LRU) e o retorna, ou `null` se não encontrado.
  ///
  /// A ExerciseDB_API não expõe um endpoint direto por id na abstração do
  /// [ExerciseDbClient]; recuperamos via busca por nome/listagem. Para manter
  /// a política de cache coerente, reutilizamos [fetchByName] quando possível
  /// e, caso o id não seja localizado, retornamos `null`.
  Future<Exercise?> _fetchByIdAndCache(String id) async {
    final dtos = await _guardNetwork(() => _client.fetchByName(id));
    final matches = dtos.map((d) => d.toDomain()).where((e) => e.id == id);
    final exercise = matches.isEmpty ? null : matches.first;
    if (exercise != null) {
      await _upsertWithLru(exercise);
    }
    return exercise;
  }

  /// Insere/atualiza [exercise] no cache com `storedAt = now` e aplica o limite
  /// LRU: se após o upsert a contagem exceder [maxCacheEntries], remove os
  /// registros acessados há mais tempo até voltar ao limite (Property 14).
  Future<void> _upsertWithLru(Exercise exercise) async {
    await _cache.upsertExercise(exercise, _now());
    final count = await _cache.countExercises();
    if (count > maxCacheEntries) {
      await _cache.evictLeastRecentlyAccessed(count - maxCacheEntries);
    }
  }

  /// Verifica se o registro em cache ultrapassou a janela de expiração de 24h.
  bool _isExpired(CachedExercise cached) {
    final age = _now().difference(cached.storedAt);
    // `age <= 24h` é fresco; `age > 24h` é expirado.
    return age > cacheTtl;
  }

  /// Executa uma operação de rede mapeando [DioException] para [AppFailure]:
  /// - timeouts → [TimeoutError];
  /// - `DioException.error` já sendo um [AppFailure] → repropaga esse erro;
  /// - demais casos → [NetworkError].
  Future<T> _guardNetwork<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  /// Mapeia uma [DioException] para o [AppFailure] correspondente conforme a
  /// tabela de mapeamento de erros do design.
  AppFailure _mapDioException(DioException e) {
    // Timeouts de conexão/envio/recebimento → TimeoutError (Requirement 1.6).
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return TimeoutError(e.message);
      case DioExceptionType.badCertificate:
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
      default:
        break;
    }

    // Erro de domínio já determinado pelos interceptors (AuthConfigurationError,
    // AuthError, RateLimitError, NetworkError) → repropaga como está
    // (Requirements 7.2, 7.3, 7.4, 7.6).
    final error = e.error;
    if (error is AppFailure) {
      return error;
    }

    // Fallback: falha de comunicação (Requirement 7.6).
    return NetworkError(e.message);
  }
}
