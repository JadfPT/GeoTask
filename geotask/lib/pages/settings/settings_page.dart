import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
// notification_service is used by dev tools; keep import in dev_tools.dart instead
import '../../data/auth_store.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_card.dart';


import 'about_sheet.dart';
import 'dev_tools.dart';
import '../../theme/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _devUnlocked = false;
  int _aboutTaps = 0;
  String? _loadedForUserId;

  Future<void> _openAppSettings(BuildContext context) async {
    final ok = await openAppSettings();
    if (!ok && context.mounted) {
      showAppSnackBar(context, 'Não foi possível abrir as definições.');
    }
  }
  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadDevUnlockedFor(String userId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final key = 'dev_unlocked.$userId';
      final v = sp.getBool(key) ?? false;
      if (!mounted) return;
      setState(() {
        _devUnlocked = v;
        _loadedForUserId = userId;
      });
    } catch (_) {}
  }

  Future<String?> _loadAvatarPathForUser(String userId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final key = 'avatar_$userId';
      final path = sp.getString(key);
      if (path == null) return null;
      final f = File(path);
      if (await f.exists()) return path;
    } catch (_) {}
    return null;
  }

  Future<void> _setDevUnlocked(bool v) async {
    try {
      // capture userId synchronously before awaiting
      final userId = context.read<AuthStore>().currentUser?.id ?? 'anon';
      final sp = await SharedPreferences.getInstance();
      final key = 'dev_unlocked.$userId';
      await sp.setBool(key, v);
    } catch (_) {}
  }

  void _onAboutTitleTap() {
    setState(() {
      _aboutTaps++;
      final userId = context.read<AuthStore>().currentUser?.id ?? 'anon';
      // ensure we're tracking for the current user
      if (_loadedForUserId != userId) {
        _loadedForUserId = userId;
        _devUnlocked = false;
      }
      if (_aboutTaps >= 5) {
        _devUnlocked = true;
        _setDevUnlocked(true);
        _aboutTaps = 0;
        if (mounted) showAppSnackBar(context, 'Opções de desenvolvimento desbloqueadas');
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // reload dev unlock state when the current user changes
    final userId = context.read<AuthStore>().currentUser?.id ?? 'anon';
    if (_loadedForUserId != userId) {
      // reset visible state until we load the specific user's flag
      _devUnlocked = false;
      _loadDevUnlockedFor(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeCtl = context.watch<ThemeController>();
    final isDark = themeCtl.isDarkEffective(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // Account section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Conta', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          // Account card: tap to open a full account sheet with clear actions
          AppCard(
            leading: Builder(builder: (ctx) {
              final auth = ctx.watch<AuthStore>();
              final user = auth.currentUser;
              String initials = '';
              if (user != null) {
                final name = user.username ?? user.email;
                final parts = name.split(RegExp(r'\s+'));
                initials = parts.map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').take(2).join();
              }

              if (user == null) {
                return CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((0.16 * 255).round()),
                  child: initials.isEmpty ? const Icon(Icons.person_outline, color: Colors.white) : Text(initials, style: const TextStyle(color: Colors.white)),
                );
              }

              return FutureBuilder<String?>(
                future: _loadAvatarPathForUser(user.id),
                builder: (fbCtx, snap) {
                  final path = snap.data;
                  if (snap.connectionState == ConnectionState.done && path != null) {
                    return CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((0.16 * 255).round()),
                      backgroundImage: FileImage(File(path)),
                    );
                  }
                  // fallback to initials while loading or if no avatar
                  return CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withAlpha((0.16 * 255).round()),
                    child: initials.isEmpty ? const Icon(Icons.person_outline, color: Colors.white) : Text(initials, style: const TextStyle(color: Colors.white)),
                  );
                },
              );
            }),
            title: Builder(builder: (ctx) {
              final auth = ctx.watch<AuthStore>();
              final user = auth.currentUser;
              if (user == null) return const Text('Sem sessão');
              if (auth.isGuest) return const Text('Convidado');
              return Text(user.username ?? user.email);
            }),
            subtitle: Builder(builder: (ctx) {
              final auth = ctx.watch<AuthStore>();
              final user = auth.currentUser;
              if (user == null) return const Text('Inicia sessão ou cria uma conta');
              if (auth.isGuest) return Text(user.id);
              return Text(user.email);
            }),
            onTap: () => _showAccountSheet(context),
          ),
          // Appearance & categories
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Aparência', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          AppCard(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Alternar tema'),
            subtitle: const Text('Claro / Escuro'),
            trailing: Switch(
              value: isDark,
              onChanged: (_) => themeCtl.toggle(context),
            ),
            onTap: () => themeCtl.toggle(context),
          ),
          const SizedBox(height: 12),

          // Management section
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Gestão', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          AppCard(
            leading: const Icon(Icons.label_outline),
            title: const Text('Categorias'),
            subtitle: const Text('Criar, apagar e ordenar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/categories'),
          ),

          // Permissions section
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Permissões', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          AppCard(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Localização'),
            subtitle: const Text('Necessária para alertas por geolocalização'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openAppSettings(context),
          ),
          AppCard(
            leading: const Icon(Icons.notifications_none),
            title: const Text('Notificações'),
            subtitle: const Text('Necessária para avisos de tarefas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openAppSettings(context),
          ),
          // Dev section: visible only when unlocked for the current user
          if (_devUnlocked)
            DevOptions(onHideDev: () {
              // Persist hidden state and update UI; we don't await here because
              // DevOptions expects a synchronous callback. _setDevUnlocked is
              // asynchronous but will complete shortly.
              _setDevUnlocked(false);
              if (!mounted) return;
              setState(() {
                _devUnlocked = false;
              });
            }),
          // Help / About
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Ajuda', style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          AppCard(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre'),
            onTap: () => showAboutGeoTasks(context, onTitleTap: _onAboutTitleTap),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountSheet(BuildContext rootContext) async {
    final auth = rootContext.read<AuthStore>();
    final user = auth.currentUser;

    await showModalBottomSheet(
      context: rootContext,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // show persisted avatar if available, otherwise fallback to initials/icon
                    Builder(builder: (avCtx) {
                      if (user == null) {
                        return CircleAvatar(radius: 28, backgroundColor: Theme.of(avCtx).colorScheme.primary.withAlpha((0.16 * 255).round()), child: const Icon(Icons.person_outline, color: Colors.white));
                      }

                      return FutureBuilder<String?>(
                        future: _loadAvatarPathForUser(user.id),
                        builder: (fbCtx, snap) {
                          final path = snap.data;
                          if (snap.connectionState == ConnectionState.done && path != null) {
                            return CircleAvatar(
                              radius: 28,
                              backgroundColor: Theme.of(avCtx).colorScheme.primary.withAlpha((0.16 * 255).round()),
                              backgroundImage: FileImage(File(path)),
                            );
                          }

                          // fallback to initials while loading or if no avatar
                          String initials = '';
                          final name = user.username ?? user.email;
                          final parts = name.split(RegExp(r'\s+'));
                          initials = parts.map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').take(2).join();

                          return CircleAvatar(
                            radius: 28,
                            backgroundColor: Theme.of(avCtx).colorScheme.primary.withAlpha((0.16 * 255).round()),
                            child: initials.isEmpty ? const Icon(Icons.person_outline, color: Colors.white) : Text(initials, style: const TextStyle(color: Colors.white)),
                          );
                        },
                      );
                    }),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(user == null ? 'Sem sessão' : (auth.isGuest ? 'Convidado' : (user.username ?? user.email)), style: Theme.of(ctx).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(user == null ? 'Inicia sessão ou cria uma conta' : (auth.isGuest ? (user.id) : user.email), style: Theme.of(ctx).textTheme.bodyMedium),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (user == null) ...[
                  Row(children: [
                    Expanded(child: FilledButton(onPressed: () { Navigator.of(ctx).pop(); rootContext.push('/login'); }, child: const Text('Entrar'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () { Navigator.of(ctx).pop(); rootContext.push('/register'); }, child: const Text('Registar'))),
                  ])
                ] else if (auth.isGuest) ...[
                  Row(children: [
                    Expanded(child: FilledButton(onPressed: () { Navigator.of(ctx).pop(); rootContext.push('/register'); }, child: const Text('Criar conta'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () async {
                      final router = GoRouter.of(rootContext);
                      final confirm = await showConfirmDialog(ctx, title: 'Apagar dados de convidado?', content: 'Ao sair como convidado, todas as tarefas e categorias desta sessão serão apagadas. Continuar?', confirmLabel: 'Apagar', cancelLabel: 'Cancelar');
                      if (confirm == true) {
                        await auth.logout();
                        router.go('/login');
                      }
                    }, child: const Text('Sair'))),
                  ])
                ] else ...[
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () async {
                      // logout (rename shown to user as 'Terminar sessão')
                      final router = GoRouter.of(rootContext);
                      await auth.logout();
                      router.go('/login');
                    }, child: const Text('Terminar sessão'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton(
                      onPressed: () {
                        // open edit account page where the user can change username, password or delete account
                        Navigator.of(ctx).pop();
                        rootContext.push('/account/edit');
                      },
                      child: const Text('Editar conta'),
                    )),
                  ])
                ],

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
