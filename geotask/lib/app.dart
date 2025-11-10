import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/auth_store.dart';
import 'router/app_router.dart';
import 'package:go_router/go_router.dart';
import 'theme/app_theme.dart';

/*
  Cabeçalho: app.dart
  Propósito: Widget raiz da aplicação.

  Resumo:
  - Define o widget principal `GeoTasksApp` que usa `MaterialApp.router` e
    configura o enrutamento (GoRouter) e o tema.
  - O widget é concebido para ser envolvido por `AppProviders`, que expõem
    stores como `AuthStore` e `ThemeController`.

  Observações:
  - O `GoRouter` é criado preguiçosamente e mantido em cache; é forçado a
    reavaliar redirects através de um `ValueNotifier` quando o estado de
    autenticação muda.
*/

/// `GeoTasksApp` é o widget raiz da aplicação. Deve ser envolvido por
/// `AppProviders` que expõem os stores necessários (ex.: Auth/Theme).
///
/// Responsabilidades principais:
/// - Criar e manter o `GoRouter` da aplicação.
/// - Ouvir mudanças de autenticação e notificar o router para reavaliar
///   redireccionamentos sem recriar o router.
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
    // Notificar o go_router para reavaliar redireccionamentos alterando o
    // valor do notifier (força o refresh sem recriar o router).
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
