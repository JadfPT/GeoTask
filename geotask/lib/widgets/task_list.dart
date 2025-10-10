import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../models/task.dart';

class TaskList extends StatelessWidget {
  final List<Task> tasks;
  final ll.LatLng? current;
  final void Function(int index) onDelete;
  final void Function(ll.LatLng point) onFocus;

  const TaskList({
    super.key,
    required this.tasks,
    required this.current,
    required this.onDelete,
    required this.onFocus,
  });

  @override
  Widget build(BuildContext context) {
    final dist = const ll.Distance();
    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final t = tasks[i];
        final d = (current == null) ? null : dist.as(ll.LengthUnit.Meter, current!, t.point);
        return ListTile(
          title: Text(t.title),
          subtitle: Text(
            'Raio: ${t.radiusMeters.toStringAsFixed(0)} m'
            '${d != null ? ' | Dist.: ${d.toStringAsFixed(0)} m' : ''}'
            '${t.notified ? ' | ⚠️ dentro do raio' : ''}',
          ),
          trailing: IconButton(icon: const Icon(Icons.delete), onPressed: () => onDelete(i)),
          onTap: () => onFocus(t.point),
        );
      },
    );
  }
}
