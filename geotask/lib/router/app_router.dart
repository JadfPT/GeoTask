import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/auth_store.dart';

import '../pages/dashboard_page.dart';
import '../pages/tasks/tasks_page.dart';
import '../pages/tasks/edit_task_page.dart';
import '../pages/tasks/task_view_page.dart';
import '../pages/map/map_page.dart';
import '../pages/map/pick_location_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/categories_page.dart';
import '../models/task.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/reset_password_page.dart';
import '../pages/settings/edit_user_page.dart';

/*
  Ficheiro: app_router.dart
  Propósito: Configuração do enrutamento da aplicação usando `go_router`.

  Descrição sucinta:
  - Define as rotas principais (dashboard, tarefas, mapa, definições, login,
    registo, recuperação de password, edição de conta, entre outras).
  - Implementa lógica de redireccionamento baseada no estado de
    autenticação (`AuthStore`) para forçar acesso a páginas protegidas.
  - Usa `ShellRoute` para fornecer um Scaffold com barra de navegação
    nas secções principais da app.

  Observações importantes:
  - O redireccionamento utiliza `AuthStore.isLoaded` e `AuthStore.currentUser`
    para decidir se o utilizador deve ser enviado para `/login` ou para
    `/dashboard`.
  - Rotas modais (ex.: `pick-location`) são declaradas com `parentNavigatorKey`
    para aparecerem acima do layout com tabs.
*/

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static GoRouter createRouter({Listenable? refreshListenable}) => GoRouter(
    refreshListenable: refreshListenable,
    initialLocation: '/login',
        navigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          // Determina redirecionamentos com base no estado de autenticação.
          // Protege rotas e evita que utilizadores autenticados voltem para
          // as páginas de login/registo (excepto em cenários de guest->register).
          try {
            final auth = Provider.of<AuthStore>(context, listen: false);
            final currentUser = auth.currentUser;
            final isLoaded = auth.isLoaded;

            final loggingPaths = {'/login', '/register', '/reset-password'};

            // Se a autenticação terminou e existe um utilizador autenticado:
            // - permitir /register apenas em caso de guest que migra dados
            // - caso contrário, redireccionar para o dashboard se estiver em
            //   páginas de login/register
            if (isLoaded && currentUser != null) {
              final uri = state.uri.toString();
              if (loggingPaths.contains(uri) && !(auth.isGuest && uri == '/register')) {
                return '/dashboard';
              }
              return null;
            }

            // Se a autenticação terminou e não existe utilizador autenticado,
            // enviar para /login quando tentar aceder a rotas protegidas.
            if (isLoaded && currentUser == null) {
              final uri = state.uri.toString();
              if (loggingPaths.contains(uri)) return null;
              return '/login';
            }

            // Enquanto o AuthStore ainda carrega, não forçar redirecionamentos
            // (permite aos providers terminarem a inicialização).
            return null;
          } catch (_) {
            return null;
          }
        },
        routes: [
          ShellRoute(
            navigatorKey: shellNavigatorKey,
            builder: (context, state, child) =>
                _ScaffoldWithNavBar(child: child),
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: DashboardPage()),
              ),
              GoRoute(
                path: '/tasks',
                name: 'tasks',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: TasksPage()),
                routes: [
                  GoRoute(
                    path: 'edit',
                    name: 'editTask',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final Task? initial =
                          state.extra is Task ? state.extra as Task : null;
                      return EditTaskPage(initial: initial);
                    },
                  ),
                  GoRoute(
                    path: 'view',
                    name: 'viewTask',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) {
                      final Task? t = state.extra is Task ? state.extra as Task : null;
                      if (t == null) return const SizedBox.shrink();
                      return TaskViewPage(task: t);
                    },
                  ),
                ],
              ),
              GoRoute(
                path: '/map',
                name: 'map',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: MapPage()),
              ),
              GoRoute(
                path: '/settings',
                name: 'settings',
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: SettingsPage()),
                routes: [
                  GoRoute(
                    path: 'categories',
                    name: 'editCategories',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => const CategoriesPage(),
                  ),
                ],
              ),
            ],
          ),

          // Modal acima das tabs
          GoRoute(
            path: '/pick-location',
            name: 'pickLocation',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              final args = state.extra is PickLocationArgs
                  ? state.extra as PickLocationArgs
                  : null;
              return PickLocationPage(
                initialPoint: args?.initialPoint,
                initialRadius: args?.initialRadius ?? 150,
              );
            },
          ),

          GoRoute(
            path: '/login',
            name: 'login',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => LoginPage(),
          ),
          GoRoute(
            path: '/reset-password',
            name: 'resetPassword',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) {
              // allow pre-filling email and auto-send via query params
              final qp = state.uri.queryParameters;
              final email = qp['email'];
              final autoSend = qp['autoSend'] == '1' || qp['autoSend'] == 'true';
              return ResetPasswordPage(initialEmail: email, autoSend: autoSend);
            },
          ),
          GoRoute(
            path: '/account/edit',
            name: 'editAccount',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => const EditUserPage(),
          ),
          GoRoute(
            path: '/register',
            name: 'register',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => RegisterPage(),
          ),

          // Alias legado
          GoRoute(
            path: '/tasks/edit/pickLocation',
            redirect: (context, state) => '/pick-location',
          ),
        ],
      );
}

class _ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  const _ScaffoldWithNavBar({required this.child});

  int _indexFromLocation(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/tasks')) return 1;
    if (loc.startsWith('/map')) return 2;
    if (loc.startsWith('/settings')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _indexFromLocation(context);

    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/dashboard');
              break;
            case 1:
              context.go('/tasks');
              break;
            case 2:
              context.go('/map');
              break;
            case 3:
              context.go('/settings');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Tarefas',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Definições',
          ),
        ],
      ),
    );
  }
}
