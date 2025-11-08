import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
// We'll implement PBKDF2 using HMAC-SHA256 from `crypto` to avoid extra native deps.
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

  // --- Password hashing utilities ---
  Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    final b = Uint8List(length);
    for (var i = 0; i < length; i++) {
      b[i] = rnd.nextInt(256);
    }
    return b;
  }

  // PBKDF2 implementation using HMAC-SHA256 (pure-Dart via `crypto` package)
  Uint8List _pbkdf2(Uint8List password, Uint8List salt, int iterations, int dkLen) {
    final hLen = 32; // SHA256 output bytes
    final l = (dkLen + hLen - 1) ~/ hLen;
    final out = Uint8List(l * hLen);
    final passwordBytes = password;
    for (var i = 1; i <= l; i++) {
      // salt || INT(i)
      final block = <int>[]
        ..addAll(salt)
        ..addAll([(i >> 24) & 0xff, (i >> 16) & 0xff, (i >> 8) & 0xff, i & 0xff]);
      var u = Hmac(sha256, passwordBytes).convert(block).bytes;
      final t = Uint8List.fromList(u);
      for (var j = 1; j < iterations; j++) {
        u = Hmac(sha256, passwordBytes).convert(u).bytes;
        for (var k = 0; k < hLen; k++) {
          t[k] ^= u[k];
        }
      }
      out.setRange((i - 1) * hLen, i * hLen, t);
    }
    return out.sublist(0, dkLen);
  }

  String _hashPasswordPbkdf2(String password, {int iterations = 100000, int saltLen = 16, int dkLen = 32}) {
    final salt = _randomBytes(saltLen);
    final key = _pbkdf2(Uint8List.fromList(utf8.encode(password)), salt, iterations, dkLen);
    final saltB64 = base64.encode(salt);
    final keyB64 = base64.encode(key);
    return 'pbkdf2:$iterations:$saltB64:$keyB64';
  }

  bool _isPbkdf2(String stored) => stored.startsWith('pbkdf2:');

  bool _verifyPassword(String password, String stored) {
    if (_isPbkdf2(stored)) {
      final parts = stored.split(':');
      if (parts.length != 4) return false;
      final iterations = int.tryParse(parts[1]);
      if (iterations == null) return false;
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      final key = _pbkdf2(Uint8List.fromList(utf8.encode(password)), Uint8List.fromList(salt), iterations, expected.length);
      if (key.length != expected.length) return false;
      var diff = 0;
      for (var i = 0; i < key.length; i++) {
        diff |= key[i] ^ expected[i];
      }
      return diff == 0;
    }

    // Legacy: stored is hex SHA-256 string
    final hash = sha256.convert(utf8.encode(password)).toString();
    return hash == stored;
  }

  Future<User> register(String username, String email, String password) async {
    final prevGuestId = isGuest ? _currentUser!.id : null;
    final db = await _db;
    final id = const Uuid().v4();
    final now = DateTime.now();
    final hash = _hashPasswordPbkdf2(password);

    final row = {
      'id': id,
      'email': email,
      'username': username,
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
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) throw Exception('User not found');
    final row = rows.first;
    final stored = row['passwordHash'] as String? ?? '';
    final ok = _verifyPassword(password, stored);
    if (!ok) throw Exception('Invalid credentials');

    // if legacy SHA256, re-hash with PBKDF2 and update DB
    if (!_isPbkdf2(stored)) {
      final newHash = _hashPasswordPbkdf2(password);
      try {
        await db.update('users', {'passwordHash': newHash}, where: 'id = ?', whereArgs: [row['id']]);
      } catch (_) {}
    }

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
    final hash = _hashPasswordPbkdf2(const Uuid().v4());
    final row = {
      'id': id,
      'email': email,
      'username': 'Convidado',
      'passwordHash': hash,
      'createdAt': now.toIso8601String(),
    };
    await db.insert('users', row, conflictAlgorithm: ConflictAlgorithm.replace);
    final user = User.fromRow(row);
    await _setCurrentUser(user);
    return user;
  }

  /// Delete current account after verifying password. Returns true if deleted.
  Future<bool> deleteAccountWithPassword(String password) async {
    final u = _currentUser;
    if (u == null) throw Exception('No user');
    if (isGuest) throw Exception('Guest cannot delete account here');
    final ok = _verifyPassword(password, u.passwordHash);
    if (!ok) return false;

    final db = await _db;
    final uid = u.id;
    // delete tasks
    try {
      await db.delete('tasks', where: 'ownerId = ?', whereArgs: [uid]);
    } catch (_) {}
    // delete categories in DB
    try {
      await db.delete('categories', where: 'ownerId = ?', whereArgs: [uid]);
    } catch (_) {}
    // delete user row
    try {
      await db.delete('users', where: 'id = ?', whereArgs: [uid]);
    } catch (_) {}

  // clear current user
  _currentUser = null;
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_prefKey);
    _loaded = true;
    notifyListeners();
    return true;
  }

  /// Migrate guest data (tasks and categories stored under guestId) to the new userId.
  Future<void> migrateGuestToUser(String guestId, String newUserId) async {
    final db = await _db;
    await db.update('tasks', {'ownerId': newUserId}, where: 'ownerId = ?', whereArgs: [guestId]);
    // migrate categories in DB
    try {
      await db.update('categories', {'ownerId': newUserId}, where: 'ownerId = ?', whereArgs: [guestId]);
    } catch (_) {}
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
    try {
      await db.delete('categories', where: 'ownerId = ?', whereArgs: [guestId]);
    } catch (_) {}
    try {
      await db.delete('users', where: 'id = ?', whereArgs: [guestId]);
    } catch (_) {}
  }
}
