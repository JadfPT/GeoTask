import 'package:flutter/material.dart';
import 'bootstrap/app_providers.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/foreground_service.dart';

/// Entrypoint da aplicação.
///
/// Inicializa bindings, prepara serviços de plataforma (notificações) e monta
/// a árvore de providers em torno do widget principal [GeoTasksApp].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize foreground service helper first (idempotent) then
  // initialize local notifications so channels/permissions are ready
  // before any runtime code may trigger notifications.
  await ForegroundService.init();
  await NotificationService.instance.init();
  runApp(const AppProviders(child: GeoTasksApp()));
}
