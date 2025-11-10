import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/task.dart';
import 'db/task_dao.dart';

/*
  Ficheiro: task_store.dart
  Propósito: Store que gere a lista de tarefas em memória e persiste através do TaskDao.

  Descrição:
  - Mantém uma lista interna `_items` e expõe operações para adicionar,
    actualizar, remover e carregar tarefas do DB.
  - As operações persistentes são executadas antes de actualizar a lista em
    memória quando relevante, para reduzir divergência entre UI e BD.
  - Fornece métodos utilitários como `seed` para popular exemplos e
    `markTaskNotified` para registar quando uma notificação foi enviada.
*/

/// Store responsável por operações CRUD simples sobre tarefas.
class TaskStore extends ChangeNotifier {
  final List<Task> _items = [];
  List<Task> get items => List.unmodifiable(_items);

  /// Insere uma nova tarefa e a persiste. Notifica os ouvintes após a inserção.
  Future<void> add(Task t) async {
    await TaskDao.instance.insert(t);
    _items.insert(0, t);
    notifyListeners();
  }

  /// Atualiza uma tarefa (se houver) e persiste as alterações.
  Future<void> update(Task t) async {
    final i = _items.indexWhere((e) => e.id == t.id);
    if (i >= 0) {
      await TaskDao.instance.update(t);
      _items[i] = t;
      notifyListeners();
    }
  }

  /// Alterna o estado `done` da tarefa com [id] e persiste a atualização.
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

  /// Remove uma tarefa pelo id e persiste a eliminação.
  Future<void> remove(String id) async {
    // Persiste a eliminação primeiro. Se a operação na BD falhar, mantemos o
    // item em memória para evitar divergência entre UI e BD.
    await TaskDao.instance.delete(id);
    _items.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Semeia tarefas de exemplo se a store estiver vazia.
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

  /// Inicializa o armazenamento carregando tarefas da base de dados. Chama este método após a criação do provedor, se necessário.
  Future<void> loadFromDb({String? ownerId}) async {
    final items = await TaskDao.instance.getAllForOwner(ownerId);
    _items
      ..clear()
      ..addAll(items);
    notifyListeners();
  }

  /// Marca uma tarefa como tendo enviado uma notificação em [when]. Persiste a alteração
  /// e atualiza o item em memória. Útil para evitar notificações duplicadas
  /// após reinícios da aplicação.
  Future<void> markTaskNotified(String id, DateTime when) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final t = _items[i];
    final updated = t.copyWith(lastNotifiedAt: when);
    await TaskDao.instance.update(updated);
    _items[i] = updated;
    notifyListeners();
  }
}
