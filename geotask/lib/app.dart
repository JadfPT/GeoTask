import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// router is created dynamically in build; keep imports below used by router creation
// go_router not required directly in this file

import 'data/task_store.dart';
import 'data/categories_store.dart';
import 'data/auth_store.dart';
import 'router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';

class GeoTasksApp extends StatefulWidget {
  const GeoTasksApp({super.key});

  @override
  State<GeoTasksApp> createState() => _GeoTasksAppState();
}

class _GeoTasksAppState extends State<GeoTasksApp> {
  GoRouter? _router;
  final ValueNotifier<int> _routerRefresh = ValueNotifier<int>(0);
  AuthStore? _authRef;

  @override
  void dispose() {
    if (_authRef != null) {
      try {
        _authRef!.removeListener(_onAuthChanged);
      } catch (_) {}
    }
    _routerRefresh.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    // notify go_router to re-evaluate redirects
    _routerRefresh.value = _routerRefresh.value + 1;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Auth first
        ChangeNotifierProvider<AuthStore>(create: (_) {
          final a = AuthStore();
          a.load();
          return a;
        }),
        // Categories are user-scoped and react to Auth changes
        ChangeNotifierProxyProvider<AuthStore, CategoriesStore>(
          create: (_) => CategoriesStore(),
          update: (context, auth, categories) {
            categories ??= CategoriesStore();
            if (auth.isLoaded) categories.load(auth.currentUser?.id);
            return categories;
          },
        ),
        // TaskStore is user-scoped and reacts to Auth changes
        ChangeNotifierProxyProvider<AuthStore, TaskStore>(
          create: (_) => TaskStore(),
          update: (context, auth, store) {
            store ??= TaskStore();
            if (auth.isLoaded) store.loadFromDb(ownerId: auth.currentUser?.id);
            return store;
          },
        ),
        ChangeNotifierProxyProvider<AuthStore, ThemeController>(
          create: (_) => ThemeController(),
          update: (context, auth, theme) {
            theme ??= ThemeController();
            if (auth.isLoaded) theme.loadForUser(auth.currentUser?.id);
            return theme;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final mode = context.watch<ThemeController>().mode;
          // Lazily create the router once and use our internal ValueNotifier
          // as the refreshListenable. Attach a listener to AuthStore so we can
          // notify the router when auth changes without recreating it.
          final auth = Provider.of<AuthStore>(context, listen: false);
          if (_router == null) {
            _router = AppRouter.createRouter(refreshListenable: _routerRefresh);
            _authRef = auth;
            _authRef?.addListener(_onAuthChanged);
          }

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
