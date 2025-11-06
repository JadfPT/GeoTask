import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/task_store.dart';
import '../data/categories_store.dart';
import '../models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TaskCard({
    super.key,
    required this.task,
    this.onToggle,
    this.onEdit,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final store = context.read<TaskStore>();
    final cs = Theme.of(context).colorScheme;
    final cats = context.read<CategoriesStore>().items;

    Color? catColorFor(String name) {
      final m = cats.where((c) => c.name == name);
      return m.isEmpty ? null : Color(m.first.color);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle ?? () => store.toggleDone(task.id),
              borderRadius: BorderRadius.circular(32),
              child: Padding(
                padding: const EdgeInsets.only(right: 8.0, top: 4, bottom: 4),
                child: Icon(
                  task.done ? Icons.check_circle : Icons.circle_outlined,
                  color: task.done ? cs.primary : cs.outline,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      decoration:
                          task.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,       // ⇦ mais espaço horizontal
                    runSpacing: 8,    // ⇦ mais espaço vertical (adeus sobreposição)
                    children: [
                      for (final cat in task.categoriesOrFallback)
                        _ColoredChip(
                          icon: Icons.sell_outlined,
                          label: cat,
                          color: catColorFor(cat),
                        ),
                      if (task.due != null)
                        _PlainChip(
                          icon: Icons.access_time,
                          label:
                              '${task.due!.day.toString().padLeft(2, '0')}/${task.due!.month.toString().padLeft(2, '0')} '
                              '${task.due!.hour.toString().padLeft(2, '0')}:${task.due!.minute.toString().padLeft(2, '0')}',
                        ),
                      if (task.radiusMeters > 0)
                        _PlainChip(
                          icon: Icons.location_on_outlined,
                          label: '${task.radiusMeters.toStringAsFixed(0)} m',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (String v) {
                switch (v) {
                  case 'edit':
                    if (onEdit != null) {
                      onEdit!();
                    } else {
                      Navigator.pushNamed(context, '/edit_task', arguments: task);
                    }
                    break;
                  case 'delete':
                    if (onDelete != null) {
                      onDelete!();
                    } else {
                      store.remove(task.id);
                    }
                    break;
                }
              },
              itemBuilder: (c) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar')),
                PopupMenuItem(value: 'delete', child: Text('Eliminar')),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _PlainChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlainChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final Color bg = cs.surfaceContainerHighest;
    final Color fg = cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // ⇦ +altura
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg)),
      ]),
    );
  }
}

class _ColoredChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _ColoredChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    if (color == null) return _PlainChip(icon: icon, label: label);
    final fg = Theme.of(context).colorScheme.onSurface;
    final bg = color!.withValues(alpha: .18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), // ⇦ +altura
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: fg)),
      ]),
    );
  }
}
