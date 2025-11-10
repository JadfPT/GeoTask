import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../data/task_store.dart';
import 'location_service.dart';
import 'notification_service.dart';

/*
  Ficheiro: geofence_watcher.dart
  Propósito: Vigiar a localização e disparar notificações quando o utilizador
  entra no raio de uma tarefa.

  Pontos-chave:
  - Solicita permissões via `LocationService.ensurePermissions`.
  - Usa `Geolocator.getPositionStream` com `distanceFilter` para reduzir
    consumo de bateria.
  - Deduplica notificações por tarefa por dia usando um conjunto em memória.
  - Para persistência de deduplicaçao entre reinícios usar `TaskDao.clearLastNotifiedForOwner`.
*/

class GeofenceWatcher {
  GeofenceWatcher._();
  static final GeofenceWatcher instance = GeofenceWatcher._();

  StreamSubscription<Position>? _sub;
  DateTime _dayKey = DateTime.now();
  final Set<String> _notifiedToday = {};
  // Rastrear o estado anterior de dentro/fora das tarefas para detectar eventos de entrada
  final Map<String, bool> _inside = {};

  /// Começar a monitorar mudanças de localização e avaliar tarefas próximas.
  ///
  /// `store` é o `TaskStore` ativo cujos `items` são inspecionados. Ter em
  /// mente que esta classe usa um conjunto em memória para evitar notificações
  /// duplicadas após reinícios da app — se for preciso persistência entre
  /// reinícios, persiste o estado `notified` externamente.
  Future<void> start(TaskStore store) async {
    await LocationService.ensurePermissions();
    await _sub?.cancel();

    // Inicializa a posição atual sem emitir notificações de entrada.
    Position? pos;
    try {
      pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    } catch (_) {
      // se a posição actual falhar, tenta a última conhecida. Se ambas falharem ainda
      // ouviremos o stream e definiremos estados na primeira atualização.
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {
        pos = null;
      }
    }

    // Seed _inside map: marcar quais tarefas estão atualmente dentro do raio de ação delas.
    if (pos != null) {
      for (final t in store.items) {
        if (t.done || t.point == null || t.radiusMeters <= 0) {
          _inside[t.id] = false;
          continue;
        }
        final d = Geolocator.distanceBetween(
          pos.latitude, pos.longitude,
          t.point!.latitude, t.point!.longitude,
        );
        _inside[t.id] = d <= t.radiusMeters;
      }
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25, // só reage quando se move ~25m
      ),
    ).listen((p) => _onPosition(p, store));
  }

  /// Limpar o estado em memória do geofence usado para deduplicação e deteção
  /// de entrada/saída. Isto não modifica os valores persistidos `lastNotifiedAt`
  /// na base de dados; use `TaskDao.clearLastNotifiedForOwner` para isso.
  ///
  /// Se for fornecido um [store], tentaremos inicializar o mapa `_inside` usando
  /// a última posição conhecida para que os eventos subsequentes de entrada/saída sejam precisos.
  Future<void> resetForStore(TaskStore? store) async {
    _notifiedToday.clear();
    _inside.clear();

    if (store == null) return;

    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return;
      for (final t in store.items) {
        if (t.done || t.point == null || t.radiusMeters <= 0) {
          _inside[t.id] = false;
          continue;
        }
        final d = Geolocator.distanceBetween(
          pos.latitude, pos.longitude,
          t.point!.latitude, t.point!.longitude,
        );
        _inside[t.id] = d <= t.radiusMeters;
      }
    } catch (_) {
      // ignorar erros; somente best-effort seeding
    }
  }

  /// Parar de monitorizar atualizações de localização.
  void stop() { _sub?.cancel(); _sub = null; }

  void _onPosition(Position pos, TaskStore store) {
    // reseta o “já notifiquei” diariamente
    final now = DateTime.now();
    if (!_isSameDay(_dayKey, now)) {
      _dayKey = now;
      _notifiedToday.clear();
    }

    for (final t in store.items) {
      if (t.done || t.point == null || t.radiusMeters <= 0) continue;

      final d = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        t.point!.latitude, t.point!.longitude,
      );

      final currInside = d <= t.radiusMeters;
      final prevInside = _inside[t.id] ?? false;

      // only trigger when transitioning from outside -> inside
      if (!prevInside && currInside) {
        // daily dedupe: don't send more than one per day
        final already = _notifiedToday.contains(t.id);
        if (!already) {
          NotificationService.instance.show(
            id: t.id.hashCode & 0x7fffffff,
            title: 'Estás perto: ${t.title}',
            body: t.note == null ? 'Dentro do raio desta tarefa.' : t.note!,
          );
          _notifiedToday.add(t.id); // uma vez por dia

          // Persistir o timestamp de data/hora da última notificação por meio do armazenamento (ignorar erros)
          store.markTaskNotified(t.id, DateTime.now()).catchError((_) {});
        }
      }

      // atualizar o estado de “dentro” para o próximo evento
      _inside[t.id] = currInside;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
