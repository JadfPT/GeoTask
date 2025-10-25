import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

@immutable
class Task {
  final String id;
  final String title;
  final String? note;
  final DateTime? due;
  final bool done;

  /// Categoria opcional (ex.: Pessoal, Trabalho, Estudo)
  final String? category;

  /// localização opcional
  final LatLng? point;
  final double radiusMeters;

  const Task({
    required this.id,
    required this.title,
    this.note,
    this.due,
    this.done = false,
    this.category,
    this.point,
    this.radiusMeters = 150,
  });

  Task copyWith({
    String? title,
    String? note,
    DateTime? due,
    bool? done,
    String? category,
    LatLng? point,
    double? radiusMeters,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        note: note ?? this.note,
        due: due ?? this.due,
        done: done ?? this.done,
        category: category ?? this.category,
        point: point ?? this.point,
        radiusMeters: radiusMeters ?? this.radiusMeters,
      );
}
