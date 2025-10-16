import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  final VoidCallback onToggleTheme;
  const SettingsPage({super.key, required this.onToggleTheme});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ListTile(
          leading: const Icon(Icons.dark_mode_outlined),
          title: const Text('Alternar tema (Claro/Escuro)'),
          onTap: onToggleTheme,
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Privacidade & Permissões'),
          subtitle: Text('Localização, notificações…'),
        ),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Sobre'),
          subtitle: Text('Gestor de Tarefas com Geolocalização'),
        ),
      ],
    );
  }
}
