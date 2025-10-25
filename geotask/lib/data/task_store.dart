import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/task.dart';

class TaskStore extends ChangeNotifier {
  final List<Task> _items = [];
  List<Task> get items => List.unmodifiable(_items);

  /// Categorias geridas nas Definições
  final List<String> _categories = ['Pessoal', 'Trabalho', 'Estudo'];
  List<String> get categories => List.unmodifiable(_categories);

  void addCategory(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    if (_categories.contains(n)) return;
    _categories.add(n);
    notifyListeners();
  }

  void removeCategory(String name) {
    _categories.remove(name);
    notifyListeners();
  }

  void add(Task t) {
    _items.insert(0, t);
    notifyListeners();
  }

  void update(Task t) {
    final i = _items.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      _items[i] = t;
      notifyListeners();
    }
  }

  void toggleDone(String id) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) {
      final t = _items[i];
      _items[i] = t.copyWith(done: !t.done);
      notifyListeners();
    }
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  // Dados de exemplo
  void seed() {
    if (_items.isNotEmpty) return;
    final now = DateTime.now();
    add(Task(
      id: _genId(),
      title: 'Comprar materiais',
      note: 'Lembrar de passar na loja X',
      due: now.add(const Duration(hours: 10)),
      category: 'Pessoal',
      point: const LatLng(38.7369, -9.1427),
      radiusMeters: 200,
    ));
    add(Task(
      id: _genId(),
      title: 'Enviar relatório',
      due: now.add(const Duration(hours: 6)),
      done: false,
      category: 'Trabalho',
    ));
  }

  String _genId() =>
      DateTime.now().millisecondsSinceEpoch.toString() +
      Random().nextInt(999).toString();
}
