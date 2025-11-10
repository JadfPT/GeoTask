import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_store.dart';
import '../data/categories_store.dart';
import '../data/task_store.dart';
import '../theme/app_theme.dart';
import '../services/notification_controller.dart';

/*
  Ficheiro: app_providers.dart
  Propósito: Configurar os providers de topo da aplicação.

  Descrição:
  - Cria e injeta o `AuthStore` responsável pela sessão e autenticação.
  - Fornece stores dependentes do utilizador (`CategoriesStore`, `TaskStore`)
    e o `ThemeController` como proxy providers, para que reajam a mudanças
    de autenticação (ex.: carregar dados do utilizador atual).

  Nota: o `NotificationController` é ligado ao `TaskStore` quando houver
  um utilizador autenticado, garantindo que notificações por tarefa são
  ativadas apenas para o utilizador correcto.
*/
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
