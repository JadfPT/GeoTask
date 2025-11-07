import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/dashboard_page.dart';
import '../pages/tasks/tasks_page.dart';
import '../pages/tasks/edit_task_page.dart';
import '../pages/tasks/task_view_page.dart';
import '../pages/map/map_page.dart';
import '../pages/map/pick_location_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/categories_page.dart';
import '../models/task.dart';

class AppRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<NavigatorState> shellNavigatorKey =
      GlobalKey<NavigatorState>();

  static GoRouter createRouter() => GoRouter(
        initialLocation: '/dashboard',
        navigatorKey: rootNavigatorKey,
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
