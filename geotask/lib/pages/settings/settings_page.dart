import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

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

  Future<void> _checkLocation(BuildContext context) async {
    final status = await Permission.location.status;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Localização: $status')),
      );
    }
  }

  Future<void> _checkNotifications(BuildContext context) async {
    final status = await Permission.notification.status;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notificações: $status')),
      );
    }
  }

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Sobre', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            Text('GeoTask — Gestor de tarefas com geolocalização.'),
            SizedBox(height: 6),
            Text('PDM Freire • Projeto académico.'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final divider = Divider(
      height: 24,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .3),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Tema (placeholder – se já tens o teu ThemeController, substitui)
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Alternar tema'),
            subtitle: const Text('Claro / Escuro'),
            onTap: () => _openAppSettings(context), // aqui podes ligar ao teu theme controller
          ),
          divider,

          // Categorias
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('Categorias'),
            subtitle: const Text('Criar, apagar e ordenar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('editCategories'),
          ),
          divider,

          // Permissões
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 4),
            child: Text('Permissões', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Localização'),
            subtitle: const Text('Necessária para alertas por geolocalização'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await _checkLocation(context);
              await _openAppSettings(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notificações'),
            subtitle: const Text('Necessária para avisos de tarefas'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await _checkNotifications(context);
              await _openAppSettings(context);
            },
          ),
          divider,

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Sobre'),
            onTap: () => _showAbout(context),
          ),
        ],
      ),
    );
  }
}
