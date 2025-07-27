import 'dart:async';
import 'package:location/location.dart';
import 'package:sanpo/import.dart';
import 'package:sanpo/database/database_helper.dart';
import 'package:sanpo/models/location_record.dart';

/// locationプラグインを使用したバックグラウンド位置情報取得サービス
class BackgroundLocationService {
  static BackgroundLocationService? _instance;
  static BackgroundLocationService get instance {
    _instance ??= BackgroundLocationService._internal();
    return _instance!;
  }
  BackgroundLocationService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  StreamSubscription<LocationData>? _locationSubscription;
  bool _isRunning = false;

  /// バックグラウンドサービスの実行状態を取得
  bool get isRunning => _isRunning;

  /// バックグラウンド位置情報サービスを開始
  Future<bool> startLocationService() async {
    return await LocationErrorHandler.handleAsyncBoolOperation(
      'バックグラウンドサービス開始',
      () async {
        // 既に実行中の場合は停止
        if (_isRunning) {
          await stopLocationService();
        }

        // 位置情報権限を要求
        final hasPermission = await LocationPermissionManager.requestLocationPermission();
        if (!hasPermission) {
          return false;
        }

        // バックグラウンド権限を要求
        final hasBackgroundPermission = await LocationPermissionManager.requestBackgroundLocationPermission();
        if (!hasBackgroundPermission) {
          return false;
        }

        // 位置情報設定を変更
        await LocationDataProvider.changeSettings();

        // 位置情報の変更をリッスン
        _locationSubscription = LocationDataProvider.location.onLocationChanged.listen(
          (LocationData locationData) async {
            await _saveLocationData(locationData);
          },
          onError: (error) {
            LocationErrorHandler.handleError('位置情報リスナー', error);
          },
        );

        _isRunning = true;
        LocationErrorHandler.logSuccess('バックグラウンド位置情報サービス開始');
        return true;
      },
    );
  }

  /// バックグラウンド位置情報サービスを停止
  Future<bool> stopLocationService() async {
    return await LocationErrorHandler.handleAsyncBoolOperation(
      'バックグラウンドサービス停止',
      () async {
        // リスナーを停止
        await _locationSubscription?.cancel();
        _locationSubscription = null;

        // バックグラウンドモードを無効化
        await LocationDataProvider.enableBackgroundMode(false);

        _isRunning = false;
        LocationErrorHandler.logSuccess('バックグラウンド位置情報サービス停止');
        return true;
      },
    );
  }

  /// 位置情報データをデータベースに保存
  Future<void> _saveLocationData(LocationData locationData) async {
    try {
      if (locationData.latitude == null || locationData.longitude == null) {
        print('無効な位置情報データ: $locationData');
        return;
      }

      final locationRecord = LocationRecord(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        altitude: locationData.altitude,
        accuracy: locationData.accuracy,
        speed: locationData.speed,
        speedAccuracy: locationData.speedAccuracy,
        heading: locationData.heading,
        timestamp: DateTime.now(),
        isBackground: true,
      );

      await _databaseHelper.insertLocationRecord(locationRecord);
      print('バックグラウンド位置情報を保存: ${locationRecord.toString()}');
    } catch (e) {
      print('位置情報の保存でエラー: $e');
    }
  }

  /// 現在の位置情報を一度だけ取得
  Future<LocationData?> getCurrentLocation() async {
    return await LocationErrorHandler.handleAsyncOperation(
      '現在の位置情報取得',
      () => LocationDataProvider.getCurrentLocation(),
    );
  }

  /// サービスを完全に破棄
  void dispose() {
    stopLocationService();
    _instance = null;
  }
}