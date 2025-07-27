import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sanpo/import.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapView();
}

class _MapView extends State<MapView> {
  LatLng? _currentLocation;
  final LocationService _locationService = LocationService();
  bool _isLoading = true;
  final MapController _mapController = MapController();
  bool _isBackgroundServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _isBackgroundServiceRunning = _locationService.isBackgroundServiceRunning;
  }

  Future<void> _initializeLocation() async {
    try {
      final locationData = await _locationService.initializeAndGetLocation(
        delayAfterPermission: 1000,
      );
      setState(() {
        _currentLocation =
            LatLng(locationData.latitude ?? 0.0, locationData.longitude ?? 0.0);
      });
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'デバッグ情報',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DebugLocationsView()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
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
              if (_currentLocation != null) const CurrentLocationLayer(),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                if (_isBackgroundServiceRunning) {
                  final success = await _locationService.stopBackgroundLocationService();
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('バックグラウンドサービスを停止しました')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('バックグラウンドサービスの停止に失敗しました')),
                    );
                  }
                  setState(() {
                    _isBackgroundServiceRunning = success;
                  });
                } else {
                  final success = await _locationService.startBackgroundLocationService();
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('バックグラウンドサービスを開始しました')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('バックグラウンドサービスの開始に失敗しました')),
                    );
                  }
                  setState(() {
                    _isBackgroundServiceRunning = success;
                  });
                }
              },
              child: _isBackgroundServiceRunning
                  ? const Text('バックグラウンドサービスを停止')
                  : const Text('バックグラウンドサービスを開始'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _currentLocation == null
            ? null
            : () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapController.move(
                      _currentLocation!, _mapController.camera.zoom);
                });
              },
        child: const Icon(Icons.my_location),
        tooltip: '現在地に移動',
      ),
    );
  }
}
