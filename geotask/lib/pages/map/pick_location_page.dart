import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class PickLocationArgs {
  final LatLng? initialPoint;
  final double initialRadius;
  const PickLocationArgs({this.initialPoint, this.initialRadius = 150});
}

class PickLocationResult {
  final LatLng point;
  final double radius;
  const PickLocationResult(this.point, this.radius);
}

class PickLocationPage extends StatefulWidget {
  final PickLocationArgs args;
  const PickLocationPage({super.key, required this.args});

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  GoogleMapController? _controller;

  // fallback (Covilhã)
  static const LatLng _fallbackCenter = LatLng(40.2795, -7.5060);

  LatLng? _point;
  double _radius = 150;

  bool _loading = true;
  bool _gpsOff = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _point = widget.args.initialPoint;
    _radius = widget.args.initialRadius;
    _ensureAndCenter();
  }

  Future<void> _ensureAndCenter() async {
    setState(() {
      _loading = true;
      _gpsOff = false;
      _status = 'A pedir permissões…';
    });

    try {
      // serviços ativos?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _gpsOff = true;
      }

      // permissões
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever ||
          perm == LocationPermission.denied) {
        // sem permissão => usa fallback/initial
        _status = 'Sem permissão. A usar localização predefinida.';
        await _moveCameraTo(_point ?? _fallbackCenter, zoom: 13);
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      // tenta lastKnown > current (com timeout)
      final me = await _getBestLocation();
      await _moveCameraTo(me, zoom: 16);
      if (_point == null) _point = me;
    } catch (_) {
      // qualquer falha => usa fallback/initial
      await _moveCameraTo(_point ?? _fallbackCenter, zoom: 13);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<LatLng> _getBestLocation() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _status = 'A usar última localização conhecida';
        return LatLng(last.latitude, last.longitude);
      }
    } catch (_) {}

    _status = 'A usar localização atual';
    final current = await Geolocator
        .getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        )
        .timeout(const Duration(seconds: 8));
    return LatLng(current.latitude, current.longitude);
  }

  Future<void> _moveCameraTo(LatLng target, {double zoom = 15}) async {
    if (_controller == null) return;
    await _controller!.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: target, zoom: zoom),
    ));
  }

  void _onConfirm() {
    final p = _point;
    if (p == null) return;
    if (!context.mounted) return;
    Navigator.of(context).pop(PickLocationResult(p, _radius));
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _point != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher localização'),
        actions: [
          TextButton(
            onPressed: canSave ? _onConfirm : null,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (c) => _controller = c,
            initialCameraPosition: const CameraPosition(
              target: _fallbackCenter,
              zoom: 13,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onTap: (latLng) => setState(() => _point = latLng),
            markers: {
              if (_point != null)
                Marker(
                  markerId: const MarkerId('picked'),
                  position: _point!,
                  draggable: true,
                  onDragEnd: (p) => setState(() => _point = p),
                ),
            },
            circles: {
              if (_point != null)
                Circle(
                  circleId: const CircleId('radius'),
                  center: _point!,
                  radius: _radius,
                  strokeWidth: 2,
                  strokeColor: Colors.blueGrey.withOpacity(0.7),
                  fillColor: Colors.blueGrey.withOpacity(0.18),
                ),
            },
          ),

          // Slider de raio
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Raio: ${_radius.toStringAsFixed(0)} m'),
                      Slider(
                        min: 50,
                        max: 1000,
                        divisions: 19,
                        value: _radius.clamp(50, 1000),
                        onChanged: (v) => setState(() => _radius = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Banner de loading
          if (_loading)
            _Banner(child: Text('A obter localização… ${_status ?? ""}')),

          // Banner de GPS desligado
          if (_gpsOff)
            _ActionBanner(
              child: const Text('Localização desativada'),
              action: TextButton(
                onPressed: () => Geolocator.openLocationSettings(),
                child: const Text('Abrir definições'),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ensureAndCenter,
        tooltip: 'Ir para a minha posição',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Widget child;
  const _Banner({required this.child});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ActionBanner extends StatelessWidget {
  final Widget child;
  final Widget action;
  const _ActionBanner({required this.child, required this.action});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                child,
                const SizedBox(width: 8),
                action,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
