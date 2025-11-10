// lib/pages/map/map_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

/*
  Ficheiro: map_page.dart
  Propósito: Apresentar e interagir com o mapa principal da aplicação.

  Descrição concisa:
  - Mostra as tarefas com localização como marcadores e círculos.
  - Gerencia a câmara (centrar no utilizador ou num ponto pedido por outra página).
  - Usa um stream partilhado para actualizações de posição para reduzir consumo.
  - Fornece mecanismos de fallback (última posição conhecida / localização fixa).
*/

// Persistência da câmera removida: preferimos sempre tentar localizar o usuário
// ao abrir o mapa e recorrer a uma localização estática se não estiver disponível.

import '../../data/task_store.dart';
import '../../models/task.dart';
import 'location_sheet.dart';
import '../../widgets/app_snackbar.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  // Pedido externo: defina isto antes de navegar para '/map' para pedir ao mapa
  // para animar para um ponto específico na criação.
  static LatLng? pendingCenter;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  /// Memória simples da câmara durante a vida da app (para não voltar a Lisboa).
  static CameraPosition? _rememberedCamera;
  
  // Verificar se já tentamos a localização inicial durante este processo
  // sessão da app. Isto previne mostrar o indicador de localização sempre que
  // o utilizador navega para a página.
  static bool _initialLocateTried = false;

  static const _fallback = LatLng(40.280572969058966, -7.5043608514295075); // Covilhã
  static const _zoomBtn = 48.0; // tamanho aprox. botões nativos +/- (Android)
  static const _zoomGap = 8.0; // gap entre + e -

  final _mapCtrl = Completer<GoogleMapController>();

  MapType _mapType = MapType.normal;
  LatLng _center = _fallback;
  LatLng? _user;
  // Quando alternado, força a camada de localização do GoogleMap a ser recriada; isto
  // ajuda em alguns dispositivos/versões onde o ponto azul desaparece após
  // navegar para longe e voltar.
  bool _showMyLocation = true;
  // Posicione a assinatura do fluxo para atualizações mais rápidas.
  // assinatura a nível de instância removida em favor de assinatura estática compartilhada
  // Assinatura compartilhada e última posição entre instâncias de página para que só
  // pesquisemos ativamente uma vez por sessão de aplicativo.
  static StreamSubscription<Position>? _sharedPosSub;
  static Position? _sharedLastPos;
  bool _locating = false; // mostrar indicador "a procurar" enquanto espera
  bool _gotInitialFix = false;
  // sem temporizador de persistência

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tente obter a última posição conhecida imediatamente para que possamos mostrar isso rapidamente.
    _prefetchLastOrFallback();
    // Solicite/verifique proativamente a permissão de localização para que, quando o mapa
    // solicitar uma posição nova, não bloqueemos no diálogo de permissão.
    // Isso é não bloqueante e não mostrará UI em caso de negação; o explícito
    // _centerOnMe() chamado a partir do botão ainda mostra SnackBars.
    _ensurePermission();
   // Sem câmera persistente: prefira uma nova localização ou uma alternativa.
   // Se já tivermos uma última posição conhecida compartilhada de um fluxo anterior,
   // use-a para que não mostremos a alternativa.
    if (_sharedLastPos != null) {
      _user = LatLng(_sharedLastPos!.latitude, _sharedLastPos!.longitude);
      _center = _user!;
      _gotInitialFix = true;
    }

    // Iniciar fluxo de posição para obter atualizações de localização mais rápidas (melhor esforço)
    // apenas se ainda não tentamos a localização inicial nesta sessão.
    if (!_initialLocateTried) {
      _startPositionStream(showLocating: true);
    } else if (_sharedPosSub != null) {
      // assinatura compartilhada já em execução; a instância irá captar
      // a última posição conhecida de `_sharedLastPos` (definida acima)
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Quando a app/página for retomado, verifique se temos permissão e tente uma
    // localização rápida para que o ponto azul apareça de forma confiável.
    if (state == AppLifecycleState.resumed) {
      _ensurePermission();
      // Se não tivermos uma última posição conhecida compartilhada, tente uma localização rápida.
      if (_sharedLastPos == null) {
        _centerOnMeBackground();
      }

      // Alguns dispositivos precisam que a camada de localização seja reativada para mostrar o ponto azul após uma navegação. 
      // Altere a flag brevemente para forçar uma nova renderização.

      if (mounted) {
        setState(() => _showMyLocation = false);
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          setState(() => _showMyLocation = true);
        });
      }
    }
  }

  Future<void> _prefetchLastOrFallback() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        setState(() => _center = LatLng(last.latitude, last.longitude));
        // Se o controlador do mapa já estiver pronto e não tivermos uma câmera lembrada,
        // mova a câmera rapidamente para a última posição conhecida para que o
        // usuário não veja o fallback por mais tempo do que o necessário.
        if (_mapCtrl.isCompleted && _rememberedCamera == null && !_gotInitialFix) {
          _animate(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: _center, zoom: 12),
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _animate(CameraUpdate update) async {
    if (!_mapCtrl.isCompleted) return;
    final c = await _mapCtrl.future;
    await c.animateCamera(update);
  }

  Future<void> _centerOnMe() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (!mounted) return;
        showAppSnackBar(context, 'Permissão de localização negada');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      _user = here;
      setState(() => _center = here);
      await _animate(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: here, zoom: 15.5),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Não foi possível obter a localização');
    }
  }

  /// Tente obter uma localização atualizada em segundo plano sem mostrar
  /// snackbars de permissão e com um tempo limite curto — usado na primeira
  /// abertura do mapa para que a interface do usuário não fique bloqueada
  /// aguardando um fixo de GPS.
  Future<void> _centerOnMeBackground() async {
    // Exibir a interface de localização apenas na primeira tentativa de localização.
    if (!_initialLocateTried) {
      _locating = true;
      if (mounted) setState(() {});
    }
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        return; // não incomode o usuário com mensagens aqui
      }
      // Tente rapidamente obter uma posição atual — o tempo limite evita esperas longas.
  final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 6));
  final here = LatLng(pos.latitude, pos.longitude);
  _user = here;
  _sharedLastPos = pos;
      if (!mounted) return;
      setState(() {
        _center = here;
      });
      // Animar sem aguardar para evitar o bloqueio de callbacks do mapa/interface do usuário.
      _animate(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: here, zoom: 15.5),
        ),
      );
      if (!_initialLocateTried) {
        _locating = false;
        if (mounted) setState(() {});
      }
      _initialLocateTried = true;
    } catch (_) {
      if (!_initialLocateTried) {
        _locating = false;
        if (mounted) setState(() {});
      }
      _initialLocateTried = true;
    // Ignorar timeouts ou outras falhas silenciosamente — o mapa já está centralizado em
    // última posição conhecida ou de fallback para que a experiência do usuário continue boa.
    }
  }

  /// Garantir permissão proativamente, mas silenciosamente.
  Future<LocationPermission> _ensurePermission() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      return p;
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  Future<void> _startPositionStream({bool showLocating = false}) async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        return;
      }
      // Marcar localização apenas se solicitado (primeira visita de abertura do app).
      if (showLocating) {
        _locating = true;
        if (mounted) setState(() {});
      }

      final settings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      );

      // Se uma assinatura compartilhada já existe, conecte-se a ela em vez de
      // criar uma nova para que só consultemos ativamente uma vez por sessão.
      if (_sharedPosSub != null) {
        return;
      }

      _sharedPosSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
        final here = LatLng(pos.latitude, pos.longitude);
        _sharedLastPos = pos;
        // Se esta instância estiver montada, atualize a interface do usuário
        if (mounted) {
          _user = here;
          setState(() {});
        }
        if (!_gotInitialFix) {
          _gotInitialFix = true;
          if (showLocating) {
            _locating = false;
            if (mounted) setState(() {});
          }
          // animar uma vez para a localização do usuário
          _animate(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: here, zoom: 15.5),
            ),
          );
          // Tentamos a localização inicial agora; não mostrar "localizando" novamente
          // em aberturas subsequentes durante esta sessão do aplicativo.
          _initialLocateTried = true;
        }
      });
  // manter a referência compartilhada em `_sharedPosSub` para que outras instâncias possam
  // reutilizá-la; não mantemos uma assinatura em nível de instância.
    } catch (_) {
      if (showLocating) {
        _locating = false;
        if (mounted) setState(() {});
      }
      _initialLocateTried = true;
    }
  }

  // dispose removido (tratado anteriormente para remover observador)

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final tasksWithPoint = store.items.where((t) => t.point != null).toList();

    final safe = MediaQuery.of(context).padding;

    // padding FIXO → logo "Google" e +/− não saltam
    final mapPadding = EdgeInsets.only(
      bottom: safe.bottom + 12,
      right: 12,
      top: 8,
      left: 0,
    );

    final cs = Theme.of(context).colorScheme;

    final markers = <Marker>{
      for (final t in tasksWithPoint)
        Marker(
          markerId: MarkerId('task_${t.id}'),
          position: t.point!,
          infoWindow: InfoWindow(
            title: t.title,
            snippet: _mkSnippet(t),
            onTap: () async {
              final c = await _mapCtrl.future;
              await c.showMarkerInfoWindow(MarkerId('task_${t.id}'));
            },
          ),
        ),
    };


    final circles = <Circle>{
      for (final t in tasksWithPoint)
        Circle(
          circleId: CircleId('c_${t.id}'),
          center: t.point!,
          radius: t.radiusMeters,
          strokeWidth: 2,
          strokeColor: cs.primary.withAlpha((0.35 * 255).round()),
          fillColor: cs.primary.withAlpha((0.12 * 255).round()),
        ),
    };

    // Note: native blue dot is used; no custom user marker/circle here.

    // alinhar verticalmente o centro do nosso botão com o centro do cluster nativo +/-:
    // clusterHeight = 48 (+) + 8 (gap) + 48 (-) = 104
    // centro do nosso (56) alinhado ao do cluster -> bottom = 16 + safe + (104/2 - 56/2)
    const ourBtn = 56.0;
    final clusterHeight = (_zoomBtn * 2) + _zoomGap; // 48+8+48=104
    final bottomOffset = 16 + safe.bottom + (clusterHeight / 2) - (ourBtn / 2);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 44,
        title: const Text('Mapa'),
        actions: [
          IconButton(
            tooltip: _mapType == MapType.normal ? 'Satélite' : 'Normal',
            onPressed: () => setState(() {
              _mapType = _mapType == MapType.normal
                  ? MapType.satellite
                  : MapType.normal;
            }),
            icon: const Icon(Icons.layers_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: _mapType,
            initialCameraPosition:
                _rememberedCamera ?? CameraPosition(target: _center, zoom: 12),
            onMapCreated: (c) async {
              if (!_mapCtrl.isCompleted) _mapCtrl.complete(c);
              // centra automaticamente SÓ na 1ª abertura (sem memória anterior)
              if (_rememberedCamera == null) {
                // Mover rapidamente para o centro conhecido ou de fallback sem
                // esperar por uma possível correção lenta do GPS.
                _animate(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _center, zoom: 12),
                  ),
                );
                // Tentar obter uma localização atualizada em segundo plano e animar
                // a câmera quando disponível.
                _centerOnMeBackground();
              }
              // Se ainda não temos uma última posição conhecida compartilhada (por exemplo
              // após navegar para longe e voltar), dispare uma localização rápida em segundo plano
              // para que o ponto azul nativo apareça mais rápido.
              if (_sharedLastPos == null) {
                _centerOnMeBackground();
              }
              // Se outra página solicitou que o mapa se centralizasse em um ponto específico,
              // faça isso agora e limpe a solicitação.
              if (MapPage.pendingCenter != null) {
                final p = MapPage.pendingCenter!;
                MapPage.pendingCenter = null;
                _animate(CameraUpdate.newCameraPosition(
                  CameraPosition(target: p, zoom: 16),
                ));
              }
            },
            padding: mapPadding,
            myLocationEnabled: _showMyLocation,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true, // nativos
            compassEnabled: true,
            onCameraMove: (cam) {
              // memoriza posição/zoom/bearing/tilt durante a sessão
              _rememberedCamera = cam;
              _center = cam.target;
            },
            markers: markers,
            circles: circles,
          ),

          // indicador de localização
          if (_locating)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 8),
                        Text('A procurar localização...', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Botão "minha localização": à ESQUERDA dos +/− e centros alinhados
          Positioned(
            right: 16 + _zoomBtn + _zoomGap,
            bottom: bottomOffset,
            child: SafeArea(
              top: false,
              child: IconButton.filled(
                onPressed: _centerOnMe,
                icon: const Icon(Icons.my_location),
                style: IconButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                tooltip: 'Ir para a minha localização',
              ),
            ),
          ),

          // Folha dos locais (ficheiro separado)
          LocationSheet(
            tasks: tasksWithPoint,
            user: _user,
            onTapTask: (t) async {
              final c = await _mapCtrl.future;
              await c.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: t.point!, zoom: 16),
                ),
              );
              await c.showMarkerInfoWindow(MarkerId('task_${t.id}'));
            },
          ),
        ],
      ),
    );
  }

  String _mkSnippet(Task t) {
    final parts = <String>[];
    if (t.category != null) parts.add(t.category!);
    if (t.due != null) {
      final d = t.due!;
      parts.add(
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
      );
    }
    if (t.radiusMeters > 0) parts.add('${t.radiusMeters.toStringAsFixed(0)} m');
    return parts.join(' • ');
  }

}
