import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart' as ll;

import '../models/task.dart';

class MapViewGoogle extends StatefulWidget {
  final ll.LatLng center;
  final ll.LatLng? current;
  final List<Task> tasks;
  final void Function(ll.LatLng point) onLongPressAdd;

  const MapViewGoogle({
    super.key,
    required this.center,
    required this.current,
    required this.tasks,
    required this.onLongPressAdd,
  });

  @override
  State<MapViewGoogle> createState() => _MapViewGoogleState();
}

class _MapViewGoogleState extends State<MapViewGoogle> {
  gm.GoogleMapController? _c;

  gm.LatLng _g(ll.LatLng p) => gm.LatLng(p.latitude, p.longitude);

  Set<gm.Marker> get _markers => widget.tasks
      .map((t) => gm.Marker(
            markerId: gm.MarkerId('t-${t.id}'),
            position: _g(t.point),
            infoWindow: gm.InfoWindow(title: t.title),
          ))
      .toSet();

  Set<gm.Circle> get _circles => widget.tasks
      .map((t) => gm.Circle(
            circleId: gm.CircleId('c-${t.id}'),
            center: _g(t.point),
            radius: t.radiusMeters.toDouble(),
            strokeWidth: 1,
            strokeColor: Colors.white54,
            fillColor: Colors.white24,
          ))
      .toSet();

  @override
  void didUpdateWidget(covariant MapViewGoogle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // se a posição atual mudou, podes recentrar (opcional)
    if (_c != null &&
        widget.current != null &&
        widget.current != oldWidget.current) {
      _c!.animateCamera(
        gm.CameraUpdate.newLatLng(_g(widget.current!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(
        target: _g(widget.center),
        zoom: 15,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      mapToolbarEnabled: false,
      compassEnabled: true,
      markers: _markers,
      circles: _circles,
      onMapCreated: (c) => _c = c,
      onLongPress: (pos) =>
          widget.onLongPressAdd(ll.LatLng(pos.latitude, pos.longitude)),
    );
  }
}
