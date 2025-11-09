import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

void showAboutGeoTasks(BuildContext context, {VoidCallback? onTitleTap}) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title is tappable to support a hidden developer easter-egg.
              GestureDetector(
                onTap: onTitleTap,
                child: Text('GeoTasks', style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: 6),
              Text(
                'Gestor de tarefas com geolocalização. '
                'Cria lembretes com raio e recebe alertas quando te aproximas.',
              ),
              const SizedBox(height: 16),
              _AboutRow(icon: Icons.map_outlined, text: 'Mapa com marcadores das tarefas e raio configurável'),
              _AboutRow(icon: Icons.place_outlined, text: 'Escolha de localização com controlo de precisão'),
              _AboutRow(icon: Icons.notifications_active_outlined, text: 'Notificações locais (Android e iOS)'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check),
                    label: const Text('OK'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchUrlString('mailto:feedback@geotasks.app'),
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Contactar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _AboutRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
