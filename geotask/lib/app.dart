import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/auth_store.dart';
import 'router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';

/// GeoTasksApp is the root widget for the application. It expects to be
/// wrapped by [AppProviders] which expose the required stores (Auth/Theme).
///
/// Responsibilities:
/// - Create and cache the app [GoRouter] instance.
/// - Listen to auth changes and notify the router to re-evaluate redirects.
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
    // notify go_router to re-evaluate redirects by changing the notifier value
    _routerRefresh.value = _routerRefresh.value + 1;
  }

  @override
  Widget build(BuildContext context) {
    // ThemeController is provided above by AppProviders
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
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
    );
  }
}
