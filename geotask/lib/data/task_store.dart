import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/task.dart';
import 'db/task_dao.dart';

/// TaskStore maintains an in-memory list of tasks and persists changes via
/// [TaskDao]. The store exposes simple methods for add/update/delete and a
/// load method to initialize state from the database.
class TaskStore extends ChangeNotifier {
  final List<Task> _items = [];
  List<Task> get items => List.unmodifiable(_items);

  /// Insert a new task and persist it. Notifies listeners after insertion.
  Future<void> add(Task t) async {
    await TaskDao.instance.insert(t);
    _items.insert(0, t);
    notifyListeners();
  }

  /// Update a task (if present) and persist the changes.
  Future<void> update(Task t) async {
    final i = _items.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      await TaskDao.instance.update(t);
      _items[i] = t;
      notifyListeners();
    }
  }

  /// Toggle the `done` state for the task with [id] and persist the update.
  Future<void> toggleDone(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) {
      final t = _items[i];
      final updated = t.copyWith(done: !t.done);
      await TaskDao.instance.update(updated);
      _items[i] = updated;
      notifyListeners();
    }
  }

  /// Remove a task by id and persist deletion.
  Future<void> remove(String id) async {
    // Persist deletion first. If the DB operation fails we keep the in-memory
    // item to avoid UI/DB divergence.
    await TaskDao.instance.delete(id);
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Seed example tasks if the store is empty.
  Future<void> seed() async {
    if (_items.isNotEmpty) return;
    final now = DateTime.now();
    await add(Task(
      id: _genId(),
      title: 'Comprar materiais',
      note: 'Lembrar de passar na loja X',
      due: now.add(const Duration(hours: 10)),
      category: 'Pessoal',
      point: const LatLng(38.7369, -9.1427),
      radiusMeters: 200,
    ));
    await add(Task(
      id: _genId(),
      title: 'Enviar relatório',
      due: now.add(const Duration(hours: 6)),
      done: false,
      category: 'Trabalho',
    ));
  }

  String _genId() => DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(999).toString();

  /// Initialize store by loading tasks from DB. Call this after provider creation if needed.
  Future<void> loadFromDb({String? ownerId}) async {
    final items = await TaskDao.instance.getAllForOwner(ownerId);
    _items
      ..clear()
      ..addAll(items);
    notifyListeners();
  }
}
