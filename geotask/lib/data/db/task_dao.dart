import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:geotask/data/db/database_helper.dart';
import 'package:geotask/models/task.dart';

class TaskDao {
  TaskDao._private();
  static final TaskDao instance = TaskDao._private();

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<Task>> getAll() async {
    final db = await _db;
    final rows = await db.query('tasks', orderBy: 'rowid DESC');
    return rows.map(_fromRow).toList();
  }

  Future<void> insert(Task t) async {
    final db = await _db;
    final map = _toRow(t);
    await db.insert('tasks', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(Task t) async {
    final db = await _db;
    final map = _toRow(t);
    await db.update('tasks', map, where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Map<String, Object?> _toRow(Task t) {
    return {
      'id': t.id,
      'title': t.title,
      'note': t.note,
      'due': t.due?.toIso8601String(),
      'done': t.done ? 1 : 0,
      'lat': t.point?.latitude,
      'lng': t.point?.longitude,
      'radius': t.radiusMeters,
      'category': t.category,
      'categories': t.categories == null ? null : jsonEncode(t.categories),
    };
  }

  Task _fromRow(Map<String, Object?> row) {
    LatLng? p;
    final lat = row['lat'] as double?;
    final lng = row['lng'] as double?;
    if (lat != null && lng != null) p = LatLng(lat, lng);

    List<String>? cats;
    final cc = row['categories'] as String?;
    if (cc != null) {
      try {
        final decoded = jsonDecode(cc);
        if (decoded is List) cats = decoded.whereType<String>().toList();
      } catch (_) {
        // fall back to CSV
        cats = cc.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    return Task(
      id: row['id'] as String,
      title: row['title'] as String,
      note: row['note'] as String?,
      due: row['due'] != null ? DateTime.tryParse(row['due'] as String) : null,
      done: (row['done'] as int?) == 1,
      point: p,
      radiusMeters: (row['radius'] as num?)?.toDouble() ?? 150,
      category: row['category'] as String?,
      categories: cats,
    );
  }
}
