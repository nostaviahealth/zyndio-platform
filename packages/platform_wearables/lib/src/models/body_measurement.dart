import '../providers.dart';

class BodyMeasurement {
  final String id;
  final BrandProvider source;
  final double? weightKg;
  final double? bodyFatPercent;
  final double? muscleMassKg;
  final double? bmi;
  final double? bodyTemperatureCelsius;
  final DateTime recordedAt;
  final DateTime syncedAt;
  final Map<String, dynamic>? rawData;

  BodyMeasurement({
    required this.id,
    required this.source,
    this.weightKg,
    this.bodyFatPercent,
    this.muscleMassKg,
    this.bmi,
    this.bodyTemperatureCelsius,
    required this.recordedAt,
    required this.syncedAt,
    this.rawData,
  });

  factory BodyMeasurement.fromMap(Map<String, dynamic> map) {
    return BodyMeasurement(
      id: map['id'] as String,
      source: BrandProvider.values.firstWhere(
        (e) => e.name == map['source']['provider'],
        orElse: () => BrandProvider.healthKit,
      ),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      bodyFatPercent: (map['bodyFatPercent'] as num?)?.toDouble(),
      muscleMassKg: (map['muscleMassKg'] as num?)?.toDouble(),
      bmi: (map['bmi'] as num?)?.toDouble(),
      bodyTemperatureCelsius:
          (map['bodyTemperatureCelsius'] as num?)?.toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recordedAt'] as int),
      syncedAt: DateTime.now(),
      rawData: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': {'provider': source.name},
      'weightKg': weightKg,
      'bodyFatPercent': bodyFatPercent,
      'muscleMassKg': muscleMassKg,
      'bmi': bmi,
      'bodyTemperatureCelsius': bodyTemperatureCelsius,
      'recordedAt': recordedAt.millisecondsSinceEpoch,
    };
  }
}
