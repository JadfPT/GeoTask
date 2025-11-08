import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'db/database_helper.dart';
import '../models/user.dart';

class AuthStore extends ChangeNotifier {
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool _loaded = false;
  bool get isLoaded => _loaded;
  bool get isGuest => _currentUser != null && _currentUser!.email.startsWith('guest:');

  static const _prefKey = 'geotask_current_user_id';

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<User> register(String email, String password) async {
    final prevGuestId = isGuest ? _currentUser!.id : null;
    final db = await _db;
    final id = const Uuid().v4();
    final now = DateTime.now();
    final hash = _hashPassword(password);

    final row = {
      'id': id,
      'email': email,
      'passwordHash': hash,
      'createdAt': now.toIso8601String(),
    };

    await db.insert('users', row, conflictAlgorithm: ConflictAlgorithm.abort);

    final user = User.fromRow(row);
    await _setCurrentUser(user);
    // If previously a guest, migrate guest data to the new user
    if (prevGuestId != null) {
      await migrateGuestToUser(prevGuestId, user.id);
    }
    return user;
  }

  Future<User> login(String email, String password) async {
    final db = await _db;
    final hash = _hashPassword(password);
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) throw Exception('User not found');
    final row = rows.first;
    if ((row['passwordHash'] as String) != hash) throw Exception('Invalid credentials');
    final user = User.fromRow(row);
    await _setCurrentUser(user);
    return user;
  }

  Future<void> logout() async {
    final wasGuest = isGuest;
    final guestId = _currentUser?.id;
    if (wasGuest && guestId != null) {
      await deleteGuestAndData(guestId);
      _currentUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      _loaded = true;
      notifyListeners();
      return;
    }

    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _setCurrentUser(User u) async {
    _currentUser = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, u.id);
    _loaded = true;
    notifyListeners();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_prefKey);
    if (id == null) return;
    final db = await _db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;
    _currentUser = User.fromRow(rows.first);
    _loaded = true;
    notifyListeners();
  }

  /// Create a persistent guest account. Returns the created guest user.
  Future<User> createGuest() async {
    final db = await _db;
    final id = const Uuid().v4();
    final now = DateTime.now();
    final email = 'guest:$id';
    final hash = _hashPassword(const Uuid().v4());
    final row = {
      'id': id,
      'email': email,
      'passwordHash': hash,
      'createdAt': now.toIso8601String(),
    };
    await db.insert('users', row, conflictAlgorithm: ConflictAlgorithm.replace);
    final user = User.fromRow(row);
    await _setCurrentUser(user);
    return user;
  }

  /// Migrate guest data (tasks and categories stored under guestId) to the new userId.
  Future<void> migrateGuestToUser(String guestId, String newUserId) async {
    final db = await _db;
    await db.update('tasks', {'ownerId': newUserId}, where: 'ownerId = ?', whereArgs: [guestId]);

    final prefs = await SharedPreferences.getInstance();
    final guestKey = 'categories.v1.$guestId';
    final newKey = 'categories.v1.$newUserId';
    final list = prefs.getStringList(guestKey);
    if (list != null) {
      await prefs.setStringList(newKey, list);
      await prefs.remove(guestKey);
    }

    try {
      await db.delete('users', where: 'id = ?', whereArgs: [guestId]);
    } catch (_) {}
  }

  /// Delete guest user's tasks, categories and user row.
  Future<void> deleteGuestAndData(String guestId) async {
    final db = await _db;
    try {
      await db.delete('tasks', where: 'ownerId = ?', whereArgs: [guestId]);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    final guestKey = 'categories.v1.$guestId';
    await prefs.remove(guestKey);
    try {
      await db.delete('users', where: 'id = ?', whereArgs: [guestId]);
    } catch (_) {}
  }
}
