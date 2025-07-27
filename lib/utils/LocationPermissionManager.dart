import 'dart:async';
import 'package:location/location.dart';

/// 位置情報権限管理クラス（locationプラグイン用）
class LocationPermissionManager {
  static final Location _location = Location();

  /// 位置情報権限を要求
  static Future<bool> requestLocationPermission() async {
    try {
      // サービス確認
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          print('位置情報サービスが無効です');
          return false;
        }
      }

      // 権限確認
      PermissionStatus permissionGranted = await _location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          print('位置情報の権限が拒否されました');
          return false;
        }
      }

      print('位置情報の権限が許可されました');
      return true;
    } catch (e) {
      print('位置情報権限要求エラー: $e');
      return false;
    }
  }

  /// バックグラウンド位置情報権限を要求（Androidの場合）
  static Future<bool> requestBackgroundLocationPermission() async {
    try {
      // まず通常の位置情報権限を取得
      final hasBasicPermission = await requestLocationPermission();
      if (!hasBasicPermission) {
        return false;
      }

      // Android 10以上の場合、バックグラウンド位置情報の権限が別途必要
      // locationプラグインではenableBackgroundModeで処理される
      await _location.enableBackgroundMode(enable: true);
      
      print('バックグラウンド位置情報の設定が完了しました');
      return true;
    } catch (e) {
      print('バックグラウンド位置情報権限要求エラー: $e');
      return false;
    }
  }

  /// 位置情報サービスが有効かどうか確認
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await _location.serviceEnabled();
    } catch (e) {
      print('位置情報サービス状態確認エラー: $e');
      return false;
    }
  }
} 