import '../providers.dart';

enum WorkoutType { run, cycle, swim, strength, yoga, hiit, walk, hike, other }

class WorkoutSession {
  final String id;
  final BrandProvider source;
  final WorkoutType type;
  final DateTime startTime;
  final DateTime endTime;
  final int durationSec;
  final double? caloriesBurned;
  final double? distanceMeters;
  final double? avgHeartRate;
  final double? maxHeartRate;
  final DateTime recordedAt;
  final DateTime syncedAt;
  final Map<String, dynamic>? rawData;

  WorkoutSession({
    required this.id,
    required this.source,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.durationSec,
    this.caloriesBurned,
    this.distanceMeters,
    this.avgHeartRate,
    this.maxHeartRate,
    required this.recordedAt,
    required this.syncedAt,
    this.rawData,
  });

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as String,
      source: BrandProvider.values.firstWhere(
        (e) => e.name == map['source']['provider'],
        orElse: () => BrandProvider.healthKit,
      ),
      type: WorkoutType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => WorkoutType.other,
      ),
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
      durationSec: map['durationSec'] as int,
      caloriesBurned: (map['caloriesBurned'] as num?)?.toDouble(),
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble(),
      avgHeartRate: (map['avgHeartRate'] as num?)?.toDouble(),
      maxHeartRate: (map['maxHeartRate'] as num?)?.toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recordedAt'] as int),
      syncedAt: DateTime.now(),
      rawData: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': {'provider': source.name},
      'type': type.name,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime.millisecondsSinceEpoch,
      'durationSec': durationSec,
      'caloriesBurned': caloriesBurned,
      'distanceMeters': distanceMeters,
      'avgHeartRate': avgHeartRate,
      'maxHeartRate': maxHeartRate,
      'recordedAt': recordedAt.millisecondsSinceEpoch,
    };
  }
}
