import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:sanpo/import.dart';
import 'package:sanpo/database/database_helper.dart';
import 'package:sanpo/models/location_record.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:location/location.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:sanpo/utils/location_data_provider.dart';

class MapView extends StatefulWidget {
  final DateTime? selectedDate;
  
  const MapView({super.key, this.selectedDate});

  @override
  State<MapView> createState() => _MapView();
}

class _MapView extends State<MapView> {
  LatLng? _currentLocation;
  final LocationService _locationService = LocationService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isLoading = true;
  final MapController _mapController = MapController();
  bool _isBackgroundServiceRunning = false;
  List<LocationRecord> _selectedDateLocations = [];
  List<LatLng> _routePoints = [];
  StreamSubscription<LocationData>? _locationSubscription;
  // compass is not used when relying on CurrentLocationLayer's default icon

  @override
  void initState() {
    super.initState();
    _initializeLocation().then((_) {
      _startForegroundLocationUpdates();
    });
    _isBackgroundServiceRunning = _locationService.isBackgroundServiceRunning;
    if (widget.selectedDate != null) {
      _loadSelectedDateLocations();
    }
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

  void _startForegroundLocationUpdates() async {
    try {
      await LocationDataProvider.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 2000,
        distanceFilter: 1.0,
      );

      _locationSubscription?.cancel();
      _locationSubscription = LocationDataProvider.location.onLocationChanged.listen(
        (LocationData data) {
          final double? lat = data.latitude;
          final double? lng = data.longitude;
          if (lat == null || lng == null) return;
          setState(() {
            _currentLocation = LatLng(lat, lng);
          });
        },
        onError: (error) {
          print('前景位置情報ストリームのエラー: $error');
        },
      );
    } catch (e) {
      print('前景位置情報ストリームの開始に失敗: $e');
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  /// 選択された日付の位置情報を読み込む
  Future<void> _loadSelectedDateLocations() async {
    if (widget.selectedDate == null) return;
    
    try {
      // 選択された日の開始時刻（00:00:00）
      final startOfDay = DateTime(
        widget.selectedDate!.year,
        widget.selectedDate!.month,
        widget.selectedDate!.day,
      );
      
      // 選択された日の終了時刻（23:59:59）
      final endOfDay = DateTime(
        widget.selectedDate!.year,
        widget.selectedDate!.month,
        widget.selectedDate!.day,
        23,
        59,
        59,
      );
      
      final locations = await _databaseHelper.getLocationRecordsByDateRange(
        startOfDay,
        endOfDay,
      );
      
      // 時系列順にソート（古い順）
      locations.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      setState(() {
        _selectedDateLocations = locations;
        _routePoints = locations
            .map((record) => LatLng(record.latitude, record.longitude))
            .toList();
      });
      
      // 位置情報がある場合は最初の地点に地図を移動
      if (_routePoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_routePoints.first, 15.0);
        });
      }
      
      print('${widget.selectedDate!.toString().split(' ')[0]}の位置情報を${locations.length}件読み込みました');
      
    } catch (e) {
      print('選択された日付の位置情報の読み込みでエラーが発生しました: $e');
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
        title: Text(widget.selectedDate != null 
          ? '散歩マップ - ${widget.selectedDate!.year}/${widget.selectedDate!.month}/${widget.selectedDate!.day}'
          : '散歩マップ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'デバッグ情報',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const DebugLocationsView()),
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
                pinchZoomWinGestures:
                    MultiFingerGesture.pinchZoom, // ピンチズームのみに設定
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sanpo',
              ),
              // 選択した日付の経路を表示
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.blue,
                      strokeWidth: 3.0,
                      borderStrokeWidth: 6.0,
                      borderColor: Colors.white,
                    ),
                  ],
                ),
              // 経路の開始点と終了点にマーカーを表示
              if (_routePoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    // 開始点（緑色）
                    Marker(
                      point: _routePoints.first,
                      width: 30.0,
                      height: 30.0,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    // 終了点（赤色）
                    if (_routePoints.length > 1)
                      Marker(
                        point: _routePoints.last,
                        width: 30.0,
                        height: 30.0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stop,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              if (_currentLocation != null)
                CurrentLocationLayer(
                  headingStream: FlutterCompass.events?.map((event) {
                    final double? headingDeg = event.heading;
                    final double? accuracyDeg = event.accuracy;
                    if (headingDeg == null) return null;
                    return LocationMarkerHeading(
                      heading: headingDeg * (math.pi / 180.0),
                      accuracy: (accuracyDeg ?? 45.0) * (math.pi / 180.0),
                    );
                  }),
                ),
            ],
          ),
          // 選択した日付の経路情報を表示
          if (widget.selectedDate != null)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.selectedDate!.year}/${widget.selectedDate!.month}/${widget.selectedDate!.day}の散歩記録',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_selectedDateLocations.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('記録点数: ${_selectedDateLocations.length}点'),
                        if (_selectedDateLocations.isNotEmpty)
                          Text(
                            '時間: ${_selectedDateLocations.first.timestamp.hour.toString().padLeft(2, '0')}:${_selectedDateLocations.first.timestamp.minute.toString().padLeft(2, '0')} - ${_selectedDateLocations.last.timestamp.hour.toString().padLeft(2, '0')}:${_selectedDateLocations.last.timestamp.minute.toString().padLeft(2, '0')}',
                          ),
                      ] else
                        const Text('この日の記録はありません'),
                    ],
                  ),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 50),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isBackgroundServiceRunning
                      ? Colors.red
                      : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                onPressed: () async {
                  if (_isBackgroundServiceRunning) {
                    final success =
                        await _locationService.stopBackgroundLocationService();
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('バックグラウンドサービスを停止しました')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('バックグラウンドサービスの停止に失敗しました')),
                      );
                    }
                  } else {
                    final success =
                        await _locationService.startBackgroundLocationService();
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('バックグラウンドサービスを開始しました')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('バックグラウンドサービスの開始に失敗しました')),
                      );
                    }
                  }
                  setState(() {
                    _isBackgroundServiceRunning =
                        _locationService.isBackgroundServiceRunning;
                  });
                },
                child: _isBackgroundServiceRunning
                    ? const Text('Stop')
                    : const Text('Start'),
              ),
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
