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
  const PickLocationResult({required this.point, required this.radius});
}

class PickLocationPage extends StatefulWidget {
  final LatLng? initialPoint;
  final double initialRadius;

  const PickLocationPage({
    super.key,
    this.initialPoint,
    this.initialRadius = 150,
  });

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  GoogleMapController? _controller;
  LatLng? _point;
  double _radius = 150;
  LatLng? _myPos;

  @override
  void initState() {
    super.initState();
    _point = widget.initialPoint;
    _radius = widget.initialRadius;
    _ensureLocation();
  }

  Future<void> _ensureLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    setState(() => _myPos = LatLng(pos.latitude, pos.longitude));

    // se não houver ponto inicial, foca na posição
    if (_point == null) {
      _point = _myPos;
      _moveCamera(_point!, zoom: 16);
    } else {
      _moveCamera(_point!, zoom: 16);
    }
  }

  Future<void> _moveCamera(LatLng target, {double zoom = 15}) async {
    final c = _controller;
    if (c == null) return;
    await c.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: target, zoom: zoom),
    ));
  }

  void _onTap(LatLng p) => setState(() => _point = p);

  void _save() {
    if (_point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleciona um ponto no mapa.')),
      );
      return;
    }
    Navigator.pop(context, PickLocationResult(point: _point!, radius: _radius));
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    final circles = <Circle>{};

    if (_point != null) {
      markers.add(Marker(markerId: const MarkerId('p'), position: _point!));
      circles.add(Circle(
        circleId: const CircleId('r'),
        center: _point!,
        radius: _radius,
        strokeColor: Theme.of(context).colorScheme.primary,
        strokeWidth: 2,
        fillColor: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher localização'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _point ?? (_myPos ?? const LatLng(38.7223, -9.1393)), // fallback: Lisboa
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onTap: _onTap,
            onMapCreated: (c) => _controller = c,
            markers: markers,
            circles: circles,
          ),

          // Botões flutuantes alinhados com o +/-
          Positioned(
            right: 16,
            bottom: 110,
            child: FloatingActionButton.extended(
              onPressed: () {
                if (_myPos != null) _moveCamera(_myPos!, zoom: 16);
              },
              icon: const Icon(Icons.my_location_outlined),
              label: const Text(''),
              heroTag: 'myLoc',
            ),
          ),

          // Slider do raio (acima da barra do sistema)
          Positioned(
            left: 12,
            right: 12,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: .92),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                    color: Colors.black.withValues(alpha: .25),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Raio: ${_radius.toStringAsFixed(0)} m'),
                  Slider(
                    value: _radius,
                    min: 25,
                    max: 1000,
                    divisions: 39,
                    onChanged: (v) => setState(() => _radius = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
