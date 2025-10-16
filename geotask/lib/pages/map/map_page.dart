import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../data/task_store.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = context.watch<TaskStore>().items;
    final withPoint = tasks.where((t) => t.point != null).toList();

    final markers = withPoint
        .map((t) => Marker(
              markerId: MarkerId(t.id),
              position: t.point!,
              infoWindow: InfoWindow(title: t.title),
            ))
        .toSet();

    // cor com alpha compatível em todas as versões
    final fill = const Color.fromRGBO(33, 150, 243, 0.15);

    final circles = withPoint
        .map((t) => Circle(
              circleId: CircleId('c-${t.id}'),
              center: t.point!,
              radius: t.radiusMeters,
              fillColor: fill,
              strokeColor: Colors.blueAccent,
              strokeWidth: 2,
            ))
        .toSet();

    final LatLng center =
        withPoint.isNotEmpty ? withPoint.first.point! : const LatLng(38.7369, -9.1427);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 13),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      markers: markers,
      circles: circles,
    );
  }
}
