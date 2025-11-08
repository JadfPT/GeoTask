// lib/pages/map/map_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
// Camera persistence removed: we prefer always attempting to locate the user
// on map open and fall back to a static location if unavailable.

import '../../data/task_store.dart';
import '../../models/task.dart';
import 'location_sheet.dart';
import '../../widgets/app_snackbar.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  // External request: set this before navigating to '/map' to ask the map
  // to animate to a specific point on create.
  static LatLng? pendingCenter;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  /// Memória simples da câmara durante a vida da app (para não voltar a Lisboa).
  static CameraPosition? _rememberedCamera;
  
  // Track whether we've already attempted the initial locate during this
  // app session. This prevents showing the locating indicator every time
  // the user navigates to the page.
  static bool _initialLocateTried = false;

  static const _fallback = LatLng(40.280572969058966, -7.5043608514295075); // Covilhã
  static const _zoomBtn = 48.0; // tamanho aprox. botões nativos +/- (Android)
  static const _zoomGap = 8.0; // gap entre + e -

  final _mapCtrl = Completer<GoogleMapController>();

  MapType _mapType = MapType.normal;
  LatLng _center = _fallback;
  LatLng? _user;
  // When toggled, forces the GoogleMap location layer to re-create; this
  // helps in some devices/versions where the blue dot disappears after
  // navigating away and back.
  bool _showMyLocation = true;
  // Position stream subscription for quicker/faster updates.
  // instance-level subscription removed in favor of shared static subscription
  // Shared subscription and last position across page instances so we only
  // actively search once per app session.
  static StreamSubscription<Position>? _sharedPosSub;
  static Position? _sharedLastPos;
  bool _locating = false; // show "a procurar" indicator while waiting
  bool _gotInitialFix = false;
  // no persistence timer anymore

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Try to get last-known position immediately so we can show that quickly.
    _prefetchLastOrFallback();
    // Proactively request/check location permission so that when the map
    // requests a fresh position we don't block on the permission dialog.
    // This is non-blocking and won't show UI on denial; the explicit
    // _centerOnMe() called from the button still shows SnackBars.
    _ensurePermission();
    // No persisted camera: prefer a fresh locate or fallback.
    // If we already have a shared last-known position from a previous
    // stream, use it so we don't show the fallback.
    if (_sharedLastPos != null) {
      _user = LatLng(_sharedLastPos!.latitude, _sharedLastPos!.longitude);
      _center = _user!;
      _gotInitialFix = true;
    }

    // Start position stream to get faster location updates (best-effort)
    // only if we haven't attempted the initial locate in this session.
    if (!_initialLocateTried) {
      _startPositionStream(showLocating: true);
    } else if (_sharedPosSub != null) {
      // shared subscription already running; instance will pick up
      // last-known position from `_sharedLastPos` (set above)
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When the app/page resumes, ensure we have permission and try a
    // quick locate so the blue dot appears reliably.
    if (state == AppLifecycleState.resumed) {
      _ensurePermission();
      // If we don't have a shared last-known pos, try a quick locate.
      if (_sharedLastPos == null) {
        _centerOnMeBackground();
      }

      // Some devices need the location layer re-enabled to show the blue
      // dot after a navigation. Toggle the flag briefly to force a redraw.
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
        // If the map controller is already ready and we don't have a remembered
        // camera, move the camera quickly to the last-known position so the
        // user doesn't see the fallback for longer than necessary.
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

  /// Try to get a fresh location in background without showing permission
  /// snackbars and with a short timeout — used on first map open so UI
  /// doesn't block waiting for a GPS fix.
  Future<void> _centerOnMeBackground() async {
    // Only show locating UI the first time we attempt an initial locate.
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
        return; // don't spam the user with messages here
      }
      // Try quickly to get a current position — timeout avoids long waits.
  final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 6));
  final here = LatLng(pos.latitude, pos.longitude);
  _user = here;
  _sharedLastPos = pos;
      if (!mounted) return;
      setState(() {
        _center = here;
      });
      // Animate without awaiting to avoid blocking map callbacks/UI.
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
      // ignore timeouts or other failures silently — map already centered on
      // last-known or fallback position so UX is still fine.
    }
  }

  /// Ensure permission proactively but silently.
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
      // Mark locating only if requested (first app-open visit).
      if (showLocating) {
        _locating = true;
        if (mounted) setState(() {});
      }

      final settings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      );

      // If a shared subscription already exists, attach to it instead of
      // creating a new one so we only actively query once per session.
      if (_sharedPosSub != null) {
        return;
      }

      _sharedPosSub = Geolocator.getPositionStream(locationSettings: settings).listen((pos) {
        final here = LatLng(pos.latitude, pos.longitude);
        _sharedLastPos = pos;
        // If this instance is mounted, update UI
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
          // animate once to the user's location
          _animate(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: here, zoom: 15.5),
            ),
          );
          // We attempted the initial locate now; don't show locating again
          // on subsequent opens during this app session.
          _initialLocateTried = true;
        }
      });
  // keep the shared reference in `_sharedPosSub` so other instances can
  // reuse it; we don't keep an instance-level subscription.
    } catch (_) {
      if (showLocating) {
        _locating = false;
        if (mounted) setState(() {});
      }
      _initialLocateTried = true;
    }
  }

  // dispose removed (handled earlier to remove observer)

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
                // Move quickly to the last-known or fallback center without
                // waiting for a potentially slow GPS fix.
                _animate(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _center, zoom: 12),
                  ),
                );
                // Try to obtain a fresh location in background and animate
                // the camera when available.
                _centerOnMeBackground();
              }
              // If we don't yet have a shared last-known position (for example
              // after navigating away and back), trigger a quick background
              // locate so the native blue dot appears faster.
              if (_sharedLastPos == null) {
                _centerOnMeBackground();
              }
              // If another page requested the map to centre on a specific
              // point, do it now and clear the request.
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

          // locating indicator
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
