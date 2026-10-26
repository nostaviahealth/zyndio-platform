import '../providers.dart';

enum HrvContext { nightly, daily, spotCheck, unknown }

class HrvReading {
  final String id;
  final BrandProvider source;
  final DateTime timestamp;
  final double? rmssd;
  final double? sdnn;
  final HrvContext context;
  final DateTime recordedAt;
  final DateTime syncedAt;
  final Map<String, dynamic>? rawData;

  HrvReading({
    required this.id,
    required this.source,
    required this.timestamp,
    this.rmssd,
    this.sdnn,
    required this.context,
    required this.recordedAt,
    required this.syncedAt,
    this.rawData,
  });

  factory HrvReading.fromMap(Map<String, dynamic> map) {
    return HrvReading(
      id: map['id'] as String,
      source: BrandProvider.values.firstWhere(
        (e) => e.name == map['source']['provider'],
        orElse: () => BrandProvider.healthKit,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      rmssd: (map['rmssd'] as num?)?.toDouble(),
      sdnn: (map['sdnn'] as num?)?.toDouble(),
      context: HrvContext.values.firstWhere(
        (e) => e.name == map['context'],
        orElse: () => HrvContext.unknown,
      ),
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
      'rmssd': rmssd,
      'sdnn': sdnn,
      'context': context.name,
      'recordedAt': recordedAt.millisecondsSinceEpoch,
    };
  }
}
