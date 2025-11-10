import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:geotask/data/db/database_helper.dart';
import 'package:geotask/models/task.dart';

/// Data Access Object for `tasks` table.
///
/// Provides basic CRUD operations and mapping between the `Task` model and
/// the database row representation. All methods are async and return when
/// the underlying database operation completes.
class TaskDao {
  TaskDao._private();
  static final TaskDao instance = TaskDao._private();

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  /// Return all tasks across users, ordered by insertion (newest first).
  Future<List<Task>> getAll() async {
    final db = await _db;
    final rows = await db.query('tasks', orderBy: 'rowid DESC');
    return rows.map(_fromRow).toList();
  }
  /// Get tasks for a specific owner (user). If [ownerId] is `null` all tasks
  /// are returned.
  Future<List<Task>> getAllForOwner(String? ownerId) async {
    final db = await _db;
    if (ownerId == null) {
      final rows = await db.query('tasks', orderBy: 'rowid DESC');
      return rows.map(_fromRow).toList();
    } else {
      final rows = await db.query('tasks',
          where: 'ownerId = ?', whereArgs: [ownerId], orderBy: 'rowid DESC');
      return rows.map(_fromRow).toList();
    }
  }
  /// Insert or replace a task into the database.
  Future<void> insert(Task t) async {
    final db = await _db;
    final map = _toRow(t);
    await db.insert('tasks', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  /// Update an existing task row (matched by id).
  Future<void> update(Task t) async {
    final db = await _db;
    final map = _toRow(t);
    await db.update('tasks', map, where: 'id = ?', whereArgs: [t.id]);
  }
  /// Delete a task by [id].
  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all tasks that belong to [ownerId]. Used when removing a user
  /// and for guest migration/cleanup.
  Future<void> deleteForOwner(String ownerId) async {
    final db = await _db;
    await db.delete('tasks', where: 'ownerId = ?', whereArgs: [ownerId]);
  }

  /// Clear the lastNotifiedAt timestamp for all tasks belonging to [ownerId].
  /// This is useful for resetting notification state during testing/dev.
  Future<void> clearLastNotifiedForOwner(String ownerId) async {
    final db = await _db;
    await db.update('tasks', {'lastNotifiedAt': null}, where: 'ownerId = ?', whereArgs: [ownerId]);
  }

  /// Move tasks from [oldOwnerId] to [newOwnerId]. Used when migrating guest
  /// data into a newly registered user account.
  Future<void> updateOwner(String oldOwnerId, String newOwnerId) async {
    final db = await _db;
    await db.update('tasks', {'ownerId': newOwnerId}, where: 'ownerId = ?', whereArgs: [oldOwnerId]);
  }

  Map<String, Object?> _toRow(Task t) {
    // Convert a Task instance into a row map suitable for SQLite storage.
    // Fields with null values are stored as NULL in the database.
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
      'ownerId': t.ownerId,
      'lastNotifiedAt': t.lastNotifiedAt?.millisecondsSinceEpoch,
    };
  }

  /// Convert a database row into a [Task] model.
  /// Handles legacy encodings for `categories` (JSON array or CSV string).
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
      ownerId: row['ownerId'] as String?,
      lastNotifiedAt: row['lastNotifiedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['lastNotifiedAt'] as int)
          : null,
    );
  }
}
