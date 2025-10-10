import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;

import '../models/task.dart';

class MapViewGoogle extends StatefulWidget {
  final ll.LatLng center;
  final ll.LatLng? current;
  final List<Task> tasks;
  final void Function(ll.LatLng point) onLongPressAdd;
  final ValueNotifier<ll.LatLng?>? focusRequest;

  const MapViewGoogle({
    super.key,
    required this.center,
    required this.current,
    required this.tasks,
    required this.onLongPressAdd,
    this.focusRequest,
  });

  @override
  State<MapViewGoogle> createState() => _MapViewGoogleState();
}

class _MapViewGoogleState extends State<MapViewGoogle> {
  gmaps.GoogleMapController? _controller;

  gmaps.LatLng _g(ll.LatLng p) => gmaps.LatLng(p.latitude, p.longitude);

  @override
  void initState() {
    super.initState();
    widget.focusRequest?.addListener(_onFocusRequested);
  }

  @override
  void didUpdateWidget(covariant MapViewGoogle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusRequest != widget.focusRequest) {
      oldWidget.focusRequest?.removeListener(_onFocusRequested);
      widget.focusRequest?.addListener(_onFocusRequested);
    }
  }

  @override
  void dispose() {
    widget.focusRequest?.removeListener(_onFocusRequested);
    super.dispose();
  }

  void _onFocusRequested() {
    final target = widget.focusRequest?.value;
    if (target != null && _controller != null) {
      _controller!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(_g(target), 17),
      );
      widget.focusRequest?.value = null; // limpa o pedido
    }
  }

  @override
  Widget build(BuildContext context) {
    final Set<gmaps.Circle> circles = widget.tasks
        .map((t) => gmaps.Circle(
              circleId: gmaps.CircleId(t.id),
              center: _g(t.point),
              radius: t.radiusMeters,
              strokeWidth: 1,
              strokeColor: Colors.white54,
              fillColor: Colors.white24,
            ))
        .toSet();

    final Set<gmaps.Marker> markers = widget.tasks
        .map((t) => gmaps.Marker(
              markerId: gmaps.MarkerId(t.id),
              position: _g(t.point),
              infoWindow: gmaps.InfoWindow(title: t.title),
            ))
        .toSet();

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: _g(widget.center),
        zoom: 15,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      onLongPress: (p) => widget.onLongPressAdd(ll.LatLng(p.latitude, p.longitude)),
      onMapCreated: (c) => _controller = c,
      circles: circles,
      markers: markers,
      minMaxZoomPreference: const gmaps.MinMaxZoomPreference(3, 20),
      compassEnabled: true,
      rotateGesturesEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }
}
