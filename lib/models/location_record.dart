/// 位置情報記録のデータモデル
class LocationRecord {
  final int? id;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final double? speedAccuracy;
  final double? heading;
  final DateTime timestamp;
  final bool isBackground;

  LocationRecord({
    this.id,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.speedAccuracy,
    this.heading,
    required this.timestamp,
    this.isBackground = false,
  });

  /// データベース用のMapに変換
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'speedAccuracy': speedAccuracy,
      'heading': heading,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isBackground': isBackground ? 1 : 0,
    };
  }

  /// MapからLocationRecordを作成
  factory LocationRecord.fromMap(Map<String, dynamic> map) {
    return LocationRecord(
      id: map['id'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      altitude: map['altitude'],
      accuracy: map['accuracy'],
      speed: map['speed'],
      speedAccuracy: map['speedAccuracy'],
      heading: map['heading'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      isBackground: map['isBackground'] == 1,
    );
  }

  /// JSON変換用
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'speedAccuracy': speedAccuracy,
      'heading': heading,
      'timestamp': timestamp.toIso8601String(),
      'isBackground': isBackground,
    };
  }

  /// JSONからLocationRecordを作成
  factory LocationRecord.fromJson(Map<String, dynamic> json) {
    return LocationRecord(
      id: json['id'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      altitude: json['altitude'],
      accuracy: json['accuracy'],
      speed: json['speed'],
      speedAccuracy: json['speedAccuracy'],
      heading: json['heading'],
      timestamp: DateTime.parse(json['timestamp']),
      isBackground: json['isBackground'] ?? false,
    );
  }

  @override
  String toString() {
    return 'LocationRecord(id: $id, lat: $latitude, lng: $longitude, time: $timestamp, bg: $isBackground)';
  }

  /// コピーを作成（idの更新などに使用）
  LocationRecord copyWith({
    int? id,
    double? latitude,
    double? longitude,
    double? altitude,
    double? accuracy,
    double? speed,
    double? speedAccuracy,
    double? heading,
    DateTime? timestamp,
    bool? isBackground,
  }) {
    return LocationRecord(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      speedAccuracy: speedAccuracy ?? this.speedAccuracy,
      heading: heading ?? this.heading,
      timestamp: timestamp ?? this.timestamp,
      isBackground: isBackground ?? this.isBackground,
    );
  }
} 