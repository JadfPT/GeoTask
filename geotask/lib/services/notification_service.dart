import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/*
  Ficheiro: notification_service.dart
  Propósito: Wrapper em torno de `flutter_local_notifications` para gerir
  notificações locais de forma centralizada.

  Descrição:
  - Inicializa canais/plataformas e pede permissões onde aplicável.
  - Exponibiliza `show(...)` para enviar notificações locais simples.

  Observações:
  - No Android 13+ é necessário pedir a permissão de notificações em runtime
    (aqui feito com `permission_handler`).
  - O `channel` e icon devem ser correctamente configurados para que as
    notificações apareçam conforme esperado.
*/

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'geotasks_channel',
    'GeoTasks Alerts',
    description: 'Notificações quando te aproximas de uma tarefa',
    importance: Importance.high,
  );

  /// Initialize platform-specific settings and request permissions when
  /// necessary. Call this early (e.g. from `main`). Calling multiple times
  /// is safe — initialization is idempotent.
  Future<void> init() async {
    // Android: ensure channel exists
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // iOS: request permissions
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else {
      // Android 13+: runtime permission
      await Permission.notification.request();
    }
    // Initialize plugin with default platform settings so callbacks work and
    // Android uses a small icon. Use the app launcher icon as default.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: androidInit, iOS: iosInit));
  }

  /// Show a simple local notification.
  ///
  /// `id` is used to identify the notification; use a stable number if you
  /// expect to update/remove the notification later. Keep `title` and
  /// `body` short for better display on notification centers.
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'geotasks_channel',
        'GeoTasks Alerts',
        priority: Priority.high,
        importance: Importance.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }
}
