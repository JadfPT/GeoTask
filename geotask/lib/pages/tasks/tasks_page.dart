import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/task_store.dart';
import '../../widgets/task_card.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final items = store.items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas'),
        actions: [
          if (items.any((t) => t.done))
            IconButton(
              tooltip: 'Apagar concluídas',
              onPressed: _clearDone,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),

      // FAB “Nova tarefa” — voltou
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/tasks/edit'),
        icon: const Icon(Icons.add),
        label: const Text('Nova tarefa'),
      ),

      body: items.isEmpty
          ? _EmptyState(onNew: () => context.push('/tasks/edit'))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final t = items[i];
                return TaskCard(
                  task: t,
                  // as páginas já tratam do push; fica tudo compat
                  onEdit: () => context.push('/tasks/edit', extra: t),
                );
              },
            ),
    );
  }

Future<void> _clearDone() async {
  final store = context.read<TaskStore>();
  final done = store.items.where((t) => t.done).toList();

  if (done.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Não há tarefas concluídas.')),
    );
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remover concluídas?'),
      content: Text('Isto vai eliminar ${done.length} tarefa(s) concluída(s).'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false), // <- usa ctx
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),  // <- usa ctx
          child: const Text('Remover'),
        ),
      ],
    ),
  );

  if (!mounted) return; // segurança se a página tiver sido fechada entretanto
  if (ok == true) {
    for (final t in done) {
      store.remove(t.id);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tarefas concluídas removidas')),
    );
  }
}
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onNew;
  const _EmptyState({required this.onNew});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist, size: 56, color: cs.primary),
          const SizedBox(height: 12),
          Text('Sem tarefas ainda',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Toca no botão “+ Nova tarefa” para criar a primeira.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: const Text('Nova tarefa'),
          )
        ],
      ),
    );
  }
}
