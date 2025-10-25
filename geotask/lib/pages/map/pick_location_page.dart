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
  static const _default = LatLng(38.7369, -9.1427); // fallback
  static const _panelHeight = 110.0;

  final _controller = Completer<GoogleMapController>();
  LatLng? _selected;
  double _radius = 150;

  @override
  void initState() {
    super.initState();
    _radius = widget.args.initialRadius;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.args.initialPoint != null) {
      setState(() => _selected = widget.args.initialPoint);
      return;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _selected = here);
      _moveCamera(here, 16);
    } catch (_) {
      setState(() => _selected = _default);
    }
  }

  Future<void> _moveCamera(LatLng target, [double? zoom]) async {
    if (!_controller.isCompleted) return;
    final c = await _controller.future;
    await c.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: target, zoom: zoom ?? 16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // padding do mapa para afastar os controlos do painel
    final mapPadding = EdgeInsets.only(
      bottom: _panelHeight + safeBottom + 16,
      right: 12,
      top: 12,
      left: 12,
    );

    final center = _selected ?? _default;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher localização'),
        actions: [
          TextButton(
            onPressed: _selected == null
                ? null
                : () =>
                    Navigator.pop(context, PickLocationResult(_selected!, _radius)),
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 15),
            onMapCreated: (c) {
              if (!_controller.isCompleted) _controller.complete(c);
            },
            padding: mapPadding, // <-- isto é o que afasta +/−/bússola
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // usamos o nosso botão
            zoomControlsEnabled: true,
            compassEnabled: true,
            onTap: (pos) => setState(() => _selected = pos),
            markers: {
              if (_selected != null)
                Marker(
                  markerId: const MarkerId('pick'),
                  position: _selected!,
                  draggable: true,
                  onDragEnd: (p) => setState(() => _selected = p),
                ),
            },
            circles: {
              if (_selected != null)
                Circle(
                  circleId: const CircleId('radius'),
                  center: _selected!,
                  radius: _radius,
                  strokeWidth: 2,
                  // evitar withOpacity (depreciado) -> usar withAlpha
                  strokeColor: cs.primary.withAlpha((0.45 * 255).round()),
                  fillColor: cs.primary.withAlpha((0.15 * 255).round()),
                ),
            },
          ),

          // Painel inferior (slider + "minha localização")
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.only(bottom: 12 - safeBottom < 0 ? 0 : 12),
              child: _BottomPanel(
                height: _panelHeight,
                radius: _radius,
                onRadiusChange: (v) => setState(() => _radius = v),
                onLocateMe: _centerOnUser,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _centerOnUser() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização negada')),
        );
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _selected = here);
      _moveCamera(here, 16);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível obter a localização')),
      );
    }
  }
}

class _BottomPanel extends StatelessWidget {
  final double height;
  final double radius;
  final ValueChanged<double> onRadiusChange;
  final VoidCallback onLocateMe;

  const _BottomPanel({
    required this.height,
    required this.radius,
    required this.onRadiusChange,
    required this.onLocateMe,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Raio: ${_fmt(radius)}',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: const SliderThemeData(trackHeight: 4),
                    child: Slider(
                      min: 50,
                      max: 1000,
                      divisions: 19, // passo de 50 m
                      value: radius.clamp(50, 1000),
                      onChanged: onRadiusChange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              width: 56,
              child: IconButton.filled(
                onPressed: onLocateMe,
                icon: const Icon(Icons.my_location),
                tooltip: 'Ir para a minha localização',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double r) {
    if (r >= 1000) return '${(r / 1000).toStringAsFixed(1)} km';
    return '${r.toStringAsFixed(0)} m';
  }
}
