import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/task.dart';

class TaskStore extends ChangeNotifier {
  final List<Task> _items = [];
  List<Task> get items => List.unmodifiable(_items);

  void add(Task t) {
    _items.insert(0, t);
    notifyListeners();
  }

  void update(Task t) {
    final i = _items.indexWhere((e) => e.id == t.id);
    if (i != -1) {
      _items[i] = t;
      notifyListeners();
    }
  }

  void remove(String id) {
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  void toggleDone(String id) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i != -1) {
      _items[i] = _items[i].copyWith(done: !_items[i].done);
      notifyListeners();
    }
  }

  /// demo seed (remove em produção)
  void seedDemo() {
    if (_items.isNotEmpty) return;
    final now = DateTime.now();
    add(Task(
      id: _genId(),
      title: 'Comprar materiais',
      note: 'Lembrar de passar na loja X',
      due: now.add(const Duration(days: 1)),
      point: const LatLng(38.7369, -9.1427),
      radiusMeters: 200,
    ));
    add(Task(
      id: _genId(),
      title: 'Enviar relatório',
      due: now.add(const Duration(hours: 6)),
      done: false,
    ));
  }

  String _genId() => DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(999).toString();
}
