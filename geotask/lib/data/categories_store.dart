import 'package:flutter/foundation.dart' show ChangeNotifier; // evita 'Category' ambíguo
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';

/// Store simples com persistência em SharedPreferences.
class CategoriesStore extends ChangeNotifier {
  static const _prefsKey = 'categories.v1';
  final List<Category> _items = <Category>[];

  List<Category> get items => List.unmodifiable(_items);

  final _uuid = const Uuid();

  CategoriesStore() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);

    if (raw == null) {
      // defaults
      _items
        ..clear()
        ..addAll([
          Category(id: _uuid.v4(), name: 'Pessoal', color: 0xFF7C4DFF),
          Category(id: _uuid.v4(), name: 'Trabalho', color: 0xFF26A69A),
          Category(id: _uuid.v4(), name: 'Estudo', color: 0xFF5C6BC0),
        ]);
      await _save();
    } else {
      _items
        ..clear()
        ..addAll(raw.map((e) => Category.fromJson(e)));
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      _items.map((e) => e.toJson()).toList(),
    );
  }

  /// Substitui todas as categorias (usado no ecrã de edição ao clicar Guardar).
  Future<void> setAll(List<Category> next) async {
    _items
      ..clear()
      ..addAll(next);
    await _save();
    notifyListeners();
  }

  // Helpers opcionais
  Category add(String name, int color) {
    final c = Category(id: _uuid.v4(), name: name, color: color);
    _items.add(c);
    _save();
    notifyListeners();
    return c;
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    _save();
    notifyListeners();
  }

  void update(Category c) {
    final i = _items.indexWhere((e) => e.id == c.id);
    if (i != -1) {
      _items[i] = c;
      _save();
      notifyListeners();
    }
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
