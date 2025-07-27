import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sanpo/models/location_record.dart';

/// SQLiteデータベースのヘルパークラス
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  /// データベースインスタンスを取得
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// データベースを初期化
  Future<Database> _initDatabase() async {
    final Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, 'sanpo_locations.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// テーブルを作成
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE location_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        accuracy REAL,
        speed REAL,
        speedAccuracy REAL,
        heading REAL,
        timestamp INTEGER NOT NULL,
        isBackground INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // インデックスを作成（検索性能向上のため）
    await db.execute('CREATE INDEX idx_timestamp ON location_records(timestamp)');
    await db.execute('CREATE INDEX idx_background ON location_records(isBackground)');
  }

  /// 位置情報を保存
  Future<int> insertLocationRecord(LocationRecord record) async {
    final db = await database;
    try {
      final id = await db.insert('location_records', record.toMap());
      print('位置情報を保存しました: ID=$id, ${record.toString()}');
      return id;
    } catch (e) {
      print('位置情報の保存でエラーが発生しました: $e');
      rethrow;
    }
  }

  /// 複数の位置情報を一括保存
  Future<void> insertLocationRecords(List<LocationRecord> records) async {
    final db = await database;
    final batch = db.batch();
    
    for (final record in records) {
      batch.insert('location_records', record.toMap());
    }
    
    try {
      await batch.commit();
      print('${records.length}件の位置情報を一括保存しました');
    } catch (e) {
      print('位置情報の一括保存でエラーが発生しました: $e');
      rethrow;
    }
  }

  /// 全ての位置情報を取得
  Future<List<LocationRecord>> getAllLocationRecords() async {
    final db = await database;
    final maps = await db.query(
      'location_records',
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => LocationRecord.fromMap(map)).toList();
  }

  /// 指定期間の位置情報を取得
  Future<List<LocationRecord>> getLocationRecordsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'location_records',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => LocationRecord.fromMap(map)).toList();
  }

  /// バックグラウンド取得の位置情報のみを取得
  Future<List<LocationRecord>> getBackgroundLocationRecords() async {
    final db = await database;
    final maps = await db.query(
      'location_records',
      where: 'isBackground = ?',
      whereArgs: [1],
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => LocationRecord.fromMap(map)).toList();
  }

  /// 最新の位置情報を取得
  Future<LocationRecord?> getLatestLocationRecord() async {
    final db = await database;
    final maps = await db.query(
      'location_records',
      orderBy: 'timestamp DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return LocationRecord.fromMap(maps.first);
    }
    return null;
  }

  /// 位置情報を更新
  Future<int> updateLocationRecord(LocationRecord record) async {
    final db = await database;
    return await db.update(
      'location_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// 位置情報を削除
  Future<int> deleteLocationRecord(int id) async {
    final db = await database;
    return await db.delete(
      'location_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 指定期間より古いデータを削除
  Future<int> deleteOldRecords(DateTime beforeDate) async {
    final db = await database;
    return await db.delete(
      'location_records',
      where: 'timestamp < ?',
      whereArgs: [beforeDate.millisecondsSinceEpoch],
    );
  }

  /// 全ての位置情報を削除
  Future<int> deleteAllLocationRecords() async {
    final db = await database;
    return await db.delete('location_records');
  }

  /// データベースを閉じる
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// 保存されている位置情報の件数を取得
  Future<int> getLocationRecordCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM location_records')
    );
    return count ?? 0;
  }
} 