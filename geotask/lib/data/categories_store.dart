import 'package:flutter/foundation.dart' hide Category; // evita conflito com foundation
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart' as model;
import 'db/category_dao.dart';

class CategoriesStore extends ChangeNotifier {
  final _uuid = const Uuid();
  String? _userId;

  final List<model.Category> _items = <model.Category>[];
  List<model.Category> get items => List.unmodifiable(_items);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Carrega do disco (SQLite). Na 1ª execução semeia 3 categorias padrão.
  Future<void> load([String? userId]) async {
    _userId = userId;
    _items.clear();
    if (userId == null) {
      _loaded = true;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    // Migrate legacy SharedPreferences categories if present
    final legacyKey = 'categories.v1.$userId';
    final legacy = prefs.getStringList(legacyKey);
    if (legacy != null) {
      // migrate into DB and remove legacy
      final migrated = legacy.map((s) => model.Category.fromJson(s)).toList(growable: false);
      for (var i = 0; i < migrated.length; i++) {
        await CategoryDao.instance.insert(migrated[i], userId, sortIndex: i);
      }
      await prefs.remove(legacyKey);
    }

    final rows = await CategoryDao.instance.getAllForOwner(userId);
    if (rows.isEmpty) {
      // seed defaults
      final defaults = [
        model.Category(id: _uuid.v4(), name: 'Pessoal', color: 0xFF7C4DFF),
        model.Category(id: _uuid.v4(), name: 'Trabalho', color: 0xFF26A69A),
        model.Category(id: _uuid.v4(), name: 'Estudo', color: 0xFF536DFE),
      ];
      for (var i = 0; i < defaults.length; i++) {
        await CategoryDao.instance.insert(defaults[i], userId, sortIndex: i);
      }
      _items.addAll(defaults);
      _loaded = true;
      notifyListeners();
      return;
    }

    _items.addAll(rows);
    _loaded = true;
    notifyListeners();
  }

  Future<void> _saveToDb() async {
    if (_userId == null) return;
    // delete existing and insert current list to preserve order
    await CategoryDao.instance.deleteForOwner(_userId!);
    for (var i = 0; i < _items.length; i++) {
      await CategoryDao.instance.insert(_items[i], _userId!, sortIndex: i);
    }
  }

  void add(String name, int color) {
    final n = name.trim();
    if (n.isEmpty) return;
    final c = model.Category(id: _uuid.v4(), name: n, color: color);
    _items.add(c);
    _saveToDb();
    notifyListeners();
  }

  void update(String id, {String? name, int? color}) {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) return;
    final c = _items[i];
    final updated = model.Category(
      id: c.id,
      name: (name?.trim().isEmpty == false) ? name!.trim() : c.name,
      color: color ?? c.color,
    );
    _items[i] = updated;
    CategoryDao.instance.update(updated);
    notifyListeners();
  }

  void remove(String id) {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) return;
    _items.removeAt(i);
    CategoryDao.instance.delete(id);
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _items.length);
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    // persist order
    CategoryDao.instance.reorder(_items.map((e) => e.id).toList());
    notifyListeners();
  }
}
