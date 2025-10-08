import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<void> ensurePermissions() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
  }

  static Future<Position> currentPosition() {
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
  }
}
