import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'db/category_dao.dart';

import 'auth/password_utils.dart';
import 'db/user_dao.dart';
import 'db/task_dao.dart';
import '../models/user.dart';

/// AuthStore manages the current authenticated user (or guest), registration,
/// login and account lifecycle. This store uses DAOs for all persistence so it
/// does not execute raw SQL directly.
class AuthStore extends ChangeNotifier {
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool _loaded = false;
  bool get isLoaded => _loaded;
  bool get isGuest => _currentUser != null && _currentUser!.email.startsWith('guest:');

  static const _prefKey = 'geotask_current_user_id';

  // Password hashing/verification moved to `lib/data/auth/password_utils.dart`.
  // Use `hashPasswordPbkdf2()` to create a new PBKDF2 hash and
  // `verifyPassword()` to validate an input password against a stored hash.

  Future<User> register(String username, String email, String password) async {
    final prevGuestId = isGuest ? _currentUser!.id : null;
    final id = const Uuid().v4();
    final now = DateTime.now();
    final hash = hashPasswordPbkdf2(password);

    final user = User(
      id: id,
      email: email,
      username: username,
      passwordHash: hash,
      createdAt: now,
    );

    await UserDao.instance.insertUser(user);
    await _setCurrentUser(user);
    // If previously a guest, migrate guest data to the new user
    if (prevGuestId != null) {
      await migrateGuestToUser(prevGuestId, user.id);
    }
    return user;
  }

  Future<User> login(String email, String password) async {
    final rowUser = await UserDao.instance.getByEmail(email);
    if (rowUser == null) throw Exception('User not found');
    final stored = rowUser.passwordHash;
    final ok = verifyPassword(password, stored);
    if (!ok) throw Exception('Invalid credentials');

    await _setCurrentUser(rowUser);
    return rowUser;
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
    final u = await UserDao.instance.getById(id);
    if (u == null) return;
    _currentUser = u;
    _loaded = true;
    notifyListeners();
  }

  /// Create a persistent guest account. Returns the created guest user.
  Future<User> createGuest() async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final email = 'guest:$id';
    final hash = hashPasswordPbkdf2(const Uuid().v4());
    final user = User(
      id: id,
      email: email,
      username: 'Convidado',
      passwordHash: hash,
      createdAt: now,
    );
    await UserDao.instance.insertUser(user);
    await _setCurrentUser(user);
    return user;
  }

  /// Delete current account after verifying password. Returns true if deleted.
  Future<bool> deleteAccountWithPassword(String password) async {
    final u = _currentUser;
    if (u == null) throw Exception('No user');
    if (isGuest) throw Exception('Guest cannot delete account here');
    final ok = verifyPassword(password, u.passwordHash);
    if (!ok) return false;

    final uid = u.id;
    // delete tasks
    try {
      await TaskDao.instance.deleteForOwner(uid);
    } catch (_) {}
    // delete categories in DB
    try {
      await CategoryDao.instance.deleteForOwner(uid);
    } catch (_) {}
    // delete user row
    try {
      await UserDao.instance.deleteUser(uid);
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
    await TaskDao.instance.updateOwner(guestId, newUserId);
    // migrate categories in DB
    try {
      await CategoryDao.instance.updateOwner(guestId, newUserId);
    } catch (_) {}
    try {
      await UserDao.instance.deleteUser(guestId);
    } catch (_) {}
  }

  /// Delete guest user's tasks, categories and user row.
  Future<void> deleteGuestAndData(String guestId) async {
    try {
      await TaskDao.instance.deleteForOwner(guestId);
    } catch (_) {}
    try {
      await CategoryDao.instance.deleteForOwner(guestId);
    } catch (_) {}
    try {
      await UserDao.instance.deleteUser(guestId);
    } catch (_) {}
  }
}
