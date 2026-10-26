import '../providers.dart';

enum SpO2Context { continuous, spotCheck, sleep }

class SpO2Reading {
  final String id;
  final BrandProvider source;
  final DateTime timestamp;
  final double percent;
  final SpO2Context context;
  final DateTime recordedAt;
  final DateTime syncedAt;
  final Map<String, dynamic>? rawData;

  SpO2Reading({
    required this.id,
    required this.source,
    required this.timestamp,
    required this.percent,
    required this.context,
    required this.recordedAt,
    required this.syncedAt,
    this.rawData,
  });

  factory SpO2Reading.fromMap(Map<String, dynamic> map) {
    return SpO2Reading(
      id: map['id'] as String,
      source: BrandProvider.values.firstWhere(
        (e) => e.name == map['source']['provider'],
        orElse: () => BrandProvider.healthKit,
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      percent: (map['percent'] as num).toDouble(),
      context: SpO2Context.values.firstWhere(
        (e) => e.name == map['context'],
        orElse: () => SpO2Context.spotCheck,
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
      'percent': percent,
      'context': context.name,
      'recordedAt': recordedAt.millisecondsSinceEpoch,
    };
  }
}
