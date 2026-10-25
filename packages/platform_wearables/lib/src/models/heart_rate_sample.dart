import '../providers.dart';

enum HeartRateContext { resting, active, sleep, workout, unknown }

class HeartRateSample {
  final String id;
  final BrandProvider source;
  final DateTime timestamp;
  final double bpm;
  final HeartRateContext context;
  final DateTime recordedAt;
  final DateTime syncedAt;
  final Map<String, dynamic>? rawData;

  HeartRateSample({
    required this.id,
    required this.source,
    required this.timestamp,
    required this.bpm,
    required this.context,
    required this.recordedAt,
    required this.syncedAt,
    this.rawData,
  });

  factory HeartRateSample.fromMap(Map<String, dynamic> map) {
    return HeartRateSample(
      id: map['id'] as String,
      source: BrandProvider.values.firstWhere(
        (e) => e.name == map['source']['provider'],
        orElse: () => BrandProvider.healthKit,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      bpm: (map['bpm'] as num).toDouble(),
      context: HeartRateContext.values.firstWhere(
        (e) => e.name == map['context'],
        orElse: () => HeartRateContext.unknown,
      ),
      recordedAt: map['recordedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['recordedAt'] as int)
          : DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      syncedAt: DateTime.now(),
      rawData: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': {'provider': source.name},
      'timestamp': timestamp.millisecondsSinceEpoch,
      'bpm': bpm,
      'context': context.name,
      'recordedAt': recordedAt.millisecondsSinceEpoch,
    };
  }
}
