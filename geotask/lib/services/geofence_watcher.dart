import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../data/task_store.dart';
import 'location_service.dart';
import 'notification_service.dart';

class GeofenceWatcher {
  GeofenceWatcher._();
  static final GeofenceWatcher instance = GeofenceWatcher._();

  StreamSubscription<Position>? _sub;
  DateTime _dayKey = DateTime.now();
  final Set<String> _notifiedToday = {};

  Future<void> start(TaskStore store) async {
    await LocationService.ensurePermissions();
    await _sub?.cancel();

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25, // só reage quando te moves ~25m
      ),
    ).listen((pos) => _onPosition(pos, store));
  }

  void stop() { _sub?.cancel(); _sub = null; }

  void _onPosition(Position pos, TaskStore store) {
    // reseta o “já notifiquei” diariamente
    final now = DateTime.now();
    if (!_isSameDay(_dayKey, now)) {
      _dayKey = now;
      _notifiedToday.clear();
    }

    for (final t in store.items) {
      if (t.done || t.point == null || t.radiusMeters <= 0) continue;

      final d = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        t.point!.latitude, t.point!.longitude,
      );

      final entered = d <= t.radiusMeters;
      final already = _notifiedToday.contains(t.id);

      if (entered && !already) {
        NotificationService.instance.show(
          id: t.id.hashCode & 0x7fffffff,
          title: 'Estás perto: ${t.title}',
          body: t.note == null ? 'Dentro do raio desta tarefa.' : t.note!,
        );
        _notifiedToday.add(t.id); // uma vez por dia
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
