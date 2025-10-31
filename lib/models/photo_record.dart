/// マップ上の写真埋め込み用データモデル
class PhotoRecord {
  final int? id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String imagePath; // 端末内に保存した画像ファイルのパス

  PhotoRecord({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'imagePath': imagePath,
    };
  }

  factory PhotoRecord.fromMap(Map<String, dynamic> map) {
    return PhotoRecord(
      id: map['id'] as int?,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      imagePath: map['imagePath'] as String,
    );
  }

  PhotoRecord copyWith({
    int? id,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    String? imagePath,
  }) {
    return PhotoRecord(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timestamp: timestamp ?? this.timestamp,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}


