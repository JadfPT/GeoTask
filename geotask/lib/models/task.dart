import 'package:google_maps_flutter/google_maps_flutter.dart';

class Task {
  final String id;
  final String title;
  final String? note;
  final DateTime? due;
  final bool done;

  // Localização
  final LatLng? point;
  final double radiusMeters;

  // Legacy: algumas views antigas ainda usam 1 categoria (string)
  final String? category;

  // Novo: até 3 categorias por tarefa (nomes)
  final List<String>? categories;

  const Task({
    required this.id,
    required this.title,
    this.note,
    this.due,
    this.done = false,
    this.point,
    this.radiusMeters = 150,
    this.category,   // legacy
    this.categories, // novo
  });

  Task copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? due,
    bool? done,
    LatLng? point,
    double? radiusMeters,
    String? category,
    List<String>? categories,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      due: due ?? this.due,
      done: done ?? this.done,
      point: point ?? this.point,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      category: category ?? this.category,
      categories: categories ?? this.categories,
    );
  }

  /// Preferir lista nova; caso vazio, cair no legacy.
  List<String> get categoriesOrFallback {
    if (categories != null && categories!.isNotEmpty) return categories!;
    if (category != null && category!.trim().isNotEmpty) return [category!];
    return const [];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'due': due?.toIso8601String(),
        'done': done,
        'point': point == null
            ? null
            : {'lat': point!.latitude, 'lng': point!.longitude},
        'radiusMeters': radiusMeters,
        'category': category,     // legacy
        'categories': categories, // novo
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    LatLng? p;
    final jp = json['point'];
    if (jp is Map) {
      final lat = (jp['lat'] ?? jp['latitude'])?.toDouble();
      final lng = (jp['lng'] ?? jp['longitude'])?.toDouble();
      if (lat != null && lng != null) p = LatLng(lat, lng);
    }

    List<String>? cats;
    final jc = json['categories'];
    if (jc is List) {
      cats = jc.whereType<String>().toList();
    } else if (jc is String) {
      cats = jc.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      note: json['note'] as String?,
      due: json['due'] != null ? DateTime.tryParse(json['due']) : null,
      done: (json['done'] as bool?) ?? false,
      point: p,
      radiusMeters: (json['radiusMeters'] as num?)?.toDouble() ?? 150,
      category: json['category'] as String?, // legacy
      categories: cats,                       // novo
    );
  }
}
