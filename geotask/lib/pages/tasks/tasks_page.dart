import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../data/task_store.dart';
import '../../data/auth_store.dart';
import '../../widgets/task_card.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/app_snackbar.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<Map<String, dynamic>>? _initialSnapshot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture initial snapshot of tasks to detect unsaved changes
    if (_initialSnapshot == null) {
      final store = context.read<TaskStore>();
      _initialSnapshot = store.items.map((t) => t.toJson()).toList();
    }
  }

  bool _isDirty(TaskStore store) {
    final curr = store.items.map((t) => t.toJson()).toList();
    return jsonEncode(curr) != jsonEncode(_initialSnapshot);
  }

  Future<bool> _confirmLeaveIfDirty() async {
    final store = context.read<TaskStore>();
    if (_initialSnapshot == null) return true;
    if (!_isDirty(store)) return true;

    // Capture ownerId before awaiting to avoid using BuildContext after an async gap
    final ownerId = context.read<AuthStore>().currentUser?.id;

    final choice = await showConfirmDialog(context,
      title: 'Guardar alterações?',
      content: 'Guardar as alterações feitas às tarefas ou reverter para a versão anterior?',
      confirmLabel: 'Guardar',
      cancelLabel: 'Reverter',
    );

    if (choice == true) {
      // Changes are already persisted per-operation; refresh snapshot and allow pop
      _initialSnapshot = store.items.map((t) => t.toJson()).toList();
      return true;
    } else {
      // Revert: reload from DB to discard any in-memory changes
      await store.loadFromDb(ownerId: ownerId);
      return true;
    }
  }
  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final items = store.items;

    // PopScope is the newer API, but it requires Flutter >= 3.12 in the SDK.
    // Keep using WillPopScope for compatibility and locally ignore the
    // deprecation to avoid analyzer warnings until the project SDK is
    // upgraded. Replace with PopScope when the environment supports it.
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: _confirmLeaveIfDirty,
      child: Scaffold(
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
                return Dismissible(
                  key: Key(t.id),
                  direction: DismissDirection.horizontal,
                  background: Container(
                    padding: const EdgeInsets.only(left: 20),
                    alignment: Alignment.centerLeft,
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  secondaryBackground: Container(
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  onDismissed: (dir) => _handleDismissed(t),
                  child: TaskCard(
                    task: t,
                    // as páginas já tratam do push; fica tudo compat
                    onEdit: () => context.push('/tasks/edit', extra: t),
                    onTap: () => context.push('/tasks/view', extra: t),
                    onDelete: null, // deletion via swipe
                  ),
                );
              },
            ),
          ),
    );
  }

  Future<void> _handleDismissed(dynamic t) async {
    final store = context.read<TaskStore>();
    final scaffold = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;
    // remove and offer undo
    await store.remove(t.id);
    scaffold.clearSnackBars();
    scaffold.showSnackBar(SnackBar(
      backgroundColor: cs.surface,
      content: Text('Tarefa eliminada', style: TextStyle(color: cs.onSurface)),
      action: SnackBarAction(label: 'Anular', textColor: cs.primary, onPressed: () async {
        // re-insert task (TaskDao.insert uses replace) to undo
        await store.add(t);
      }),
    ));
  }

Future<void> _clearDone() async {
  final store = context.read<TaskStore>();
  final done = store.items.where((t) => t.done).toList();

  if (done.isEmpty) {
    if (!mounted) return;
    showAppSnackBar(context, 'Não há tarefas concluídas.');
    return;
  }

  // Capture the count before awaiting dialogs
  final count = done.length;
  final ok = await showConfirmDialog(context,
    title: 'Remover concluídas?',
    content: 'Isto vai eliminar $count tarefa(s) concluída(s).',
    confirmLabel: 'Remover',
    cancelLabel: 'Cancelar',
  );

  if (!mounted) return; // segurança se a página tiver sido fechada entretanto
  if (ok == true) {
    for (final t in done) {
      await store.remove(t.id);
    }
    if (!mounted) return;
    showAppSnackBar(context, 'Tarefas concluídas removidas');
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
