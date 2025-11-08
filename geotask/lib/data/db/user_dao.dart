import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../../models/user.dart';

/// Data Access Object for `users` table.
///
/// Encapsulates all user-related database operations so higher-level stores
/// (e.g. `AuthStore`) don't need to execute raw SQL.
class UserDao {
  UserDao._();
  static final instance = UserDao._();

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<void> insertUser(User u) async {
    final db = await _db;
    await db.insert('users', u.toRow(), conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<User?> getByEmail(String email) async {
    final db = await _db;
    final rows = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (rows.isEmpty) return null;
    return User.fromRow(rows.first);
  }

  Future<User?> getById(String id) async {
    final db = await _db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return User.fromRow(rows.first);
  }

  Future<void> updatePasswordHash(String id, String newHash) async {
    final db = await _db;
    await db.update('users', {'passwordHash': newHash}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteUser(String id) async {
    final db = await _db;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
