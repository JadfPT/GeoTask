import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../data/task_store.dart';
import '../../services/notification_service.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const SettingsPage({super.key, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Alternar tema'),
          subtitle: const Text('Claro / Escuro'),
          onTap: onToggleTheme,
        ),
        const Divider(height: 24),

        // Categorias
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text('Categorias',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in store.categories)
                InputChip(
                  label: Text(c),
                  onDeleted: () =>
                      context.read<TaskStore>().removeCategory(c),
                ),
              ActionChip(
                label: const Text('Adicionar'),
                avatar: const Icon(Icons.add, size: 18),
                onPressed: () => _addCategoryDialog(context),
              ),
            ],
          ),
        ),
        const Divider(height: 24),

        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Permissões de notificações'),
          subtitle: const Text('Conceder/Verificar'),
          onTap: () async {
            final status = await Permission.notification.status;
            if (!status.isGranted) {
              await Permission.notification.request();
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.mark_chat_unread_outlined),
          title: const Text('Testar notificação'),
          onTap: () => NotificationService.instance.show(
            id: 999001,
            title: 'GeoTask',
            body: 'Isto é um teste ✔️',
          ),
        ),
        const Divider(height: 24),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Sobre'),
          subtitle: Text('Gestor de tarefas com geolocalização.'),
        ),
      ],
    );
  }

  Future<void> _addCategoryDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova categoria'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome da categoria'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Adicionar')),
        ],
      ),
    );
    if (ok == true) {
      context.read<TaskStore>().addCategory(ctrl.text);
    }
  }
}
