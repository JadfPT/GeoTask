import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../data/task_store.dart';
import '../../data/categories_store.dart';
import '../map/map_page.dart';

class TaskViewPage extends StatelessWidget {
  final Task task;
  const TaskViewPage({super.key, required this.task});

  String _formatDue(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final catsStore = context.watch<CategoriesStore>();
    // find freshest copy of the task in the store (so edits reflect here
    // immediately when TaskStore updates)
    final Task current = store.items.firstWhere(
      (e) => e.id == task.id,
      orElse: () => task,
    );

    Color? catColorFor(String name) {
      final m = catsStore.items.where((c) => c.name == name);
      return m.isEmpty ? null : Color(m.first.color);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefa'),
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () => context.push('/tasks/edit', extra: current),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(current.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (current.note == null || current.note!.isEmpty)
              Text('Sem descrição', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 12),
            if (current.note != null && current.note!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(current.note!, style: Theme.of(context).textTheme.bodyLarge),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (current.due != null)
              ListTile(
                leading: const Icon(Icons.access_time_outlined),
                title: const Text('Data e hora'),
                subtitle: Text(_formatDue(current.due!)),
              ),

            if (current.categoriesOrFallback.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in current.categoriesOrFallback)
                      Builder(builder: (ctx) {
                        final col = catColorFor(c) ?? Theme.of(ctx).colorScheme.primary;
                        // choose readable text color on top of the category color
                        final textCol = col.computeLuminance() > 0.5 ? Colors.black : Colors.white;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: col,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0,2)),
                            ],
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.sell_outlined, size: 14, color: textCol.withOpacity(0.9)),
                            const SizedBox(width: 8),
                            Text(c, style: TextStyle(color: textCol, fontWeight: FontWeight.w600)),
                          ]),
                        );
                      }),
                  ],
                ),
              ),

            if (current.radiusMeters > 0 || current.point != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Localização', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (current.point != null)
                        Text('Lat: ${current.point!.latitude.toStringAsFixed(6)}, Lng: ${current.point!.longitude.toStringAsFixed(6)}'),
                      if (current.radiusMeters > 0) ...[
                        const SizedBox(height: 6),
                        Text('Raio: ${current.radiusMeters.toStringAsFixed(0)} m'),
                      ],
                      const SizedBox(height: 12),
                      if (current.point != null)
                        Row(
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                // Request map to centre on this point and open the map
                                MapPage.pendingCenter = current.point;
                                context.go('/map');
                              },
                              icon: const Icon(Icons.map_outlined),
                              label: const Text('Abrir no mapa'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
