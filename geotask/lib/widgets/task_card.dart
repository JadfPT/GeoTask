import 'package:flutter/material.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: InkResponse(
          onTap: onToggle,
          child: CircleAvatar(
            backgroundColor:
                task.done ? cs.primaryContainer : cs.surfaceContainerHighest,
            child: Icon(
              task.done
                  ? Icons.check_rounded
                  : Icons.radio_button_unchecked,
              color: task.done ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
        ),
        title: Text(
          task.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.note != null) Text(task.note!),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: -6,
              children: [
                if (task.due != null)
                  _Chip(
                    icon: Icons.schedule,
                    label: _fmt(task.due!),
                  ),
                if (task.point != null)
                  _Chip(
                    icon: Icons.location_on,
                    label: '${task.radiusMeters.round()} m',
                  ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'del') onDelete();
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Editar'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'del',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Apagar'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }

  String _fmt(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurface),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: cs.onSurface)),
        ],
      ),
    );
  }
}
