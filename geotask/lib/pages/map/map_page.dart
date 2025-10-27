// lib/pages/map/map_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../data/task_store.dart';
import '../../models/task.dart';
import 'location_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  /// Memória simples da câmara durante a vida da app (para não voltar a Lisboa).
  static CameraPosition? _rememberedCamera;

  static const _fallback = LatLng(38.7369, -9.1427); // Lisboa
  static const _zoomBtn = 48.0; // tamanho aprox. botões nativos +/- (Android)
  static const _zoomGap = 8.0; // gap entre + e -

  final _mapCtrl = Completer<GoogleMapController>();

  MapType _mapType = MapType.normal;
  LatLng _center = _fallback;
  LatLng? _user;

  @override
  void initState() {
    super.initState();
    _prefetchLastOrFallback();
  }

  Future<void> _prefetchLastOrFallback() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        setState(() => _center = LatLng(last.latitude, last.longitude));
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização negada')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter a localização')),
      );
    }
  }

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
                await _centerOnMe(); // centra só na 1ª vez
              }
            },
            padding: mapPadding,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true, // nativos
            compassEnabled: true,
            onCameraMove: (cam) {
              // memoriza posição/zoom/bearing/tilt sempre que mexer
              _rememberedCamera = cam;
              _center = cam.target;
            },
            markers: markers,
            circles: circles,
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
