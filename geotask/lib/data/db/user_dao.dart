import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';
import '../../models/user.dart';

/*
  Ficheiro: user_dao.dart
  Propósito: DAO para a tabela `users`.

  Descrição:
  - Encapsula operações CRUD sobre utilizadores para que stores (ex.:
    `AuthStore`) não executem SQL directo.
  - Opera sobre representações simples (Map) produzidas por `User.toRow()` e
    consumidas por `User.fromRow()`.
*/

/// DAO para a tabela `users`.
/// Fornece operações assíncronas para inserir, procurar, actualizar e
/// eliminar utilizadores.
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

  Future<void> updateUsername(String id, String username) async {
    final db = await _db;
    await db.update('users', {'username': username}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteUser(String id) async {
    final db = await _db;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
