import 'package:flutter/foundation.dart';
import 'dart:async';

/*
  Ficheiro: foreground_service.dart
  Propósito: Interface para gerir um serviço em foreground.

  Nota importante:
  - Actualmente este ficheiro é um shim no-op que não executa um serviço
    real. Foi usado para contornar incompatibilidades com a versão do
    plugin `flutter_foreground_task` no ambiente de desenvolvimento.
  - Para produção, substituir por uma implementação real após alinhar a
    versão do plugin e testar no Android (serviço em foreground requer
    configuração no Manifest e permissão adequada).
*/

/// Wrapper leve para um serviço em foreground (actualmente no-op).
class ForegroundService {
  ForegroundService._();

  /// Inicializa suporte ao foreground service (shim que não faz nada).
  static Future<void> init() async {
    if (kDebugMode) debugPrint('ForegroundService.init() - no-op');
    return Future<void>.value();
  }

  /// Inicia o serviço em foreground (no-op).
  static Future<void> start({String title = 'GeoTask', String content = 'A vigiar localização'}) async {
    if (kDebugMode) debugPrint('ForegroundService.start() - no-op');
    return Future<void>.value();
  }

  /// Para o serviço em foreground (no-op).
  static Future<void> stop() async {
    if (kDebugMode) debugPrint('ForegroundService.stop() - no-op');
    return Future<void>.value();
  }
}
