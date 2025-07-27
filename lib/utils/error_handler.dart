/// 位置情報関連のエラーハンドリングユーティリティ
class LocationErrorHandler {
  /// エラーをログ出力し、再スローする
  static void handleError(String operation, dynamic error) {
    print('$operation でエラーが発生しました: $error');
  }

  /// 非同期操作のエラーをハンドリングして結果を返す
  static Future<T?> handleAsyncOperation<T>(
    String operation,
    Future<T> Function() operation_func,
  ) async {
    try {
      return await operation_func();
    } catch (e) {
      handleError(operation, e);
      return null;
    }
  }

  /// 非同期操作のエラーをハンドリングしてboolを返す
  static Future<bool> handleAsyncBoolOperation(
    String operation,
    Future<bool> Function() operation_func,
  ) async {
    try {
      return await operation_func();
    } catch (e) {
      handleError(operation, e);
      return false;
    }
  }

  /// 成功ログを出力
  static void logSuccess(String operation) {
    print('$operation が完了しました');
  }
} 