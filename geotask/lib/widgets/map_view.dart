import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/task.dart';

class MapView extends StatelessWidget {
  final MapController controller;
  final LatLng center;
  final LatLng? current;
  final List<Task> tasks;
  final void Function(LatLng point) onLongPressAdd;

  const MapView({
    super.key,
    required this.controller,
    required this.center,
    required this.current,
    required this.tasks,
    required this.onLongPressAdd,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        onLongPress: (_, latlng) => onLongPressAdd(latlng),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.geotask',
        ),
        if (current != null)
          MarkerLayer(markers: [
            Marker(
              point: current!,
              width: 40,
              height: 40,
              child: const Icon(Icons.person_pin_circle, size: 40),
            ),
          ]),
        CircleLayer(circles: tasks.map((t) {
          return CircleMarker(
            point: t.point,
            radius: t.radiusMeters,
            useRadiusInMeter: true,
            color: Colors.white24,
            borderColor: Colors.white54,
            borderStrokeWidth: 1.5,
          );
        }).toList()),
        MarkerLayer(markers: tasks.map((t) {
          return Marker(
            point: t.point,
            width: 46,
            height: 46,
            child: Tooltip(
              message: t.title,
              child: const Icon(Icons.location_on, size: 40),
            ),
          );
        }).toList()),
      ],
    );
  }
}
