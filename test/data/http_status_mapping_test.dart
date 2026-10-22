import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_workout_app/data/remote/retry_interceptor.dart';
import 'package:gym_workout_app/domain/app_failure.dart';

/// Adaptador que sempre responde com um status HTTP fixo (sem corpo útil).
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);
  final int statusCode;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString('{}', statusCode, headers: {
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    });
  }
}

/// Monta um Dio com o RetryInterceptor e um adaptador que devolve [status].
/// `validateStatus` deixa o dio tratar como erro para acionar o onError do
/// interceptor (onde ocorre o mapeamento).
({Dio dio, _StatusAdapter adapter}) _dioWithStatus(int status) {
  final adapter = _StatusAdapter(status);
  final dio = Dio(BaseOptions(
    baseUrl: 'https://example.com',
    validateStatus: (code) => code != null && code < 400,
  ))
    ..httpClientAdapter = adapter
    ..interceptors.add(RetryInterceptor(delay: (_) async {}));
  return (dio: dio, adapter: adapter);
}

Future<AppFailure?> _failureFor(int status) async {
  final setup = _dioWithStatus(status);
  try {
    await setup.dio.get<dynamic>('/exercises');
    return null;
  } on DioException catch (e) {
    // O status mapeado NÃO deve ter sido retentado.
    expect(setup.adapter.calls, 1,
        reason: 'respostas HTTP não devem ser retentadas');
    return e.error is AppFailure ? e.error as AppFailure : null;
  }
}

void main() {
  group('Mapeamento de status HTTP (Requirements 7.3, 7.4)', () {
    test('401 → AuthError', () async {
      expect(await _failureFor(401), isA<AuthError>());
    });

    test('403 → AuthError', () async {
      expect(await _failureFor(403), isA<AuthError>());
    });

    test('429 → RateLimitError', () async {
      expect(await _failureFor(429), isA<RateLimitError>());
    });
  });
}
