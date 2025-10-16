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
      elevation: 1,
      child: ListTile(
        leading: IconButton(
          icon: Icon(task.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: task.done ? cs.primary : cs.outline),
          onPressed: onToggle,
        ),
        title: Text(task.title, style: task.done ? const TextStyle(decoration: TextDecoration.lineThrough) : null),
        subtitle: task.note != null ? Text(task.note!) : null,
        trailing: PopupMenuButton(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'del') onDelete();
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'))),
            PopupMenuItem(value: 'del',  child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Apagar'))),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}
