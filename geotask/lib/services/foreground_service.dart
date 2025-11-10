import 'package:flutter/foundation.dart';
import 'dart:async';

// Temporary no-op foreground service shim.
//
// The app previously attempted to integrate `flutter_foreground_task` but
// encountered compile-time API mismatches with the plugin version in the
// developer's pub cache. To unblock the build and let you continue testing
// other features, this file currently provides a minimal, safe shim that
// does nothing on Android/iOS. We can replace this with a proper
// implementation after pinning the plugin version or inspecting its API.

/// Lightweight foreground service wrapper using `flutter_foreground_task`.
///
/// This keeps a minimal Android foreground service active while the
/// app needs to receive location updates in background. Start the
/// service when you begin long-running location work and stop it when
/// done.
class ForegroundService {
  ForegroundService._();

  /// Initialize foreground service support (no-op shim).
  static Future<void> init() async {
    if (kDebugMode) debugPrint('ForegroundService.init() - no-op');
    // Intentionally do nothing: real init requires plugin API alignment.
    return Future<void>.value();
  }

  /// Start foreground service (no-op).
  static Future<void> start({String title = 'GeoTask', String content = 'A vigiar localização'}) async {
    if (kDebugMode) debugPrint('ForegroundService.start() - no-op');
    return Future<void>.value();
  }

  /// Stop foreground service (no-op).
  static Future<void> stop() async {
    if (kDebugMode) debugPrint('ForegroundService.stop() - no-op');
    return Future<void>.value();
  }
}
