import 'dart:async';

import '../data/task_store.dart';
import 'notification_service.dart';
import 'geofence_watcher.dart';
import 'foreground_service.dart';

/// NotificationController orchestrates time-based and location-based
/// notifications for the currently attached [TaskStore].
///
/// It does not replace the low-level [NotificationService] (which sends
/// notifications) nor the geofence watcher (which provides raw location
/// events). Instead it wires both together: it starts/stops the
/// geofence watcher and periodically scans tasks for due times and triggers
/// notifications when appropriate.
class NotificationController {
  NotificationController._();
  static final NotificationController instance = NotificationController._();

  TaskStore? _store;
  Timer? _timer;

  /// Attach to a TaskStore. This starts a periodic timer and the geofence
  /// watcher. Re-attaching with the same store is a no-op.
  void attach(TaskStore store) {
    if (identical(_store, store)) return;
    detach();
    _store = store;
    _store!.addListener(_onTasksChanged);
    // start geofence watcher which will trigger notifications on enter
    GeofenceWatcher.instance.start(store);
    // start a foreground service so the app is more likely to keep receiving
    // location updates while backgrounded. This is a lightweight persistent
    // notification that keeps the process alive on most Android devices.
    ForegroundService.start(title: 'GeoTask', content: 'A vigiar localização');
    // periodic check for due tasks every 30 seconds
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkDue());
    // run initial check immediately
    _checkDue();
  }

  /// Detach from the current store and stop timers/watchers.
  void detach() {
    _timer?.cancel();
    _timer = null;
    if (_store != null) {
      try {
        _store!.removeListener(_onTasksChanged);
      } catch (_) {}
      _store = null;
    }
    // stop geofence watcher
    GeofenceWatcher.instance.stop();
  // stop foreground service if running
  ForegroundService.stop();
    // persisted per-task notification timestamps are used; nothing to
    // clear here.
  }

  void _onTasksChanged() {
    // If tasks were added/removed/updated, re-evaluate immediate due items
    _checkDue();
    // Also clear notifications for tasks that are no longer present/done
    if (_store == null) return;
    // No in-memory dedupe set: the per-task `lastNotifiedAt` persisted value
    // in the database will be used to avoid re-sending notifications.
  }

  Future<void> _checkDue() async {
    final s = _store;
    if (s == null) return;
    final now = DateTime.now();
    for (final t in s.items) {
      if (t.done) continue;
      final id = t.id;
      if (t.due == null) continue;
      // skip if we've already recorded a notification after (or at) the
      // due time. We persist lastNotifiedAt per task so that app restarts
      // don't re-send the same overdue notification repeatedly.
      if (t.lastNotifiedAt != null) {
        // if lastNotifiedAt is at/after the due time, assume we've already
        // sent the due notification
        if (!t.lastNotifiedAt!.isBefore(t.due!)) continue;
      }

      // notify if due time passed
      if (!t.due!.isAfter(now)) {
        final nid = _notifIdForTask(id);
        try {
          await NotificationService.instance.show(
            id: nid,
            title: 'Tarefa: ${t.title}',
            body: t.note ?? 'Hora de executar a tarefa',
          );
          // persist that we've notified at now
          await s.markTaskNotified(id, DateTime.now());
        } catch (_) {}
      }
    }
  }

  int _notifIdForTask(String taskId) => taskId.hashCode & 0x7fffffff;
}
