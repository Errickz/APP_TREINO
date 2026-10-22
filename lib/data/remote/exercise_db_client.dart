import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'auth_interceptor.dart';
import 'exercise_dto.dart';
import 'retry_interceptor.dart';

/// Contrato de comunicação HTTP com a ExerciseDB_API (RapidAPI).
///
/// Mapeia as operações de catálogo e busca para os endpoints da API:
///
/// | Operação                | Endpoint                                  |
/// |-------------------------|-------------------------------------------|
/// | Listar exercícios       | `GET /exercises?limit={limit}&offset={offset}` |
/// | Buscar por nome         | `GET /exercises/name/{name}`              |
/// | Buscar por grupo muscular | `GET /exercises/bodyPart/{bodyPart}`    |
/// | Buscar por equipamento  | `GET /exercises/equipment/{type}`         |
///
/// Requirements 1.1, 1.3, 3.1, 3.2, 3.3.
abstract class ExerciseDbClient {
  /// Lista exercícios paginados. `offset`/`limit` mapeados para a paginação da
  /// API (Requirement 1.3, limite padrão de página = 20).
  Future<List<ExerciseDto>> fetchExercises({
    required int offset,
    required int limit,
  });

  /// Busca por nome (parcial) — Requirement 3.1.
  Future<List<ExerciseDto>> fetchByName(String name);

  /// Busca por grupo muscular alvo — Requirement 3.2.
  Future<List<ExerciseDto>> fetchByBodyPart(String bodyPart);

  /// Busca por equipamento — Requirement 3.3.
  Future<List<ExerciseDto>> fetchByEquipment(String equipment);
}

/// Implementação de [ExerciseDbClient] baseada em [Dio].
///
/// A instância de [Dio] é injetável para facilitar testes. Quando não
/// fornecida, uma instância padrão é construída com:
/// - `baseUrl` obtido de [ApiConfig];
/// - timeouts de conexão, recebimento e envio de 10 segundos
///   (Requirements 1.6, 3.1–3.3).
///
/// A injeção dos cabeçalhos de autenticação (`X-RapidAPI-Key`,
/// `X-RapidAPI-Host`) é feita pelo [AuthInterceptor], e a política de retry de
/// rede e o mapeamento de status HTTP para [AppFailure] são feitos pelo
/// [RetryInterceptor]; ambos são registrados na construção padrão do [Dio]
/// (AuthInterceptor primeiro, RetryInterceptor em seguida). O ponto de
/// registro de interceptors permanece disponível através de [dio.interceptors],
/// e cada interceptor pode ser testado de forma independente desta classe.
class DioExerciseDbClient implements ExerciseDbClient {
  DioExerciseDbClient({required ApiConfig config, Dio? dio})
      : _dio = dio ?? _buildDefaultDio(config);

  final Dio _dio;

  /// Timeout aplicado a conexão, recebimento e envio (Requirements 1.6, 3.1–3.3).
  static const Duration timeout = Duration(seconds: 10);

  /// Expõe a instância [Dio] para registro de interceptors
  /// (`AuthInterceptor`, `RetryInterceptor`) pelas tarefas 8.2/8.3.
  Dio get dio => _dio;

  /// Constrói uma instância [Dio] padrão com `baseUrl`, timeouts de 10s e o
  /// [AuthInterceptor] registrado (Requirements 7.1, 7.2).
  static Dio _buildDefaultDio(ApiConfig config) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        responseType: ResponseType.json,
      ),
    );
    // Autenticação (tarefa 8.2): injeta os cabeçalhos da RapidAPI e aborta
    // sem tráfego quando a chave não está configurada.
    dio.interceptors.add(AuthInterceptor(config));
    // Retry e mapeamento de status (tarefa 8.3): registrado após o
    // AuthInterceptor para que o AuthConfigurationError seja propagado sem
    // nova tentativa e os erros de rede/HTTP sejam tratados por último.
    dio.interceptors.add(RetryInterceptor());
    return dio;
  }

  @override
  Future<List<ExerciseDto>> fetchExercises({
    required int offset,
    required int limit,
  }) async {
    final response = await _dio.get<dynamic>(
      '/exercises',
      queryParameters: <String, dynamic>{
        'limit': limit,
        'offset': offset,
      },
    );
    return _parseList(response.data);
  }

  @override
  Future<List<ExerciseDto>> fetchByName(String name) async {
    final response = await _dio.get<dynamic>('/exercises/name/$name');
    return _parseList(response.data);
  }

  @override
  Future<List<ExerciseDto>> fetchByBodyPart(String bodyPart) async {
    final response = await _dio.get<dynamic>('/exercises/bodyPart/$bodyPart');
    return _parseList(response.data);
  }

  @override
  Future<List<ExerciseDto>> fetchByEquipment(String equipment) async {
    final response = await _dio.get<dynamic>('/exercises/equipment/$equipment');
    return _parseList(response.data);
  }

  /// Converte o corpo da resposta (lista de objetos JSON) em [ExerciseDto]s.
  ///
  /// Entradas que não sejam mapas são ignoradas, tornando o parsing resiliente
  /// a variações inesperadas da resposta.
  List<ExerciseDto> _parseList(dynamic data) {
    if (data is! List) return const <ExerciseDto>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(ExerciseDto.fromJson)
        .toList(growable: false);
  }
}
