import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Thin wrapper around `geolocator` used by the app.
///
/// Purpose:
/// - centralize permission handling and common location calls,
/// - provide a single place to tune `LocationSettings` for the app.
class LocationService {
  /// Ensure the app has location permissions. If denied, this will prompt
  /// the user. Note: callers should handle permanently denied states and
  /// guide the user to the OS settings if necessary.
  static Future<void> ensurePermissions() async {
    // Request fine/coarse permission using geolocator flow first
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    // On Android, also request background location permission where appropriate
    // so that the app can continue to receive location updates while in background.
    // This improves the chance the Geolocator stream will deliver updates
    // when the app is backgrounded. Note: some OEMs still restrict background
    // activity; a foreground service may be required for full reliability.
    if (Platform.isAndroid) {
      try {
        final status = await Permission.locationAlways.status;
        if (!status.isGranted) {
          await Permission.locationAlways.request();
        }
      } catch (_) {}
    }
  }

  /// Get the device's current position using app-preferred [LocationSettings].
  ///
  /// This delegates to `Geolocator.getCurrentPosition`. If you need a
  /// stream of updates use `Geolocator.getPositionStream` directly.
  static Future<Position> currentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, // substitui desiredAccuracy
      ),
    );
  }
}
