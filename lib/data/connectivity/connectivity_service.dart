import 'package:connectivity_plus/connectivity_plus.dart';

/// Serviço de conectividade de rede.
///
/// Abstrai a detecção de conexão usada pela camada de dados para decidir a
/// origem dos dados (cache vs. rede) e para sinalizar indisponibilidade quando
/// o dispositivo está offline.
///
/// Requirement 6.4: quando offline e há exercícios em cache, o App exibe os
/// dados do cache independentemente da idade.
/// Requirement 6.5: quando offline e o exercício não está em cache, o App
/// sinaliza indisponibilidade por falta de conexão.
abstract class ConnectivityService {
  /// Retorna `true` se o dispositivo possui ao menos uma conexão de rede ativa.
  Future<bool> isOnline();

  /// Emite o estado de conectividade (`true` = online, `false` = offline)
  /// sempre que ele muda.
  Stream<bool> onConnectivityChanged();
}

/// Implementação de [ConnectivityService] baseada no pacote `connectivity_plus`.
///
/// No `connectivity_plus` 6.x, tanto `checkConnectivity()` quanto o stream
/// `onConnectivityChanged` retornam uma `List<ConnectivityResult>`. Considera-se
/// o dispositivo "online" quando a lista contém ao menos um resultado diferente
/// de [ConnectivityResult.none].
class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  @override
  Stream<bool> onConnectivityChanged() {
    return _connectivity.onConnectivityChanged.map(_isOnline);
  }

  /// Considera online quando existe ao menos um resultado diferente de
  /// [ConnectivityResult.none].
  static bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
