import 'package:geolocator/geolocator.dart';

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
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
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
