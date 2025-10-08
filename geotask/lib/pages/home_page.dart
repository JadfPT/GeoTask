import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/task.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../widgets/map_view.dart';
import '../widgets/task_list.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _map = MapController();
  final Distance _distance = const Distance();
  final List<Task> _tasks = [];

  LatLng? _current;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await LocationService.ensurePermissions();
    await _locate();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final p = await LocationService.currentPosition();
      setState(() => _current = LatLng(p.latitude, p.longitude));
    } catch (_) {}
  }

  Future<void> _tick() async {
    if (_tasks.isEmpty) return;
    try {
      final p = await LocationService.currentPosition();
      _current = LatLng(p.latitude, p.longitude);
    } catch (_) {}

    for (final t in _tasks) {
      if (_current == null) break;
      final d = _distance.as(LengthUnit.Meter, _current!, t.point);
      if (d <= t.radiusMeters && !t.notified) {
        t.notified = true;
        await NotificationService.instance.showNearby(
          id: t.hashCode,
          title: 'Estás perto de "${t.title}"',
          body: 'A ${d.toStringAsFixed(0)} m do teu destino.',
        );
      }
      if (d > t.radiusMeters * 1.5) {
        t.notified = false;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _addTaskAt(LatLng point) async {
    final titleCtrl = TextEditingController();
    final radiusCtrl = TextEditingController(text: '100');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nova tarefa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
            TextField(
              controller: radiusCtrl,
              decoration: const InputDecoration(labelText: 'Raio (m)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true) return;
    final title = titleCtrl.text.trim().isEmpty ? 'Tarefa' : titleCtrl.text.trim();
    final radius = double.tryParse(radiusCtrl.text.trim()) ?? 100;

    setState(() {
      _tasks.add(Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        point: point,
        radiusMeters: radius.clamp(10, 5000),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = _current ?? const LatLng(39.3999, -8.2245);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestor de Tarefas com Geolocalização'),
        actions: [
          IconButton(onPressed: _locate, icon: const Icon(Icons.my_location)),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MapView(
              controller: _map,
              center: center,
              current: _current,
              tasks: _tasks,
              onLongPressAdd: _addTaskAt,
            ),
          ),
          Expanded(
            flex: 2,
            child: TaskList(
              tasks: _tasks,
              current: _current,
              onDelete: (i) => setState(() => _tasks.removeAt(i)),
              onFocus: (p) => _map.move(p, 17),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTaskAt(center),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Nova tarefa'),
      ),
    );
  }
}
