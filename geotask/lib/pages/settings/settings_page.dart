import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../data/auth_store.dart';


import 'about_sheet.dart';
import '../../theme/app_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _openAppSettings(BuildContext context) async {
    final ok = await openAppSettings();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir as definições.')),
      );
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
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
        title: Text(context.watch<AuthStore>().currentUser?.username ?? context.watch<AuthStore>().currentUser?.email ?? 'Sem sessão'),
        subtitle: context.watch<AuthStore>().currentUser == null
          ? const Text('Inicia sessão ou cria uma conta')
          : Text(context.watch<AuthStore>().currentUser?.email ?? ''),
              trailing: Builder(builder: (ctx) {
                final auth = ctx.watch<AuthStore>();
                final user = auth.currentUser;
                if (user == null) {
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(onPressed: () => ctx.push('/login'), child: const Text('Entrar')),
                    TextButton(onPressed: () => ctx.push('/register'), child: const Text('Registar')),
                  ]);
                }

                if (auth.isGuest) {
                  return Row(mainAxisSize: MainAxisSize.min, children: [
                    TextButton(onPressed: () => ctx.push('/register'), child: const Text('Criar conta')),
                    TextButton(
                      onPressed: () async {
                        final router = GoRouter.of(ctx);
                        final authStore = ctx.read<AuthStore>();
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dctx) => AlertDialog(
                            title: const Text('Apagar dados de convidado?'),
                            content: const Text('Ao sair como convidado, todas as tarefas e categorias desta sessão serão apagadas. Continuar?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancelar')),
                              ElevatedButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Apagar')),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await authStore.logout();
                          router.go('/login');
                        }
                      },
                      child: const Text('Sair'),
                    ),
                  ]);
                }

                // Regular signed-in user: show menu with email, logout, delete
                return PopupMenuButton<String>(
                  onSelected: (v) async {
                    final router = GoRouter.of(ctx);
                    if (v == 'logout') {
                      await ctx.read<AuthStore>().logout();
                      router.go('/login');
                    } else if (v == 'email') {
                      final email = ctx.read<AuthStore>().currentUser?.email ?? '';
                      showDialog<void>(context: ctx, builder: (dctx) => AlertDialog(title: const Text('Email associado'), content: Text(email), actions: [TextButton(onPressed: () => Navigator.of(dctx).pop(), child: const Text('OK'))]));
                    } else if (v == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: const Text('Apagar conta?'),
                          content: const Text('Isto apagará permanentemente a sua conta e todos os dados associados. Continuar?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancelar')),
                            ElevatedButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Apagar')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        // ask for password
                        final password = await showDialog<String?>(
                          context: ctx,
                          builder: (dctx) {
                            final ctrl = TextEditingController();
                            return AlertDialog(
                              title: const Text('Confirme com a sua password'),
                              content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(dctx).pop(null), child: const Text('Cancelar')),
                                ElevatedButton(onPressed: () => Navigator.of(dctx).pop(ctrl.text), child: const Text('Apagar')),
                              ],
                            );
                          },
                        );
                        if (password != null) {
                          final ok = await ctx.read<AuthStore>().deleteAccountWithPassword(password);
                          if (ok) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Conta apagada')));
                            }
                            router.go('/login');
                          } else {
                            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Password incorreta')));
                          }
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'email', child: Text('Ver email')), 
                    PopupMenuItem(value: 'logout', child: Text('Sair')),
                    PopupMenuItem(value: 'delete', child: Text('Apagar conta')),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Alternar tema'),
              subtitle: const Text('Claro / Escuro'),
              trailing: Switch(
                value: isDark,
                onChanged: (_) => themeCtl.toggle(context),
              ),
              onTap: () => themeCtl.toggle(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Categorias'),
              subtitle: const Text('Criar, apagar e ordenar'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/settings/categories'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Permissões',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Localização'),
              subtitle:
                  const Text('Necessária para alertas por geolocalização'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openAppSettings(context),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('Notificações'),
              subtitle: const Text('Necessária para avisos de tarefas'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openAppSettings(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Sobre'),
              onTap: () => showAboutGeoTasks(context),
            ),
          ),
        ],
      ),
    );
  }
}
