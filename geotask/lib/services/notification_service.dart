import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Notification helper that wraps `flutter_local_notifications`.
///
/// Responsibilities:
/// - initialize platform channels and request platform permissions (Android
///   notification permission / iOS notification permission),
/// - expose a simple `show(...)` API for sending local notifications.
///
/// Usage:
/// ```dart
/// // initialise early in app start (e.g. main)
/// await NotificationService.instance.init();
///
/// // later
/// NotificationService.instance.show(id: 1, title: 'Olá', body: 'Exemplo');
/// ```
///
/// Platform notes:
/// - Android: ensure `AndroidManifest.xml` contains the notification permission
///   and any required metadata; on Android 13+ a runtime permission is requested
///   via `permission_handler`.
/// - iOS: register for permissions and add necessary entitlements if using
///   advanced features like attachments.
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
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }
}
