import 'dart:convert';

class Category {
  final String id;
  final String name;
  /// Cor ARGB (ex.: 0xFF7C4DFF)
  final int color;

  const Category({
    required this.id,
    required this.name,
    required this.color,
  });

  Category copyWith({String? id, String? name, int? color}) => Category(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'color': color};

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        color: (map['color'] as num).toInt(),
      );

  String toJson() => jsonEncode(toMap());

  factory Category.fromJson(String s) =>
      Category.fromMap(jsonDecode(s) as Map<String, dynamic>);
}
