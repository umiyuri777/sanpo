import 'package:location/location.dart';
import 'package:sanpo/import.dart';
import 'package:sanpo/database/database_helper.dart';
import 'package:sanpo/models/location_record.dart';
import 'package:flutter/material.dart';

/// 位置情報サービスのシングルトンクラス
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final BackgroundLocationService _backgroundService = BackgroundLocationService.instance;
  
  /// Location インスタンスを取得
  Location get location => LocationDataProvider.location;

  /// バックグラウンドサービスの実行状態を取得
  bool get isBackgroundServiceRunning => _backgroundService.isRunning;

  /// 位置情報の権限を要求
  Future<void> requestLocationPermission() async {
    final success = await LocationPermissionManager.requestLocationPermission();
    if (!success) {
      throw Exception('位置情報の権限が取得できませんでした');
    }
  }

  /// バックグラウンド位置情報の権限を要求
  Future<bool> requestBackgroundLocationPermission() async {
    try {
      final hasPermission = await LocationPermissionManager.requestBackgroundLocationPermission();
      
      if (hasPermission) {
        debugPrint('バックグラウンド位置情報の権限が許可されました');
        return true;
      } else {
        debugPrint('バックグラウンド位置情報の権限が拒否されました');
        return false;
      }
    } catch (e) {
      debugPrint('バックグラウンド位置情報の権限要求でエラー: $e');
      return false;
    }
  }

  /// 現在の位置情報を取得
  Future<LocationData> getCurrentLocation() async {
    return await LocationDataProvider.getCurrentLocation();
  }

  /// 現在の位置情報を取得してデータベースに保存
  Future<LocationData> getCurrentLocationAndSave({bool isBackground = false}) async {
    try {
      final locationData = await getCurrentLocation();
      
      // LocationRecordに変換して保存
      final locationRecord = LocationRecord(
        latitude: locationData.latitude!,
        longitude: locationData.longitude!,
        altitude: locationData.altitude,
        accuracy: locationData.accuracy,
        speed: locationData.speed,
        speedAccuracy: locationData.speedAccuracy,
        heading: locationData.heading,
        timestamp: DateTime.now(),
        isBackground: isBackground,
      );

      await _databaseHelper.insertLocationRecord(locationRecord);
      
      return locationData;
    } catch (error) {
      debugPrint('位置情報の取得・保存でエラーが発生しました: $error');
      rethrow;
    }
  }

  /// 位置情報の初期化（権限要求 + 位置取得）
  /// [delayAfterPermission] 権限要求後の待機時間（ミリ秒）
  /// [saveToDatabase] データベースに保存するかどうか
  Future<LocationData> initializeAndGetLocation({
    int delayAfterPermission = 1000,
    bool saveToDatabase = true,
  }) async {
    try {
      await requestLocationPermission();
      
      if (delayAfterPermission > 0) {
        await Future.delayed(Duration(milliseconds: delayAfterPermission));
      }
      
      if (saveToDatabase) {
        return await getCurrentLocationAndSave();
      } else {
        return await getCurrentLocation();
      }
    } catch (e) {
      debugPrint('位置情報の初期化でエラーが発生しました: $e');
      rethrow;
    }
  }

  /// バックグラウンド位置情報サービスを開始
  Future<bool> startBackgroundLocationService() async {
    try {
      // バックグラウンド権限を確認・要求
      final hasPermission = await requestBackgroundLocationPermission();
      if (!hasPermission) {
        return false;
      }

      // バックグラウンドサービスを開始
      final success = await _backgroundService.startLocationService();
      
      if (success) {
        debugPrint('バックグラウンド位置情報サービスを開始しました');
      }
      
      return success;
    } catch (e) {
      debugPrint('バックグラウンド位置情報サービスの開始でエラー: $e');
      return false;
    }
  }

  /// バックグラウンド位置情報サービスを停止
  Future<bool> stopBackgroundLocationService() async {
    try {
      final success = await _backgroundService.stopLocationService();
      
      if (success) {
        debugPrint('バックグラウンド位置情報サービスを停止しました');
      }
      
      return success;
    } catch (e) {
      debugPrint('バックグラウンド位置情報サービスの停止でエラー: $e');
      return false;
    }
  }

  /// バックグラウンドサービスの実行状態を確認
  Future<bool> checkBackgroundServiceStatus() async {
    return _backgroundService.isRunning;
  }

  /// 保存された位置情報を全て取得
  Future<List<LocationRecord>> getAllLocationRecords() async {
    return await _databaseHelper.getAllLocationRecords();
  }

  /// 指定期間の位置情報を取得
  Future<List<LocationRecord>> getLocationRecordsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _databaseHelper.getLocationRecordsByDateRange(startDate, endDate);
  }

  /// バックグラウンドで取得した位置情報のみを取得
  Future<List<LocationRecord>> getBackgroundLocationRecords() async {
    return await _databaseHelper.getBackgroundLocationRecords();
  }

  /// 最新の位置情報を取得
  Future<LocationRecord?> getLatestLocationRecord() async {
    return await _databaseHelper.getLatestLocationRecord();
  }

  /// 保存されている位置情報の件数を取得
  Future<int> getLocationRecordCount() async {
    return await _databaseHelper.getLocationRecordCount();
  }

  /// 指定期間より古いデータを削除
  Future<int> deleteOldRecords(DateTime beforeDate) async {
    return await _databaseHelper.deleteOldRecords(beforeDate);
  }

  /// 全ての位置情報を削除
  Future<int> deleteAllLocationRecords() async {
    return await _databaseHelper.deleteAllLocationRecords();
  }

  /// サービスを破棄
  void dispose() {
    _backgroundService.dispose();
  }
} 