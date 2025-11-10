import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/task_store.dart';
import '../data/categories_store.dart';
import '../models/task.dart';
import 'category_chip.dart';

/*
  Ficheiro: task_card.dart
  Propósito: Cartão reutilizável que apresenta uma tarefa na lista principal.

  Funcionalidade:
  - Mostra título, categorias (chips), data/ícone de localização e acções (editar, alternar concluído).
  - Reconstrói quando `CategoriesStore` muda para reflectir cores actualizadas.
*/

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
  // Use watch so the card rebuilds when categories (and their colors) are loaded/updated
  final cats = context.watch<CategoriesStore>().items;

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
                          CategoryChip(label: cat, color: catColorFor(cat)),
                      if (task.due != null)
                        CategoryChip(
                          icon: Icons.access_time,
                          label:
                              '${task.due!.day.toString().padLeft(2, '0')}/${task.due!.month.toString().padLeft(2, '0')} '
                              '${task.due!.hour.toString().padLeft(2, '0')}:${task.due!.minute.toString().padLeft(2, '0')}',
                        ),
                      // Only show a radius badge when the task has a geo point
                      // associated. Tasks without a location should not display
                      // the default radius value (which defaults to 150).
                      if (task.point != null && task.radiusMeters > 0)
                        CategoryChip(
                          icon: Icons.location_on_outlined,
                          label: '${task.radiusMeters.toStringAsFixed(0)} m',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar',
              onPressed: onEdit ?? () => Navigator.pushNamed(context, '/tasks/edit', arguments: task),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// CategoryChip is provided by lib/widgets/category_chip.dart
