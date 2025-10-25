import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/task_store.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

class GeoTasksApp extends StatefulWidget {
  const GeoTasksApp({super.key});
  @override
  State<GeoTasksApp> createState() => _GeoTasksAppState();
}

class _GeoTasksAppState extends State<GeoTasksApp> {
  bool _dark = true;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaskStore()..seed(),
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'GeoTask',
            routerConfig: buildRouter(onToggleTheme: () {
              setState(() => _dark = !_dark);
            }),
            themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
          );
        },
      ),
    );
  }
}
