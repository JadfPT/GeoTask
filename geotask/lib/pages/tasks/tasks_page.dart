import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/task_store.dart';
import '../../widgets/task_card.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    if (store.items.isEmpty) {
      return const Center(child: Text('Sem tarefas ainda. Adiciona uma com o botão +'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: store.items.length,
      separatorBuilder: (context, state) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final t = store.items[i];
        return TaskCard(
          task: t,
          onToggle: () => store.toggleDone(t.id),
          onEdit: () => ctx.push('/tasks/edit', extra: t),
          onDelete: () => store.remove(t.id),
        );
      },
    );
  }
}
