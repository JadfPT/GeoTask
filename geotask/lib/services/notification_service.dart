import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'geotasks_channel',
    'GeoTasks Alerts',
    description: 'Notificações quando te aproximas de uma tarefa',
    importance: Importance.high,
  );

  Future<void> init() async {
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: initAndroid));

    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    await android?.requestPermission(); // Android 13+
  }

  Future<void> showNearby({
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
    );
    await _plugin.show(id, title, body, details);
  }
}
