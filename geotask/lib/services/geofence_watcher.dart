import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../data/task_store.dart';
import 'location_service.dart';
import 'notification_service.dart';

/// GeofenceWatcher continuously watches the device location and triggers
/// local notifications when the user enters any task's radius.
///
/// Key behaviours:
/// - requests permissions via [LocationService.ensurePermissions],
/// - listens to `Geolocator.getPositionStream` with a moderate [distanceFilter]
///   to reduce battery usage,
/// - deduplicates notifications per task per day using an in-memory set.
///
/// Usage:
/// ```dart
/// // Start watching when you have the current TaskStore instance (e.g. after login)
/// await GeofenceWatcher.instance.start(taskStore);
///
/// // Stop watching when the user logs out or you want to pause
/// GeofenceWatcher.instance.stop();
/// ```
class GeofenceWatcher {
  GeofenceWatcher._();
  static final GeofenceWatcher instance = GeofenceWatcher._();

  StreamSubscription<Position>? _sub;
  DateTime _dayKey = DateTime.now();
  final Set<String> _notifiedToday = {};
  // track previous inside/outside state for tasks to detect `enter` events
  final Map<String, bool> _inside = {};

  /// Start listening to location changes and evaluate nearby tasks.
  ///
  /// `store` is the active `TaskStore` whose `items` are inspected. Keep in
  /// mind this class uses an in-memory set to avoid duplicate notifications
  /// across app restarts — if you need persistence across restarts, persist
  /// the `notified` state externally.
  Future<void> start(TaskStore store) async {
    await LocationService.ensurePermissions();
    await _sub?.cancel();

    // Initialize current position without emitting enter notifications.
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (_) {
      // if current position fails, try last known — if both fail we'll still
      // listen to the stream and set states on first update.
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {
        pos = null;
      }
    }

    // Seed _inside map: mark which tasks are currently inside their radius
    if (pos != null) {
      for (final t in store.items) {
        if (t.done || t.point == null || t.radiusMeters <= 0) {
          _inside[t.id] = false;
          continue;
        }
        final d = Geolocator.distanceBetween(
          pos.latitude, pos.longitude,
          t.point!.latitude, t.point!.longitude,
        );
        _inside[t.id] = d <= t.radiusMeters;
      }
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25, // só reage quando te moves ~25m
      ),
    ).listen((p) => _onPosition(p, store));
  }

  /// Clear in-memory geofence state used for deduplication and enter/exit
  /// detection. This does not modify persisted `lastNotifiedAt` values in
  /// the database; use `TaskDao.clearLastNotifiedForOwner` for that.
  ///
  /// If a [store] is provided we will try to seed the `_inside` map using
  /// the last known position so subsequent enter/exit events are accurate.
  Future<void> resetForStore(TaskStore? store) async {
    _notifiedToday.clear();
    _inside.clear();

    if (store == null) return;

    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return;
      for (final t in store.items) {
        if (t.done || t.point == null || t.radiusMeters <= 0) {
          _inside[t.id] = false;
          continue;
        }
        final d = Geolocator.distanceBetween(
          pos.latitude, pos.longitude,
          t.point!.latitude, t.point!.longitude,
        );
        _inside[t.id] = d <= t.radiusMeters;
      }
    } catch (_) {
      // ignore errors; best-effort seeding only
    }
  }

  /// Stop watching location updates.
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

      final currInside = d <= t.radiusMeters;
      final prevInside = _inside[t.id] ?? false;

      // only trigger when transitioning from outside -> inside
      if (!prevInside && currInside) {
        // daily dedupe: don't send more than one per day
        final already = _notifiedToday.contains(t.id);
        if (!already) {
          NotificationService.instance.show(
            id: t.id.hashCode & 0x7fffffff,
            title: 'Estás perto: ${t.title}',
            body: t.note == null ? 'Dentro do raio desta tarefa.' : t.note!,
          );
          _notifiedToday.add(t.id); // uma vez por dia

          // persist last notified timestamp via the store (ignore errors)
          store.markTaskNotified(t.id, DateTime.now()).catchError((_) {});
        }
      }

      // update inside state for the next event
      _inside[t.id] = currInside;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
