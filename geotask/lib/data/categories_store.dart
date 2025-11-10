import 'dart:async';
import 'package:flutter/foundation.dart' hide Category; // evita conflito com foundation
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart' as model;
import 'db/category_dao.dart';

/*
  Ficheiro: categories_store.dart
  Propósito: Store para gerir categorias do utilizador.

  Principais responsabilidades:
  - Carregar categorias do SQLite, migrar dados legados de SharedPreferences
    e semear categorias por omissão na primeira execução.
  - Fornecer operações por-posição (insert/update/delete/reorder) que
    persistem individualmente para evitar reescritas amplas da tabela.
  - Manter um mecanismo de carregamento concorrente (`_loadingCompleter`)
    para prevenir múltiplos seedings em caso de chamadas concorrentes.
*/

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
    // Se já houver um load em progresso, aguardar para evitar condições de corrida
    if (_loadingCompleter != null) {
      await _loadingCompleter!.future;
      // Se o userId coincidir e já estivermos carregados, nada a fazer
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
    // Migrar categorias legadas em SharedPreferences para a BD se existirem
    final legacyKey = 'categories.v1.$userId';
    final legacy = prefs.getStringList(legacyKey);
    if (legacy != null) {
      // migrar para DB e remover legado
      final migrated = legacy.map((s) => model.Category.fromJson(s)).toList(growable: false);
      for (var i = 0; i < migrated.length; i++) {
        await CategoryDao.instance.insert(migrated[i], userId, sortIndex: i);
      }
      await prefs.remove(legacyKey);
    }

    final rows = await CategoryDao.instance.getAllForOwner(userId);
    if (rows.isEmpty) {
      // semear defaults na primeira execução para melhor UX
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

  // NOTE: implementação anterior incluía um `_saveToDb` que reescrevia tudo.
  // Mantemos persistência por operação (insert/update/delete/reorder) para
  // evitar reescritas amplas e facilitar raciocínio sobre o estado.

  /// Adiciona uma nova categoria para o utilizador actual e persiste-a.
  /// Se não houver utilizador associado, retorna imediatamente.
  Future<void> add(String name, int color) async {
    final n = name.trim();
    if (n.isEmpty) return;
    if (_userId == null) return;
    final c = model.Category(id: _uuid.v4(), name: n, color: color);
    // persistir com o próximo sortIndex
    await CategoryDao.instance.insert(c, _userId!, sortIndex: _items.length);
    _items.add(c);
    notifyListeners();
  }

  /// Actualiza uma categoria existente e persiste a alteração.
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

  /// Remove uma categoria e persiste a eliminação.
  Future<void> remove(String id) async {
    final i = _items.indexWhere((c) => c.id == id);
    if (i == -1) return;
    await CategoryDao.instance.delete(id);
    _items.removeAt(i);
    notifyListeners();
  }

  /// Reordena a lista local e persiste a nova ordem.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _items.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    newIndex = newIndex.clamp(0, _items.length);
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    // persistir ordem
    await CategoryDao.instance.reorder(_items.map((e) => e.id).toList());
    notifyListeners();
  }
}
