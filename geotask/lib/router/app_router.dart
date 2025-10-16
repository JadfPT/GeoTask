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
        builder: (ctx, state, navShell) => Scaffold(
          body: navShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navShell.currentIndex,
            onDestinationSelected: navShell.goBranch,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Início'),
              NavigationDestination(icon: Icon(Icons.checklist_outlined), label: 'Tarefas'),
              NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Mapa'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Definições'),
            ],
          ),
          floatingActionButton: navShell.currentIndex == 1
              ? FloatingActionButton.extended(
                  onPressed: () => ctx.push('/tasks/edit'),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova tarefa'),
                )
              : null,
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (context, state) => const DashboardPage()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksPage(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (ctx, st) => EditTaskPage(initial: st.extra as Task?),
                ),
              ],
            ),
          ]),



          StatefulShellBranch(routes: [
            GoRoute(path: '/map', builder: (context, state) => const MapPage(), routes: [
            GoRoute(
              path: 'pick',
              builder: (context, state) {
                  final args = state.extra as PickLocationArgs? ??
                      const PickLocationArgs();
                  return PickLocationPage(args: args);
                },
              ),
            ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/settings', builder: (context, state) => SettingsPage(onToggleTheme: onToggleTheme)),
          ]),
        ],
      ),
    ],
  );
}
