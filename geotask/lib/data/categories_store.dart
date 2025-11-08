import 'dart:async';
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

  Completer<void>? _loadingCompleter;

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Carrega do disco (SQLite). Na 1ª execução semeia 3 categorias padrão.
  Future<void> load([String? userId]) async {
    // If another load is in progress, wait for it to finish. This prevents
    // concurrent loads seeding defaults multiple times when callers (for
    // example the proxy provider and an explicit load after login) race.
    if (_loadingCompleter != null) {
      await _loadingCompleter!.future;
      // If the previously loaded user matches the requested one and we're
      // already loaded, nothing to do.
      if (_userId == userId && _loaded) return;
    }

    _loadingCompleter = Completer<void>();

    _userId = userId;
    _items.clear();
    if (userId == null) {
      _loaded = true;
      notifyListeners();
      _loadingCompleter?.complete();
      _loadingCompleter = null;
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
      _loadingCompleter?.complete();
      _loadingCompleter = null;
      return;
    }

    _items.addAll(rows);
    _loaded = true;
    notifyListeners();
    _loadingCompleter?.complete();
    _loadingCompleter = null;
  }

  // NOTE: previous implementation included a full rewrite helper `_saveToDb`.
  // We keep per-operation persistence (insert/update/delete/reorder) which
  // avoids wide table rewrites and is simpler to reason about.

  /// Add a new category for the current user and persist it.
  /// Returns immediately if there is no associated user.
  Future<void> add(String name, int color) async {
    final n = name.trim();
    if (n.isEmpty) return;
    if (_userId == null) return;
    final c = model.Category(id: _uuid.v4(), name: n, color: color);
    // persist with the next sortIndex
    await CategoryDao.instance.insert(c, _userId!, sortIndex: _items.length);
    _items.add(c);
    notifyListeners();
  }

  /// Update an existing category and persist the change.
  Future<void> update(String id, {String? name, int? color}) async {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) return;
    final c = _items[i];
    final updated = model.Category(
      id: c.id,
      name: (name?.trim().isEmpty == false) ? name!.trim() : c.name,
      color: color ?? c.color,
    );
    await CategoryDao.instance.update(updated);
    _items[i] = updated;
    notifyListeners();
  }

  /// Remove a category and persist deletion.
  Future<void> remove(String id) async {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) return;
    await CategoryDao.instance.delete(id);
    _items.removeAt(i);
    notifyListeners();
  }

  /// Reorder the local list and persist the new ordering.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _items.length);
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    // persist order
    await CategoryDao.instance.reorder(_items.map((e) => e.id).toList());
    notifyListeners();
  }
}
