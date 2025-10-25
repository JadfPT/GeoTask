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
    final doneCount = items.where((t) => t.done).length;

    return SafeArea( // evita sobreposição com a status bar
      top: true,
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: items.isEmpty
            ? _EmptyState(onNew: () => context.push('/tasks/edit'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho
                  Row(
                    children: [
                      Text(
                        'Tarefas',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('${items.length}',
                            style: Theme.of(context).textTheme.labelMedium),
                      ),
                      const Spacer(),
                      if (doneCount > 0)
                        TextButton.icon(
                          onPressed: () => _confirmAndClearCompleted(context),
                          icon: const Icon(Icons.delete_sweep_outlined),
                          label: Text('Limpar concluídas ($doneCount)'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Lista
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final t = items[i];
                        return TaskCard(
                          task: t,
                          onToggle: () => store.toggleDone(t.id),
                          onEdit: () => ctx.push('/tasks/edit', extra: t),
                          onDelete: () => store.remove(t.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmAndClearCompleted(BuildContext context) async {
    final store = context.read<TaskStore>();
    final doneIds = store.items.where((t) => t.done).map((t) => t.id).toList();
    if (doneIds.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar concluídas?'),
        content: Text(
            'Isto vai remover ${doneIds.length} tarefa(s) concluída(s). Queres continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Apagar')),
        ],
      ),
    );

    if (ok == true) {
      for (final id in doneIds) {
        store.remove(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarefas concluídas removidas')),
        );
      }
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
