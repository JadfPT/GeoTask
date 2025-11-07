import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../data/task_store.dart';
import '../widgets/task_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final tasks = store.items;
    final total = tasks.length;
    final done = tasks.where((t) => t.done).length;
    final pending = total - done;
    final completion = total == 0 ? 0.0 : done / total;

    final upcoming = [...tasks.where((t) => !t.done && t.due != null)];
    upcoming.sort((a, b) => a.due!.compareTo(b.due!));
    final next3 = upcoming.take(3).toList();

    final bottomPad = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      bottom: true,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('GeoTask'),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Olá!', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    _greetingSubtitle(total, pending),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          // Estatísticas
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // altura maior para evitar overflow em ecrãs pequenos
              childAspectRatio: 1.6,
              children: [
                _StatTile(label: 'Tarefas', value: '$total', icon: Icons.list_alt),
                _StatTile(label: 'Concluídas', value: '$done', icon: Icons.task_alt),
                _StatTile(label: 'Pendentes', value: '$pending', icon: Icons.schedule),
                _ProgressTile(value: completion),
              ],
            ),
          ),

          // Ações rápidas
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: _QuickActions(
                onNew: () => context.push('/tasks/edit'),
                onMap: () => context.go('/map'),
                onTasks: () => context.go('/tasks'),
              ),
            ),
          ),

          if (next3.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text('A seguir', style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
          if (next3.isNotEmpty)
            SliverList.separated(
              itemBuilder: (context, i) {
                final t = next3[i];
                return TaskCard(
                  task: t,
                  onToggle: () => store.toggleDone(t.id),
                  onEdit: () => context.push('/tasks/edit', extra: t),
                  onDelete: () => store.remove(t.id),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemCount: next3.length,
            ),

          SliverPadding(padding: EdgeInsets.only(bottom: bottomPad + 24)),
        ],
      ),
    );
  }

  String _greetingSubtitle(int total, int pending) {
    if (total == 0) return 'Começa criando a tua primeira tarefa ✨';
    if (pending == 0) return 'Tudo em dia — boa! ✅';
    return 'Tens $pending pendente(s) — bora lá!';
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, color: cs.onPrimaryContainer, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown, // garante que nunca rebenta a altura
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  final double value;
  const _ProgressTile({required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final percent = (value * 100).round();
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.secondaryContainer,
            child: Icon(Icons.trending_up, color: cs.onSecondaryContainer, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$percent%',
                    maxLines: 1,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text('Progresso', maxLines: 1, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: value, minHeight: 6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onNew;
  final VoidCallback onMap;
  final VoidCallback onTasks;
  const _QuickActions({required this.onNew, required this.onMap, required this.onTasks});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: const Text('Nova tarefa'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onTasks,
            icon: const Icon(Icons.checklist),
            label: const Text('Ver tarefas'),
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          onPressed: onMap,
          icon: const Icon(Icons.map),
          style: IconButton.styleFrom(
            backgroundColor: cs.surfaceContainerHigh,
          ),
          tooltip: 'Abrir mapa',
        ),
      ],
    );
  }
}
