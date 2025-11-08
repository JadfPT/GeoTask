import 'dart:convert';
import 'package:flutter/foundation.dart' hide Category; // evita conflito com foundation
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart' as model;

class CategoriesStore extends ChangeNotifier {
  static const String _prefsKey = 'categories.v1';
  final _uuid = const Uuid();
  String? _userId;

  final List<model.Category> _items = <model.Category>[];
  List<model.Category> get items => List.unmodifiable(_items);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  /// Carrega do disco. Na 1ª execução semeia 3 categorias padrão.
  Future<void> load([String? userId]) async {
    _userId = userId;
    // Do not use a global categories set when there is no signed-in user.
    if (userId == null) {
      // clear categories for anonymous (no global data)
      _items.clear();
      _loaded = true;
      notifyListeners();
      return;
    }

    final key = '$_prefsKey.$userId';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(key);
    if (raw == null) {
      // If the user has no saved categories yet, seed defaults for them.
      if (_items.isEmpty) {
        _items.addAll([
          model.Category(id: _uuid.v4(), name: 'Pessoal', color: 0xFF7C4DFF),
          model.Category(id: _uuid.v4(), name: 'Trabalho', color: 0xFF26A69A),
          model.Category(id: _uuid.v4(), name: 'Estudo', color: 0xFF536DFE),
        ]);
        await _save();
      }
      _loaded = true;
      notifyListeners();
      return;
    }

    _items
      ..clear()
      ..addAll(raw.map((s) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return model.Category(
          id: m['id'] as String,
          name: m['name'] as String,
          color: (m['color'] as num).toInt(),
        );
      }));

    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
  if (_userId == null) return; // nothing to save when no user
  final key = '$_prefsKey.$_userId';
  final prefs = await SharedPreferences.getInstance();
  final List<String> list = _items
      .map((c) => jsonEncode({'id': c.id, 'name': c.name, 'color': c.color}))
      .toList(growable: false);
  await prefs.setStringList(key, list);
  }

  void add(String name, int color) {
    final n = name.trim();
    if (n.isEmpty) return;
    _items.add(model.Category(id: _uuid.v4(), name: n, color: color));
    _save();
    notifyListeners();
  }

  void update(String id, {String? name, int? color}) {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) return;
    final c = _items[i];
    _items[i] = model.Category(
      id: c.id,
      name: (name?.trim().isEmpty == false) ? name!.trim() : c.name,
      color: color ?? c.color,
    );
    _save();
    notifyListeners();
  }

  void remove(String id) {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) return;
    _items.removeAt(i);
    _save();
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _items.length);
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    _save();
    notifyListeners();
  }
}
