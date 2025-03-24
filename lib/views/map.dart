import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sanpo/import.dart';
import 'package:location/location.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapView();
}

class _MapView extends State<MapView> {
  LatLng? _currentLocation;
  final location = Location();

  Future<void> _requestLocationPermission() async {
    await RequestLocationPermission.request(location);
  }

  void _getLocation() {
    GetLocation.getPosition(location).then((value) => setState(() =>
        _currentLocation =
            LatLng(value.latitude ?? 0.0, value.longitude ?? 0.0)));
  }

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _getLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        options: const MapOptions(
          // 名古屋駅の緯度経度です。
          initialCenter:
              LatLng(35.170694, 136.881637),
          initialZoom: 10.0,
          interactionOptions: InteractionOptions(
            rotationWinGestures: MultiFingerGesture.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          const CurrentLocationLayer(), 
        ],
      ),
    );
  }
}
