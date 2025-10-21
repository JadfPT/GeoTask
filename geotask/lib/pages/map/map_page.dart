import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _controller = Completer<GoogleMapController>();
  late Future<CameraPosition> _initialCamera;

  static const _fallback = CameraPosition(
    target: LatLng(40.2795, -7.5060), // fallback temporário (não será mostrado se obtivermos localização)
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _initialCamera = _computeInitialCamera();
  }

  Future<CameraPosition> _computeInitialCamera() async {
    // serviços e permissões
    final servicesOn = await Geolocator.isLocationServiceEnabled();
    if (!servicesOn) return _fallback;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return _fallback;
    }

    // 1) lastKnown para não “piscar” Lisboa
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) {
      return CameraPosition(
        target: LatLng(last.latitude, last.longitude),
        zoom: 16,
      );
    }

    // 2) currentPosition com timeout
    try {
      final cur = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return CameraPosition(
        target: LatLng(cur.latitude, cur.longitude),
        zoom: 16,
      );
    } catch (_) {
      return _fallback;
    }
  }

  Future<void> _refineToCurrent() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final c = await _controller.future;
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pos.latitude, pos.longitude), zoom: 16),
        ),
      );
    } catch (_) {
      // silencioso; fica como está
    }
  }

  Future<void> _centerToMe() async => _refineToCurrent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa • debug')),
      body: FutureBuilder<CameraPosition>(
        future: _initialCamera,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: snap.data!,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                compassEnabled: true,
                onMapCreated: (ctrl) async {
                  if (!_controller.isCompleted) _controller.complete(ctrl);
                  // pequeno atraso para garantir que o mapa terminou o 1º frame
                  await Future.delayed(const Duration(milliseconds: 150));
                  await _refineToCurrent();
                },
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerToMe,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
