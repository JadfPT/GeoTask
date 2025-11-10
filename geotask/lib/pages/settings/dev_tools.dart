import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/auth_store.dart';
import '../../data/categories_store.dart';
import '../../data/task_store.dart';
import '../../data/db/task_dao.dart';
import '../../data/db/category_dao.dart';
import '../../models/task.dart';
import '../../widgets/app_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_snackbar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// Dev options extracted from settings to keep the SettingsPage file smaller.
class DevOptions extends StatelessWidget {
  final VoidCallback? onHideDev;

  const DevOptions({super.key, this.onHideDev});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('Dev', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),

        // Test notification
        AppCard(
          leading: const Icon(Icons.notifications_active),
          title: const Text('Testar notificação (dev)'),
          subtitle: const Text('Envia uma notificação de teste ao sistema'),
            onTap: () async {
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

        const SizedBox(height: 8),
        // Clear all user data
        AppCard(
          leading: const Icon(Icons.delete_forever),
          title: const Text('Limpar dados da conta'),
          subtitle: const Text('Apaga todas as tarefas e categorias e restaura categorias padrão'),
          onTap: () async {
            final userId = context.read<AuthStore>().currentUser?.id;
            if (userId == null) return;

            final cats = context.read<CategoriesStore>();
            final tasks = context.read<TaskStore>();

            final confirm = await showConfirmDialog(context,
              title: 'Apagar todos os dados?',
              content: 'Isto apagará permanentemente todas as tarefas e categorias desta conta. As categorias padrão serão recriadas. Continuar?',
              confirmLabel: 'Apagar',
              cancelLabel: 'Cancelar',
            );
            if (confirm != true) return;

            try {
              await TaskDao.instance.deleteForOwner(userId);
              await CategoryDao.instance.deleteForOwner(userId);
              await cats.load(userId);
              await tasks.loadFromDb(ownerId: userId);
              if (context.mounted) showAppSnackBar(context, 'Dados apagados e categorias padrão restauradas');
            } catch (e) {
              if (context.mounted) showAppSnackBar(context, 'Erro ao limpar dados: ${e.toString()}');
            }
          },
        ),

        const SizedBox(height: 8),
        // Reset notifications
        AppCard(
          leading: const Icon(Icons.notifications_off),
          title: const Text('Reset notifications'),
          subtitle: const Text('Limpa os registos de notificações para esta conta'),
          onTap: () async {
            final userId = context.read<AuthStore>().currentUser?.id;
            if (userId == null) return;
            final tasks = context.read<TaskStore>();
            final confirm = await showConfirmDialog(context,
              title: 'Reset notifications?',
              content: 'Isto permitirá que todas as tarefas voltem a notificar quando as condições ocorrerem. Continuar?',
              confirmLabel: 'Reset',
              cancelLabel: 'Cancelar',
            );
              if (confirm != true) return;
            try {
              await TaskDao.instance.clearLastNotifiedForOwner(userId);
              await tasks.loadFromDb(ownerId: userId);
              if (context.mounted) showAppSnackBar(context, 'Notificações resetadas');
            } catch (e) {
              if (context.mounted) showAppSnackBar(context, 'Erro ao resetar notificações: ${e.toString()}');
            }
          },
        ),

        const SizedBox(height: 8),
        // Seed demo data
        AppCard(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('Seed demo data'),
          subtitle: const Text('Adiciona tarefas de exemplo para testes'),
          onTap: () async {
            final userId = context.read<AuthStore>().currentUser?.id;
            if (userId == null) return;
            final cats = context.read<CategoriesStore>();
            final tasks = context.read<TaskStore>();
            final confirm = await showConfirmDialog(context,
              title: 'Seed demo data?',
              content: 'Isto adicionará algumas tarefas de exemplo à sua conta. Continuar?',
              confirmLabel: 'Adicionar',
              cancelLabel: 'Cancelar',
            );
              if (confirm != true) return;

            try {
              await cats.load(userId);
              final now = DateTime.now();
              final t1 = Task(id: '${now.millisecondsSinceEpoch}-demo-1', title: 'Demo: Comprar leite', note: 'Ir ao supermercado', due: now.add(const Duration(hours: 3)), category: cats.items.isNotEmpty ? cats.items.first.name : 'Pessoal', ownerId: userId);
              final t2 = Task(id: '${now.millisecondsSinceEpoch}-demo-2', title: 'Demo: Enviar relatório', due: now.add(const Duration(days: 1)), category: cats.items.length > 1 ? cats.items[1].name : 'Trabalho', ownerId: userId);
              final t3 = Task(id: '${now.millisecondsSinceEpoch}-demo-3', title: 'Demo: Visitar local', note: 'Perto do escritório', point: const LatLng(38.7369, -9.1427), radiusMeters: 150, category: cats.items.isNotEmpty ? cats.items.first.name : 'Pessoal', ownerId: userId);
              await tasks.add(t1);
              await tasks.add(t2);
              await tasks.add(t3);
              if (context.mounted) showAppSnackBar(context, 'Dados de exemplo adicionados');
            } catch (e) {
              if (context.mounted) showAppSnackBar(context, 'Erro ao semear dados: ${e.toString()}');
            }
          },
        ),

        const SizedBox(height: 8),
        // Simulate location
        AppCard(
          leading: const Icon(Icons.my_location),
          title: const Text('Simulate location'),
          subtitle: const Text('Simula a posição para testar geofence notifications'),
          onTap: () async {
            final userId = context.read<AuthStore>().currentUser?.id;
            if (userId == null) return;
            final tasks = context.read<TaskStore>();

            final latCtrl = TextEditingController();
            final lngCtrl = TextEditingController();
            final formKey = GlobalKey<FormState>();
            final ok = await showDialog<bool>(context: context, builder: (ctx) {
              return AlertDialog(
                title: const Text('Simulate location'),
                content: Form(
                  key: formKey,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(controller: latCtrl, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.numberWithOptions(decimal: true), validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null),
                    TextFormField(controller: lngCtrl, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.numberWithOptions(decimal: true), validator: (v) => v == null || v.trim().isEmpty ? 'Obrigatório' : null),
                  ]),
                ),
                actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')), FilledButton(onPressed: () {
                  if (formKey.currentState?.validate() ?? false) Navigator.of(ctx).pop(true);
                }, child: const Text('Simular'))],
              );
            });
              if (ok != true) return;

            try {
              final lat = double.tryParse(latCtrl.text.trim());
              final lng = double.tryParse(lngCtrl.text.trim());
              if (lat == null || lng == null) {
                // ignore: use_build_context_synchronously
                showAppSnackBar(context, 'Coordenadas inválidas');
                return;
              }

              int triggered = 0;
              for (final t in tasks.items) {
                if (t.point == null) continue;
                final d = Geolocator.distanceBetween(lat, lng, t.point!.latitude, t.point!.longitude);
                if (d <= t.radiusMeters) {
                  await NotificationService.instance.show(id: t.id.hashCode & 0x7fffffff, title: 'Simulação: ${t.title}', body: t.note ?? 'Dentro do raio da tarefa');
                  await tasks.markTaskNotified(t.id, DateTime.now());
                  triggered++;
                }
              }

              // ignore: use_build_context_synchronously
              showAppSnackBar(context, 'Simulação completa — $triggered tarefas acionadas');
            } catch (e) {
              // ignore: use_build_context_synchronously
              showAppSnackBar(context, 'Erro durante simulação: ${e.toString()}');
            }
          },
        ),

        const SizedBox(height: 8),
        AppCard(
          leading: const Icon(Icons.lock),
          title: const Text('Ocultar opções de desenvolvimento'),
          subtitle: const Text('Reverter o desbloqueio para este utilizador'),
          onTap: () async {
            
            final confirm = await showConfirmDialog(context,
              title: 'Ocultar opções de desenvolvimento',
              content: 'Tem a certeza que pretende ocultar as opções de desenvolvimento para este utilizador?',
              confirmLabel: 'Ocultar',
              cancelLabel: 'Cancelar',
            );
            if (confirm != true) return;
            try {
              if (onHideDev != null) {
                onHideDev!();
                if (context.mounted) showAppSnackBar(context, 'Opções de desenvolvimento ocultadas');
              }
            } catch (_) {
              if (context.mounted) showAppSnackBar(context, 'Erro ao ocultar opções de desenvolvimento');
            }
          },
        ),
      ],
    );
  }
}
