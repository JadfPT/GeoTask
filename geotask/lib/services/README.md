# Services

This folder contains small platform-related helpers used by the app:

- `notification_service.dart` — wraps `flutter_local_notifications` and handles
  permission requests (Android 13+ and iOS) and channel creation.

- `location_service.dart` — thin wrapper around `geolocator` to centralize
  permission checks and provide a single place to tune `LocationSettings`.

- `geofence_watcher.dart` — subscribes to location updates and triggers local
  notifications when the user enters a task's radius. Uses an in-memory
  deduplication strategy (one notification per task per day).

Quick integration notes
- Initialize notifications early (for example in `main`):

```dart
await NotificationService.instance.init();
```

- Start geofence watching after the user logs in and `TaskStore` is loaded:

```dart
await GeofenceWatcher.instance.start(taskStore);
```

- Stop watching on logout:

```dart
GeofenceWatcher.instance.stop();
```

Platform requirements & testing
- Android:
  - Ensure `AndroidManifest.xml` includes required permissions for background
    location (if you want background geofencing) and for notifications.
  - On Android 13+ the app must request runtime notification permission; this
    is handled in `NotificationService.init()` but verify the manifest
    targets SDK 33+ as appropriate.

- iOS:
  - Add `NSLocationWhenInUseUsageDescription` and/or background location keys
    if you plan to run location updates in background.
  - Request notification permissions and add entitlements for push/local
    notification capabilities.

Testing
- To test geofencing locally, you can simulate location changes in the
  emulator or device (Android Studio: `Extended controls > Location`).
- Send a test notification via `NotificationService.instance.show(...)` to
  verify channels and permissions are configured.

Notes & TODO
- The current geofence deduplication is in-memory (resets on app restart).
  If you require persistence across restarts, persist the `_notifiedToday`
  set in a small local store keyed by date.
- For robust background geofencing, consider platform-specific solutions or
  dedicated geofencing plugins that integrate with OS-level geofencing APIs.
