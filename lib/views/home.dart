import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:sanpo/import.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key, required this.title});

  final String title;

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  LocationData? _currentLocation;
  final LocationService _locationService = LocationService();
  bool _isBackgroundServiceRunning = false;
  int _savedLocationCount = 0;

  @override
  void initState() {
    super.initState();
    _checkBackgroundServiceStatus();
    _updateLocationCount();
  }

  /// バックグラウンドサービスの状態を確認
  Future<void> _checkBackgroundServiceStatus() async {
    final isRunning = await _locationService.checkBackgroundServiceStatus();
    setState(() {
      _isBackgroundServiceRunning = isRunning;
    });
  }

  /// 保存された位置情報の件数を更新
  Future<void> _updateLocationCount() async {
    final count = await _locationService.getLocationRecordCount();
    setState(() {
      _savedLocationCount = count;
    });
  }

  void _requestLocationPermission() async {
    try {
      await _locationService.requestLocationPermission();
    } catch (e) {
      debugPrint('権限要求エラー: $e');
    }
  }

  void _getLocation() {
    _locationService.getCurrentLocationAndSave()
        .then((value) {
          setState(() => _currentLocation = value);
          _updateLocationCount(); // 件数を更新
        })
        .catchError((error) {
          debugPrint('位置情報取得エラー: $error');
          return null;
        });
  }

  /// バックグラウンド位置情報サービスを開始
  Future<void> _startBackgroundService() async {
    try {
      final success = await _locationService.startBackgroundLocationService();
      setState(() {
        _isBackgroundServiceRunning = success;
      });
      
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('バックグラウンド位置情報サービスを開始しました')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('バックグラウンドサービスの開始に失敗しました')),
        );
      }
    } catch (e) {
      debugPrint('バックグラウンドサービス開始エラー: $e');
    }
  }

  /// バックグラウンド位置情報サービスを停止
  Future<void> _stopBackgroundService() async {
    try {
      final success = await _locationService.stopBackgroundLocationService();
      setState(() {
        _isBackgroundServiceRunning = !success;
      });
      
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('バックグラウンド位置情報サービスを停止しました')),
        );
      }
    } catch (e) {
      debugPrint('バックグラウンドサービス停止エラー: $e');
    }
  }

  /// 保存された位置情報を表示
  Future<void> _showSavedLocations() async {
    try {
      final locations = await _locationService.getAllLocationRecords();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('保存された位置情報 (${locations.length}件)'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: locations.length,
              itemBuilder: (context, index) {
                final location = locations[index];
                return ListTile(
                  title: Text('緯度: ${location.latitude.toStringAsFixed(6)}'),
                  subtitle: Text(
                    '経度: ${location.longitude.toStringAsFixed(6)}\n'
                    '時刻: ${location.timestamp.toString().substring(0, 19)}\n'
                    '${location.isBackground ? 'バックグラウンド' : 'フォアグラウンド'}',
                  ),
                  dense: true,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('位置情報表示エラー: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        centerTitle: true,
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
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 現在の位置情報表示
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  '$_currentLocation',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              
              // 位置情報操作ボタン
              OverflowBar(
                alignment: MainAxisAlignment.center,
                spacing: 10,
                children: [
                  SizedBox(
                    height: 50,
                    width: 105,
                    child: ElevatedButton(
                      onPressed: _requestLocationPermission,
                      child: const Text('request'),
                    ),
                  ),
                  SizedBox(
                    height: 50,
                    width: 105,
                    child: ElevatedButton(
                      onPressed: _getLocation,
                      child: const Text('get'),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // バックグラウンドサービス状態表示
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'バックグラウンドサービス',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isBackgroundServiceRunning ? '実行中' : '停止中',
                        style: TextStyle(
                          color: _isBackgroundServiceRunning ? Colors.green : Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _isBackgroundServiceRunning ? null : _startBackgroundService,
                            child: const Text('開始'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _isBackgroundServiceRunning ? _stopBackgroundService : null,
                            child: const Text('停止'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // 保存された位置情報の件数とボタン
              Card(
                margin: const EdgeInsets.all(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        '保存された位置情報',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$_savedLocationCount件',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _showSavedLocations,
                            child: const Text('履歴表示'),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: _updateLocationCount,
                            child: const Text('更新'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}