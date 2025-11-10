import 'package:flutter/material.dart';
import 'bootstrap/app_providers.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/foreground_service.dart';

/*
  Cabeçalho: main.dart
  Propósito: Ponto de entrada da aplicação.

  O ficheiro inicializa bindings do Flutter, configura serviços que correm
  em background/foreground (ex.: notificações) e monta a árvore de
  providers antes de lançar o widget principal `GeoTasksApp`.

  Nota: comentários no código referem-se às ordens de inicialização que são
  relevantes para permissões e canais de notificação.
*/

/// Entrypoint da aplicação.
///
/// Inicializa bindings, prepara serviços de plataforma (notificações) e monta
/// a árvore de providers em torno do widget principal [GeoTasksApp].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializar primeiro o helper do foreground service (idempotente) e
  // só depois inicializar notificações locais para garantir que os canais
  // e permissões estão prontos antes de qualquer evento que possa disparar
  // uma notificação em runtime.
  await ForegroundService.init();
  await NotificationService.instance.init();
  runApp(const AppProviders(child: GeoTasksApp()));
}
