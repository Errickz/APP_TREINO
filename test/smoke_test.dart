import 'package:flutter_test/flutter_test.dart';
import 'package:gym_workout_app/data/config/api_config.dart';

void main() {
  group('ApiConfig', () {
    test('lê valores padrão do ambiente quando RAPIDAPI_KEY não é definido', () {
      final config = ApiConfig.fromEnvironment();

      // Sem --dart-define=RAPIDAPI_KEY, a chave fica vazia e isConfigured é false.
      expect(config.rapidApiKey, isEmpty);
      expect(config.isConfigured, isFalse);

      // O host tem um valor padrão e a baseUrl é derivada dele.
      expect(config.rapidApiHost, 'exercisedb.p.rapidapi.com');
      expect(config.baseUrl, 'https://exercisedb.p.rapidapi.com');
    });

    test('isConfigured é true quando a chave não é vazia', () {
      const config = ApiConfig(
        rapidApiKey: 'abc123',
        rapidApiHost: 'exercisedb.p.rapidapi.com',
        baseUrl: 'https://exercisedb.p.rapidapi.com',
      );

      expect(config.isConfigured, isTrue);
    });

    test('isConfigured é false quando a chave é apenas espaços', () {
      const config = ApiConfig(
        rapidApiKey: '   ',
        rapidApiHost: 'exercisedb.p.rapidapi.com',
        baseUrl: 'https://exercisedb.p.rapidapi.com',
      );

      expect(config.isConfigured, isFalse);
    });
  });
}
