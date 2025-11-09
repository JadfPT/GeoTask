import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import '../../data/auth_store.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_card.dart';


import 'about_sheet.dart';
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
              return CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.16),
                child: initials.isEmpty ? const Icon(Icons.person_outline, color: Colors.white) : Text(initials, style: const TextStyle(color: Colors.white)),
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
          if (_devUnlocked) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('Dev', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            AppCard(
              leading: const Icon(Icons.notifications_active),
              title: const Text('Testar notificação (dev)'),
              subtitle: const Text('Envia uma notificação de teste ao sistema'),
              onTap: () async {
                // Ensure runtime permission is requested on Android 13+
                final status = await Permission.notification.status;
                if (!status.isGranted) {
                  final r = await Permission.notification.request();
                  if (!r.isGranted) {
                    if (context.mounted) showAppSnackBar(context, 'Permissão de notificações não concedida');
                    return;
                  }
                }

                try {
                  await NotificationService.instance.show(id: 999999, title: 'Teste GeoTask', body: 'Isto é uma notificação de teste');
                  if (context.mounted) showAppSnackBar(context, 'Notificação enviada (verifica a área de sistema)');
                } catch (e) {
                  if (context.mounted) showAppSnackBar(context, 'Erro ao enviar notificação: ${e.toString()}');
                }
              },
            ),

            // Allow the user to hide dev options again for the current user
            const SizedBox(height: 8),
            AppCard(
              leading: const Icon(Icons.lock),
              title: const Text('Ocultar opções de desenvolvimento'),
              subtitle: const Text('Reverter o desbloqueio para este utilizador'),
              onTap: () async {
                // capture messenger synchronously to avoid using BuildContext after await
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _setDevUnlocked(false);
                  if (!mounted) return;
                  setState(() {
                    _devUnlocked = false;
                  });
                  messenger.showSnackBar(const SnackBar(content: Text('Opções de desenvolvimento ocultadas')));
                } catch (_) {
                  if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Erro ao ocultar opções de desenvolvimento')));
                }
              },
            ),
          ],
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
                    CircleAvatar(radius: 28, backgroundColor: Theme.of(ctx).colorScheme.primary.withOpacity(0.16), child: const Icon(Icons.person_outline, color: Colors.white)),
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
                      // logout
                      final router = GoRouter.of(rootContext);
                      await auth.logout();
                      router.go('/login');
                    }, child: const Text('Sair'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                      onPressed: () async {
                      final router = GoRouter.of(rootContext);
                      final messenger = ScaffoldMessenger.of(rootContext);
                      // ignore: use_build_context_synchronously
                      final confirm = await showConfirmDialog(rootContext, title: 'Apagar conta?', content: 'Isto apagará permanentemente a sua conta e todos os dados associados. Continuar?', confirmLabel: 'Apagar', cancelLabel: 'Cancelar');
                      if (confirm == true) {
                        // ignore: use_build_context_synchronously
                        final password = await showPasswordPrompt(rootContext, title: 'Confirme com a sua password', label: 'Password', confirmLabel: 'Apagar');
                        if (password != null) {
                          final ok = await auth.deleteAccountWithPassword(password);
                          if (ok) {
                            router.go('/login');
                          } else {
                            messenger.showSnackBar(const SnackBar(content: Text('Password incorreta')));
                          }
                        }
                      }
                      },
                      child: const Text('Apagar conta'),
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
