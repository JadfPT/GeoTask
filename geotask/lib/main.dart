import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init(); // canal + permissões (Android 13+)
  runApp(const GeoTasksApp());
}

class GeoTasksApp extends StatelessWidget {
  const GeoTasksApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoTasks',
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomePage(),
    );
  }
}
