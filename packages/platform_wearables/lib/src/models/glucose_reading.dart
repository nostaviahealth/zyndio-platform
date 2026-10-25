import '../providers.dart';

enum GlucoseTrend { rising, risingQuickly, stable, falling, fallingQuickly }

class GlucoseReading {
  final String id;
  final BrandProvider source;
  final DateTime timestamp;
  final double valueMgDl;
  final GlucoseTrend? trend;
  final DateTime recordedAt;
  final DateTime syncedAt;
  final Map<String, dynamic>? rawData;

  GlucoseReading({
    required this.id,
    required this.source,
    required this.timestamp,
    required this.valueMgDl,
    this.trend,
    required this.recordedAt,
    required this.syncedAt,
    this.rawData,
  });

  factory GlucoseReading.fromMap(Map<String, dynamic> map) {
    return GlucoseReading(
      id: map['id'] as String,
      source: BrandProvider.values.firstWhere(
        (e) => e.name == map['source']['provider'],
        orElse: () => BrandProvider.healthKit,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      valueMgDl: (map['valueMgDl'] as num).toDouble(),
      trend: map['trend'] != null
          ? GlucoseTrend.values.firstWhere(
              (e) => e.name == map['trend'],
              orElse: () => GlucoseTrend.stable,
            )
          : null,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recordedAt'] as int),
      syncedAt: DateTime.now(),
      rawData: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': {'provider': source.name},
      'timestamp': timestamp.millisecondsSinceEpoch,
      'valueMgDl': valueMgDl,
      'trend': trend?.name,
      'recordedAt': recordedAt.millisecondsSinceEpoch,
    };
  }
}
