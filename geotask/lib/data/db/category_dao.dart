import 'package:sqflite/sqflite.dart';
import '../../models/category.dart' as model;
import 'database_helper.dart';

/*
  Ficheiro: category_dao.dart
  Propósito: DAO para a tabela `categories`.

  Notas:
  - Cada categoria pertence a um `ownerId` (user) e tem um `sortIndex` para
    permitir ordenação personalizada.
  - O DAO expõe métodos para inserir, actualizar, eliminar e reordenar
    categorias; as operações são persistidas imediatamente para manter
    consistência com a UI.
*/

/// DAO para a tabela `categories`.
/// Responsável por CRUD e reordenação.
class CategoryDao {
  CategoryDao._();
  static final instance = CategoryDao._();

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<model.Category>> getAllForOwner(String ownerId) async {
    // Retorna as categorias ordenadas por sortIndex (em ordem crescente).
    final db = await _db;
    final rows = await db.query('categories', where: 'ownerId = ?', whereArgs: [ownerId], orderBy: 'sortIndex ASC');
    return rows.map((r) => model.Category.fromMap(r)).toList(growable: false);
  }

  Future<void> insert(model.Category c, String ownerId, {int? sortIndex}) async {
    // Insere ou substitui a linha de categoria para [ownerId]. Se [sortIndex] for
    // omitido, o chamador poderá chamar `reorder` posteriormente para ajustar a ordem.
    final db = await _db;
    final row = {'id': c.id, 'ownerId': ownerId, 'name': c.name, 'color': c.color, 'sortIndex': sortIndex ?? 0};
    await db.insert('categories', row, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(model.Category c) async {
    // Update category name/color by id. The category's owner is not changed
    // here; use `updateOwner` when moving categories between users.
    final db = await _db;
    await db.update('categories', {'name': c.name, 'color': c.color}, where: 'id = ?', whereArgs: [c.id]);
  }

  Future<void> updateOwner(String oldOwnerId, String newOwnerId) async {
    // Move categories from one owner to another (used during guest->user migration).
    final db = await _db;
    await db.update('categories', {'ownerId': newOwnerId}, where: 'ownerId = ?', whereArgs: [oldOwnerId]);
  }

  Future<void> delete(String id) async {
    // Remove a single category row by id.
    final db = await _db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteForOwner(String ownerId) async {
    // Delete all categories that belong to [ownerId]. Used during account
    // deletion or when wiping guest data.
    final db = await _db;
    await db.delete('categories', where: 'ownerId = ?', whereArgs: [ownerId]);
  }

  Future<void> reorder(List<String> orderedIds) async {
    // Persist new ordering by updating sortIndex for each id in the list.
    final db = await _db;
    final batch = db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update('categories', {'sortIndex': i}, where: 'id = ?', whereArgs: [orderedIds[i]]);
    }
    await batch.commit(noResult: true);
  }
}
