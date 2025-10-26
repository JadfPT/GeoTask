import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/task_store.dart';
import 'data/categories_store.dart';
import 'router/app_router.dart';

class GeoTasksApp extends StatefulWidget {
  const GeoTasksApp({super.key});

  @override
  State<GeoTasksApp> createState() => _GeoTasksAppState();
}

class _GeoTasksAppState extends State<GeoTasksApp> {
  // cria o GoRouter uma única vez
  late final _router = AppRouter.createRouter();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskStore>(create: (_) => TaskStore()),
        ChangeNotifierProvider<CategoriesStore>(create: (_) => CategoriesStore()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        // usa Material 3; se já tens um AppTheme, podes trocar aqui
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          colorSchemeSeed: const Color(0xFF7C4DFF),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF7C4DFF),
        ),
      ),
    );
  }
}
