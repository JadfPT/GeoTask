import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'data/task_store.dart';
import 'data/categories_store.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class GeoTasksApp extends StatefulWidget {
  const GeoTasksApp({super.key});

  @override
  State<GeoTasksApp> createState() => _GeoTasksAppState();
}

class _GeoTasksAppState extends State<GeoTasksApp> {
  late final GoRouter _router = AppRouter.createRouter();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final s = TaskStore();
          // Load persisted tasks in background
          s.loadFromDb();
          return s;
        }),
        ChangeNotifierProvider<CategoriesStore>(
          create: (_) => CategoriesStore()..load(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: Builder(
        builder: (context) {
          final mode = context.watch<ThemeController>().mode;
          return MaterialApp.router(
            debugShowCheckedModeBanner: false, // 3) tira o “DEBUG” do canto
            routerConfig: _router,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
          );
        },
      ),
    );
  }
}
