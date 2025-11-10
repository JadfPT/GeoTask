import 'dart:async';

import '../data/task_store.dart';
import 'notification_service.dart';
import 'geofence_watcher.dart';
import 'foreground_service.dart';

/*
  Ficheiro: notification_controller.dart
  Propósito: Orquestrar notificações por tempo e por localização.

  Descrição:
  - Liga o `TaskStore` ao `GeofenceWatcher` e ao `NotificationService`.
  - Inicia um timer periódico para verificar tarefas com `due` e também
    arranca o watcher de geofences para notificações de proximidade.

  Observações:
  - Inicia um `ForegroundService` para melhorar a
    probabilidade de receber actualizações em background em Android.
  - Mantém lógica para evitar reenvios repetidos: `lastNotifiedAt` em cada
    tarefa é usado para deduplicação persistente.
*/

class NotificationController {
  NotificationController._();
  static final NotificationController instance = NotificationController._();

  TaskStore? _store;
  Timer? _timer;

/// Conectar a um TaskStore. Isso inicia um temporizador periódico e o observador de geofence.
/// Conectar novamente ao mesmo armazenamento não tem efeito.
  void attach(TaskStore store) {
    if (identical(_store, store)) return;
    detach();
    _store = store;
    _store!.addListener(_onTasksChanged);
    // Iniciar o observador de geofence, que acionará notificações ao entrar
    GeofenceWatcher.instance.start(store);
    // iniciar um serviço em foreground para que o app tenha mais probabilidade de continuar a receber
    // atualizações de localização em background. Esta é uma notificação persistente leve
    // que mantém o processo ativo na maioria dos dispositivos Android.
    ForegroundService.start(title: 'GeoTask', content: 'A vigiar localização');
    // verificação periódica para tarefas com prazo a cada 30 segundos
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkDue());
    // executar verificação inicial imediatamente
    _checkDue();
  }

  /// Desconectar do armazenamento atual e parar temporizadores/observadores.
  void detach() {
    _timer?.cancel();
    _timer = null;
    if (_store != null) {
      try {
        _store!.removeListener(_onTasksChanged);
      } catch (_) {}
      _store = null;
    }
    // parar o observador de geofence
    GeofenceWatcher.instance.stop();
  // parar o serviço em foreground se estiver a correr
  ForegroundService.stop();
    // os timestamps de notificação persistidos por tarefa são usados; não há nada para
    // limpar aqui.
  }

  void _onTasksChanged() {
    // Se tarefas foram adicionadas/removidas/atualizadas, reavaliar tarefas com prazo imediato
    _checkDue();
    // Também limpar notificações para tarefas que não estão mais presentes/concluídas
    if (_store == null) return;
    // Nenhum conjunto de deduplicação em memória: o valor persistido `lastNotifiedAt` por tarefa
    // na base de dados será usado para evitar reenvio de notificações.
  }

  Future<void> _checkDue() async {
    final s = _store;
    if (s == null) return;
    final now = DateTime.now();
    for (final t in s.items) {
      if (t.done) continue;
      final id = t.id;
      if (t.due == null) continue;
      // pular se já registamos uma notificação após (ou no) horário
      // devido. Persistimos lastNotifiedAt por tarefa para que reinícios do app
      // não reenviem repetidamente a mesma notificação atrasada.
      if (t.lastNotifiedAt != null) {
        // Se lastNotifiedAt for igual ou posterior ao horário previsto, assumir que já foi enviada a notificação.        
        if (!t.lastNotifiedAt!.isBefore(t.due!)) continue;
      }

    // notificar se o prazo expirou
      if (!t.due!.isAfter(now)) {
        final nid = _notifIdForTask(id);
        try {
          await NotificationService.instance.show(
            id: nid,
            title: 'Tarefa: ${t.title}',
            body: t.note ?? 'Hora de executar a tarefa',
          );
          // persistir que notificamos agora
          await s.markTaskNotified(id, DateTime.now());
        } catch (_) {}
      }
    }
  }

  int _notifIdForTask(String taskId) => taskId.hashCode & 0x7fffffff;
}
