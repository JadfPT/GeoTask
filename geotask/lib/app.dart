import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/task_store.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class GeoTasksApp extends StatefulWidget {
  const GeoTasksApp({super.key});

  @override
  State<GeoTasksApp> createState() => _GeoTasksAppState();
}

class _GeoTasksAppState extends State<GeoTasksApp> {
  bool _dark = true;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TaskStore()..seedDemo(),
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'GeoTasks',
        routerConfig: buildRouter(
          onToggleTheme: () => setState(() => _dark = !_dark),
        ),
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
      ),
    );
  }
}
