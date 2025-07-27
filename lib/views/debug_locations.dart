import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sanpo/database/database_helper.dart';
import 'package:sanpo/models/location_record.dart';

class DebugLocationsView extends StatefulWidget {
  const DebugLocationsView({super.key});

  @override
  State<DebugLocationsView> createState() => _DebugLocationsViewState();
}

class _DebugLocationsViewState extends State<DebugLocationsView> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<LocationRecord> _locationRecords = [];
  bool _isLoading = true;
  bool _showBackgroundOnly = false;
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd HH:mm:ss');

  @override
  void initState() {
    super.initState();
    _loadLocationRecords();
  }

  /// 位置情報データを読み込み
  Future<void> _loadLocationRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<LocationRecord> records;
      if (_showBackgroundOnly) {
        records = await _databaseHelper.getBackgroundLocationRecords();
      } else {
        records = await _databaseHelper.getAllLocationRecords();
      }

      setState(() {
        _locationRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの読み込みでエラー: $e')),
      );
    }
  }

  /// 全データを削除
  Future<void> _deleteAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: const Text('全ての位置情報データを削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _databaseHelper.deleteAllLocationRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('全てのデータを削除しました')),
        );
        _loadLocationRecords();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除でエラー: $e')),
        );
      }
    }
  }

  /// 個別のレコードを削除
  Future<void> _deleteRecord(LocationRecord record) async {
    try {
      await _databaseHelper.deleteLocationRecord(record.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データを削除しました')),
      );
      _loadLocationRecords();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除でエラー: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('位置情報デバッグ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _loadLocationRecords();
                  break;
                case 'delete_all':
                  _deleteAllRecords();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('更新'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('全削除', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // フィルター切り替え
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('表示フィルター: '),
                Switch(
                  value: _showBackgroundOnly,
                  onChanged: (value) {
                    setState(() {
                      _showBackgroundOnly = value;
                    });
                    _loadLocationRecords();
                  },
                ),
                Text(_showBackgroundOnly ? 'バックグラウンドのみ' : '全て'),
              ],
            ),
          ),
          // 統計情報
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          '${_locationRecords.length}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text('総レコード数'),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${_locationRecords.where((r) => r.isBackground).length}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text('バックグラウンド'),
                      ],
                    ),
                    Column(
                      children: [
                        Text(
                          '${_locationRecords.where((r) => !r.isBackground).length}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const Text('フォアグラウンド'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // データリスト
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _locationRecords.isEmpty
                    ? const Center(
                        child: Text(
                          '位置情報データがありません',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _locationRecords.length,
                        itemBuilder: (context, index) {
                          final record = _locationRecords[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: record.isBackground
                                    ? Colors.blue
                                    : Colors.green,
                                child: Text(
                                  record.isBackground ? 'BG' : 'FG',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                '${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_dateFormat.format(record.timestamp)),
                                  if (record.accuracy != null)
                                    Text('精度: ${record.accuracy!.toStringAsFixed(1)}m'),
                                  if (record.speed != null && record.speed! > 0)
                                    Text('速度: ${(record.speed! * 3.6).toStringAsFixed(1)}km/h'),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteRecord(record),
                              ),
                              onTap: () => _showRecordDetails(record),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// レコード詳細を表示
  void _showRecordDetails(LocationRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('位置情報詳細 (ID: ${record.id})'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _DetailRow('緯度', record.latitude.toStringAsFixed(8)),
              _DetailRow('経度', record.longitude.toStringAsFixed(8)),
              _DetailRow('記録時刻', _dateFormat.format(record.timestamp)),
              _DetailRow('取得方法', record.isBackground ? 'バックグラウンド' : 'フォアグラウンド'),
              if (record.altitude != null)
                _DetailRow('高度', '${record.altitude!.toStringAsFixed(1)}m'),
              if (record.accuracy != null)
                _DetailRow('精度', '${record.accuracy!.toStringAsFixed(1)}m'),
              if (record.speed != null)
                _DetailRow('速度', '${(record.speed! * 3.6).toStringAsFixed(1)}km/h'),
              if (record.speedAccuracy != null)
                _DetailRow('速度精度', '${record.speedAccuracy!.toStringAsFixed(1)}m/s'),
              if (record.heading != null)
                _DetailRow('方角', '${record.heading!.toStringAsFixed(1)}°'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteRecord(record);
            },
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// 詳細情報の行ウィジェット
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
} 