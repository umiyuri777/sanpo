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
  bool _isLoading = true;

  Future<void> _requestLocationPermission() async {
    try {
      await RequestLocationPermission.request(location);
      // 方位センサーを有効化
      await location.enableBackgroundMode(enable: false);
      print('位置情報の権限を要求しました');
    } catch (e) {
      print('位置情報の権限要求でエラーが発生しました: $e');
    }
  }

  void _getLocation() {
    GetLocation.getPosition(location).then((value) {
      print('位置情報を取得しました: ${value.latitude}, ${value.longitude}');
      setState(() {
        _currentLocation =
            LatLng(value.latitude ?? 0.0, value.longitude ?? 0.0);
      });
    }).catchError((error) {
      print('位置情報の取得でエラーが発生しました: $error');
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      await _requestLocationPermission();
      await Future.delayed(const Duration(seconds: 1)); // 権限要求後の待機
      _getLocation();
    } catch (e) {
      print('位置情報の初期化でエラーが発生しました: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('散歩マップ'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('地図を読み込み中...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('散歩マップ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: FlutterMap(
        options: const MapOptions(
          // 名古屋駅の緯度経度です。
          initialCenter: LatLng(35.170694, 136.881637),
          initialZoom: 10.0,
          interactionOptions: InteractionOptions(
            // 拡大縮小と回転を分離
            rotationThreshold: 10.0, // 回転のための閾値を高く設定
            enableMultiFingerGestureRace: true, // 複数指ジェスチャーの競合を有効化
            rotationWinGestures: MultiFingerGesture.rotate, // 回転のみに設定
            pinchZoomWinGestures: MultiFingerGesture.pinchZoom, // ピンチズームのみに設定
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.sanpo',
          ),
          if (_currentLocation != null)
            const CurrentLocationLayer(),
        ],
      ),
    );
  }
}
