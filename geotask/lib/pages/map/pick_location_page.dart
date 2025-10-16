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
  GoogleMapController? _c;

  // Fallback: Covilhã
  LatLng _center = const LatLng(40.2795, -7.5060);

  LatLng? _point;
  double _radius = 150;

  bool _loading = true;
  bool _gpsOff = false;
  LocationPermission _permission = LocationPermission.denied;

  StreamSubscription<ServiceStatus>? _serviceSub;

  String? _status;   // texto de debug opcional
  String? _error;    // último erro de localização

  @override
  void initState() {
    super.initState();
    _point = widget.args.initialPoint;
    _radius = widget.args.initialRadius;

    // Reagir a ligar/desligar do GPS
    _serviceSub = Geolocator.getServiceStatusStream().listen((status) {
      _gpsOff = status != ServiceStatus.enabled;
      if (!_gpsOff) {
        _centerToMe();
      }
      if (mounted) setState(() {});
    });

    _bootstrap();
  }

  @override
  void dispose() {
    _serviceSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _checkServiceAndPermission();
    await _initCenter(); // primeiro centramento
  }

  Future<void> _checkServiceAndPermission() async {
    _gpsOff = !(await Geolocator.isLocationServiceEnabled());
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    setState(() => _permission = p);
  }

  /// Estratégia robusta: lastKnown → current (timeout) → stream (1ª leitura ou timeout)
  Future<LatLng?> _getMeRobust() async {
    if (_gpsOff) {
      _status = 'GPS OFF';
      return null;
    }

    if (_permission == LocationPermission.denied) {
      _status = 'Permission denied (requesting…)';
      _permission = await Geolocator.requestPermission();
    }
    if (_permission == LocationPermission.denied ||
        _permission == LocationPermission.deniedForever) {
      _status = 'Permission not granted';
      return null;
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _status = 'Using lastKnown';
        return LatLng(last.latitude, last.longitude);
      }
    } catch (e) {
      _error = 'lastKnown: $e';
    }

    try {
      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
        timeLimit: const Duration(seconds: 8),
      );
      _status = 'Using currentPosition';
      return LatLng(current.latitude, current.longitude);
    } catch (e) {
      _error = 'currentPosition: $e';
    }

    // Fallback final: ouvir stream até à 1ª leitura
    try {
      final completer = Completer<LatLng?>();
      final sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).listen((pos) {
        if (!completer.isCompleted) {
          completer.complete(LatLng(pos.latitude, pos.longitude));
        }
      });

      // timeout da stream
      Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) completer.complete(null);
      });

      final first = await completer.future;
      await sub.cancel();
      if (first != null) {
        _status = 'Using stream first fix';
        return first;
      }
    } catch (e) {
      _error = 'stream: $e';
    }

    _status = 'Falling back';
    return null;
  }

  Future<void> _initCenter() async {
    setState(() { _loading = true; _error = null; });
    final me = await _getMeRobust();
    setState(() {
      _center = widget.args.initialPoint ?? me ?? _center;
      _loading = false;
    });
  }

  Future<void> _centerToMe() async {
    final me = await _getMeRobust();
    if (me != null) {
      if (_c != null) {
        await _c!.animateCamera(CameraUpdate.newLatLng(me));
      }
      if (mounted) setState(() => _center = me);
    } else if (mounted && _error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível obter localização: $_error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fill = const Color.fromRGBO(99, 102, 241, 0.18);

    final needsPermission = _permission == LocationPermission.denied ||
        _permission == LocationPermission.deniedForever;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher local'),
        actions: [
          if (_point != null)
            TextButton(
              onPressed: () => setState(() => _point = null),
              child: const Text('Limpar'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _center, zoom: 14),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (c) {
                    _c = c;
                    _centerToMe(); // assim que o mapa está pronto, tenta recentrar
                  },
                  onTap: (latLng) {
                    setState(() => _point = latLng);
                    _c?.animateCamera(CameraUpdate.newLatLng(latLng));
                  },
                  markers: {
                    if (_point != null)
                      Marker(markerId: const MarkerId('sel'), position: _point!),
                  },
                  circles: {
                    if (_point != null)
                      Circle(
                        circleId: const CircleId('r'),
                        center: _point!,
                        radius: _radius,
                        fillColor: fill,
                        strokeColor: Colors.indigo,
                        strokeWidth: 2,
                      ),
                  },
                ),

                if (_loading)
                  _Banner(child: Text('A obter localização… ${_status ?? ""}')),

                if (_gpsOff)
                  _ActionBanner(
                    action: TextButton(
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                      },
                      child: const Text('Abrir definições'),
                    ),
                    child: const Text('O GPS está desligado'),
                  ),

                if (needsPermission && !_gpsOff)
                  _ActionBanner(
                    action: TextButton(
                      onPressed: () async {
                        final p = await Geolocator.requestPermission();
                        setState(() => _permission = p);
                        if (p == LocationPermission.deniedForever && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Concede a permissão em Definições > Apps > Permissões.'),
                            ),
                          );
                          await Geolocator.openAppSettings();
                        }
                        if (mounted) _centerToMe();
                      },
                      child: const Text('Conceder'),
                    ),
                    child: const Text('Permissão de localização necessária'),
                  ),

                // cartão de debug (opcional; remove se não quiseres)
                if (_error != null)
                  _Banner(
                    topPadding: 96,
                    child: Text(
                      'Erro: $_error\n${_status ?? ""}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: _radius,
                  min: 50,
                  max: 500,
                  divisions: 9,
                  label: '${_radius.round()} m',
                  onChanged: (_point == null) ? null : (v) => setState(() => _radius = v),
                ),
                Text('Raio: ${_radius.round()} m',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: (_point == null)
                      ? null
                      : () => Navigator.of(context)
                          .pop(PickLocationResult(_point!, _radius)),
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _centerToMe,
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Widget child;
  final double topPadding;
  const _Banner({required this.child, this.topPadding = 12});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding, left: 12, right: 12),
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
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 56),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              child,
              const SizedBox(width: 8),
              action,
            ]),
          ),
        ),
      ),
    );
  }
}
