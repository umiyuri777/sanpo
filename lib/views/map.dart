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
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:sanpo/models/photo_record.dart';

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

  // 写真関連
  final PopupController _popupController = PopupController();
  final Map<int, PhotoRecord> _photoById = {};
  List<PhotoRecord> _photoRecords = [];

  /// 安全にsetStateを実行するヘルパーメソッド
  /// ウィジェットがdisposeされている場合は何もしない
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  /// 位置情報が利用できない状態かどうかを判定
  bool get _isLocationUnavailable => widget.selectedDate == null && _currentLocation == null;

  @override
  void initState()  {
    super.initState();
    // 初期化を開始
    _initialize();

    // バックグラウンドサービスの実行状態を取得
    _isBackgroundServiceRunning = _locationService.isBackgroundServiceRunning;
  }

  /// 非同期で位置情報とデータベースを初期化する
  Future<void> _initialize() async {
    
    if (widget.selectedDate != null) {
      // 選択された日付がある場合（カレンダーから遷移）は位置情報の取得をスキップ
      await _loadSelectedDateLocations();
    } else {
      // 通常のマップ表示の場合：位置情報の初期化と更新の開始を並列実行
      await _initializeLocation();
      await _startForegroundLocationUpdates();
    }

    // 写真レコードを読み込み
    await _loadPhotoRecordsForCurrentView();

    _safeSetState(() {
      _isLoading = false;
    });
  }

  /// 位置情報の初期化
  Future<void> _initializeLocation() async {    
    try {
      final locationData = await _locationService.initializeAndGetLocation(
        delayAfterPermission: 1000,
      );
      _safeSetState(() {
        _currentLocation =
            LatLng(locationData.latitude ?? 0.0, locationData.longitude ?? 0.0);
      });
    } catch (e) {
      print('位置情報の初期化でエラーが発生しました: $e');
    }
  }

  /// 位置情報ストリームの開始
  Future<void> _startForegroundLocationUpdates() async {
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
          _safeSetState(() {
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
      
      // 時系列順（昇順：古い順）で取得
      final locations = await _databaseHelper.getLocationRecordsByDateRange(
        startOfDay,
        endOfDay,
      );
      
      _safeSetState(() {
        _selectedDateLocations = locations;
        _routePoints = locations
            .map((record) => LatLng(record.latitude, record.longitude))
            .toList();
      });
      // マップの初期表示は initialCenter に委ねる
      
      print('${widget.selectedDate!.toString().split(' ')[0]}の位置情報を${locations.length}件読み込みました');
      
    } catch (e) {
      print('選択された日付の位置情報の読み込みでエラーが発生しました: $e');
    }
  }

  /// 表示対象日の写真レコードを読み込む
  Future<void> _loadPhotoRecordsForCurrentView() async {
    try {
      final DateTime base = widget.selectedDate ?? DateTime.now();
      final DateTime start = DateTime(base.year, base.month, base.day);
      final DateTime end =
          DateTime(base.year, base.month, base.day, 23, 59, 59);
      final photos = await _databaseHelper.getPhotoRecordsByDateRange(start, end);
      _safeSetState(() {
        _photoRecords = photos;
        _photoById
          ..clear()
          ..addEntries(photos.where((e) => e.id != null).map((e) => MapEntry(e.id!, e)));
      });
    } catch (e) {
      print('写真の読み込みでエラーが発生しました: $e');
    }
  }

  /// ルート（_routePoints）の近くで長押しされたかどうか判定（しきい値: メートル）
  bool _isNearRoute(LatLng pressed, {double thresholdMeters = 50}) {
    if (_routePoints.isEmpty) return false;
    final distance = const Distance();
    double minDist = double.infinity;
    for (final p in _routePoints) {
      final d = distance(pressed, p);
      if (d < minDist) minDist = d;
      if (minDist <= thresholdMeters) return true;
    }
    return minDist <= thresholdMeters;
  }

  /// マップ長押しで写真を追加
  Future<void> _onMapLongPress(LatLng latLng) async {
    if (_routePoints.isEmpty || !_isNearRoute(latLng)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('線の近くを長押しすると写真を追加できます')),
        );
      }
      return;
    }

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('カメラで撮影'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('ライブラリから選択'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null) return;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'sanpo_photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path)}';
      final savePath = p.join(dir.path, fileName);
      await File(picked.path).copy(savePath);

      final record = PhotoRecord(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
        timestamp: DateTime.now(),
        imagePath: savePath,
      );
      final id = await _databaseHelper.insertPhotoRecord(record);
      final saved = record.copyWith(id: id);
      _safeSetState(() {
        _photoRecords.add(saved);
        if (saved.id != null) {
          _photoById[saved.id!] = saved;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真を保存しました')),
        );
      }
    } catch (e) {
      print('写真の保存に失敗: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('写真の保存に失敗しました')),
        );
      }
    }
  }

  List<Marker> _buildPhotoMarkers() {
    return _photoRecords
        .where((e) => e.id != null)
        .map((e) => Marker(
              key: ValueKey<int>(e.id!),
              point: LatLng(e.latitude, e.longitude),
              width: 16,
              height: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLocationUnavailable) {
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
          ? '${widget.selectedDate!.year}/${widget.selectedDate!.month}/${widget.selectedDate!.day}'
          : '散歩マップ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              // 初期中心: 通常は現在地、カレンダー表示時は経路の先頭、なければ名古屋駅
              initialCenter: widget.selectedDate == null
                  ? (_currentLocation ?? const LatLng(35.170694, 136.881637))
                  : (_routePoints.isNotEmpty
                      ? _routePoints.first
                      : const LatLng(35.170694, 136.881637)),
              initialZoom: 10.0,
              interactionOptions: const InteractionOptions(
                // 拡大縮小と回転を分離
                rotationThreshold: 10.0, // 回転のための閾値を高く設定
                enableMultiFingerGestureRace: true, // 複数指ジェスチャーの競合を有効化
                rotationWinGestures: MultiFingerGesture.rotate, // 回転のみに設定
                pinchZoomWinGestures:
                    MultiFingerGesture.pinchZoom, // ピンチズームのみに設定
              ),
              onLongPress: (tapPos, latLng) => _onMapLongPress(latLng),
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
              // 写真マーカー + ポップアップ
              if (_photoRecords.isNotEmpty)
                PopupMarkerLayerWidget(
                  options: PopupMarkerLayerOptions(
                    popupController: _popupController,
                    markers: _buildPhotoMarkers(),
                    popupDisplayOptions: PopupDisplayOptions(
                      builder: (ctx, marker) {
                        final key = marker.key;
                        int? id;
                        if (key is ValueKey<int>) id = key.value;
                        final rec = id != null ? _photoById[id] : null;
                        if (rec == null) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 220,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(rec.imagePath),
                                  width: 220,
                                  height: 160,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            CustomPaint(
                              size: const Size(20, 10),
                              painter: _TrianglePainter(color: Colors.white),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
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
          // カレンダーから遷移した場合は記録ボタンを非表示
          if (widget.selectedDate == null)
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
                      if (!mounted) return;
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
                      if (!mounted) return;
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
                    _safeSetState(() {
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
      // カレンダーから遷移した場合は現在地ボタンを非表示
      floatingActionButton: widget.selectedDate == null
          ? FloatingActionButton(
              onPressed: _currentLocation == null
                  ? null
                  : () {
                      final target = _currentLocation!;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _mapController.move(target, _mapController.camera.zoom);
                        }
                      });
                    },
              tooltip: '現在地に移動',
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }
}

/// ポップアップ下の三角形（吹き出しのしっぽ）
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
