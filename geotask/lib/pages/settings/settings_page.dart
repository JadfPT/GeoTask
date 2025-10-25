import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/notification_service.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const SettingsPage({super.key, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Alternar tema Claro/Escuro'),
          onTap: onToggleTheme,
        ),
        const Divider(height: 24),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Permissões', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        ListTile(
          leading: const Icon(Icons.location_on_outlined),
          title: const Text('Localização'),
          subtitle: const Text('Necessária para alertas por geolocalização'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openAppSettings(),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_active_outlined),
          title: const Text('Notificações'),
          subtitle: const Text('Necessária para avisos de tarefas'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openAppSettings(),
        ),
        const Divider(height: 24),
        ListTile(
          leading: const Icon(Icons.mark_chat_unread_outlined),
          title: const Text('Testar notificação'),
          onTap: () => NotificationService.instance.show(
            id: 999001,
            title: 'GeoTasks',
            body: 'Isto é um teste ✔️',
          ),
        ),
        const Divider(height: 24),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Sobre'),
          subtitle: Text('Gestor de tarefas com geolocalização'),
        ),
      ],
    );
  }
}
