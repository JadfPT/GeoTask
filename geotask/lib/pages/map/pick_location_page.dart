import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../widgets/app_snackbar.dart';

/*
  Ficheiro: pick_location_page.dart
  Propósito: Página para seleccionar um ponto e raio no mapa (usada no formulário de tarefa).

  Resumo:
  - Permite ao utilizador tocar para escolher um ponto, ajustar o raio e guardar.
  - Tenta centrar na posição do utilizador quando possível.
  - Retorna um `PickLocationResult` com ponto e raio para a página chamadora.
*/

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
      showAppSnackBar(context, 'Seleciona um ponto no mapa.');
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
              // fallback: Covilhã (centro da cidade)
              target: _point ?? (_myPos ?? const LatLng(40.280572969058966, -7.5043608514295075)),
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
          // Use um controle do mesmo tamanho que o MapPage principal para manter a paridade visual.
          Positioned(
            right: 16,
            bottom: 110,
            child: SafeArea(
              top: false,
              child: IconButton.filled(
                onPressed: () {
                  if (_myPos != null) _moveCamera(_myPos!, zoom: 16);
                },
                icon: const Icon(Icons.my_location),
                style: IconButton.styleFrom(
                  minimumSize: const Size(56, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
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
