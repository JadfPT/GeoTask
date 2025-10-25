import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/dashboard_page.dart';
import '../pages/tasks/tasks_page.dart';
import '../pages/map/map_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/tasks/edit_task_page.dart';
import '../pages/map/pick_location_page.dart';
import '../models/task.dart';

GoRouter buildRouter({required VoidCallback onToggleTheme}) {
  return GoRouter(
    initialLocation: '/dashboard',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, navShell) {
          final showFab = navShell.currentIndex == 1 && state.uri.path == '/tasks';
          return Scaffold(
            body: navShell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: navShell.currentIndex,
              onDestinationSelected: (i) => navShell.goBranch(i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checklist_outlined),
                  selectedIcon: Icon(Icons.checklist),
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
            floatingActionButton: showFab
                ? FloatingActionButton.extended(
                    onPressed: () => ctx.push('/tasks/edit'),
                    icon: const Icon(Icons.add),
                    label: const Text('Nova tarefa'),
                  )
                : null,
          );
        },
        branches: [
          // Início
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardPage(),
            ),
          ]),
          // Tarefas
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksPage(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) {
                    final Task? initial =
                        state.extra is Task ? state.extra as Task : null;
                    return EditTaskPage(initial: initial);
                  },
                ),
                GoRoute(
                  path: 'pick-location',
                  builder: (context, state) {
                    final args = state.extra is PickLocationArgs
                        ? state.extra as PickLocationArgs
                        : const PickLocationArgs();
                    return PickLocationPage(args: args);
                  },
                ),
              ],
            ),
          ]),
          // Mapa
          StatefulShellBranch(routes: [
            GoRoute(path: '/map', builder: (c, s) => const MapPage()),
          ]),
          // Definições
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (c, s) => SettingsPage(onToggleTheme: onToggleTheme),
            ),
          ]),
        ],
      ),
    ],
  );
}
