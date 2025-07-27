import 'package:location/location.dart';

/// 位置情報取得の基本ロジックを提供するクラス
class LocationDataProvider {
  static final Location _location = Location();

  /// Locationインスタンスを取得
  static Location get location => _location;

  /// 現在の位置情報を取得
  static Future<LocationData> getCurrentLocation() async {
    try {
      final locationData = await _location.getLocation();
      print('位置情報を取得: ${locationData.latitude}, ${locationData.longitude}');
      return locationData;
    } catch (e) {
      print('位置情報取得エラー: $e');
      rethrow;
    }
  }

  /// 位置情報設定を変更
  static Future<void> changeSettings({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int interval = 30000, // 30秒間隔
    double distanceFilter = 10.0, // 10m移動したら更新
  }) async {
    try {
      await _location.changeSettings(
        accuracy: accuracy,
        interval: interval,
        distanceFilter: distanceFilter,
      );
    } catch (e) {
      print('位置情報設定変更エラー: $e');
      rethrow;
    }
  }

  /// バックグラウンドモードの有効/無効切り替え
  static Future<void> enableBackgroundMode(bool enable) async {
    try {
      await _location.enableBackgroundMode(enable: enable);
    } catch (e) {
      print('バックグラウンドモード設定エラー: $e');
      rethrow;
    }
  }
} 