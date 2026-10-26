import '../providers.dart';

class ActivitySummary {
  final String id;
  final BrandProvider source;
  final DateTime date;
  final int steps;
  final double distanceMeters;
  final double caloriesTotal;
  final double caloriesActive;
  final int activeMinutes;
  final int sedentaryMinutes;
  final int floorsClimbed;
  final DateTime recordedAt;
  final DateTime syncedAt;
  final Map<String, dynamic>? rawData;

  ActivitySummary({
    required this.id,
    required this.source,
    required this.date,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesTotal,
    required this.caloriesActive,
    required this.activeMinutes,
    required this.sedentaryMinutes,
    required this.floorsClimbed,
    required this.recordedAt,
    required this.syncedAt,
    this.rawData,
  });

  factory ActivitySummary.fromMap(Map<String, dynamic> map) {
    return ActivitySummary(
      id: map['id'] as String,
      source: BrandProvider.values.firstWhere(
        (e) => e.name == map['source']['provider'],
        orElse: () => BrandProvider.healthKit,
      ),
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      steps: map['steps'] as int,
      distanceMeters: (map['distanceMeters'] as num).toDouble(),
      caloriesTotal: (map['caloriesTotal'] as num).toDouble(),
      caloriesActive: (map['caloriesActive'] as num).toDouble(),
      activeMinutes: map['activeMinutes'] as int,
      sedentaryMinutes: map['sedentaryMinutes'] as int,
      floorsClimbed: map['floorsClimbed'] as int,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recordedAt'] as int),
      syncedAt: DateTime.now(),
      rawData: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': {'provider': source.name},
      'date': date.millisecondsSinceEpoch,
      'steps': steps,
      'distanceMeters': distanceMeters,
      'caloriesTotal': caloriesTotal,
      'caloriesActive': caloriesActive,
      'activeMinutes': activeMinutes,
      'sedentaryMinutes': sedentaryMinutes,
      'floorsClimbed': floorsClimbed,
      'recordedAt': recordedAt.millisecondsSinceEpoch,
    };
  }
}
