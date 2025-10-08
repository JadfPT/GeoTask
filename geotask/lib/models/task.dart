import 'package:latlong2/latlong.dart';

class Task {
  final String id;
  final String title;
  final LatLng point;
  final double radiusMeters;
  bool notified;

  Task({
    required this.id,
    required this.title,
    required this.point,
    required this.radiusMeters,
    this.notified = false,
  });

  Task copyWith({
    String? id,
    String? title,
    LatLng? point,
    double? radiusMeters,
    bool? notified,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      point: point ?? this.point,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      notified: notified ?? this.notified,
    );
  }
}
