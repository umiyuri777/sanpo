import 'package:flutter/material.dart';

/// 位置情報関連のエラーハンドリングユーティリティ
class LocationErrorHandler {
  /// エラーをログ出力し、再スローする
  static void handleError(String operation, dynamic error) {
    debugPrint('$operation でエラーが発生しました: $error');
  }

  /// 非同期操作のエラーをハンドリングして結果を返す
  static Future<T?> handleAsyncOperation<T>(
    String operation,
    Future<T> Function() operationFunc,
  ) async {
    try {
      return await operationFunc();
    } catch (e) {
      handleError(operation, e);
      return null;
    }
  }

  /// 非同期操作のエラーをハンドリングしてboolを返す
  static Future<bool> handleAsyncBoolOperation(
    String operation,
    Future<bool> Function() operationFunc,
  ) async {
    try {
      return await operationFunc();
    } catch (e) {
      handleError(operation, e);
      return false;
    }
  }

  /// 成功ログを出力
  static void logSuccess(String operation) {
    debugPrint('$operation が完了しました');
  }
} 