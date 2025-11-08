import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_store.dart';
import '../data/categories_store.dart';
import '../data/task_store.dart';
import '../theme/app_theme.dart';
import '../services/notification_controller.dart';

/// AppProviders sets up top-level providers used by the application.
///
/// Responsibilities:
/// - Create the [AuthStore] and load persisted session.
/// - Provide user-scoped [CategoriesStore], [TaskStore] and [ThemeController]
///   as proxy providers that react to authentication changes.
class AppProviders extends StatelessWidget {
  final Widget child;
  const AppProviders({super.key, required this.child});

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
            // Attach the notification controller once the task store is
            // prepared for the authenticated user so time-based and
            // location-based notifications are active for the current user.
            if (auth.isLoaded) {
              NotificationController.instance.attach(store);
            } else {
              NotificationController.instance.detach();
            }
            return store;
          },
        ),

        // ThemeController persists per-user theme choice
        ChangeNotifierProxyProvider<AuthStore, ThemeController>(
          create: (_) => ThemeController(),
          update: (context, auth, theme) {
            theme ??= ThemeController();
            if (auth.isLoaded) theme.loadForUser(auth.currentUser?.id);
            return theme;
          },
        ),
      ],
      child: child,
    );
  }
}
