import '../providers.dart';

class SleepSession {
  final String id;
  final BrandProvider source;
  final DateTime bedtime;
  final DateTime wakeTime;
  final int totalSleepSec;
  final int deepSleepSec;
  final int remSleepSec;
  final int lightSleepSec;
  final int awakeSec;
  final double efficiency;
  final int? sleepScore;
  final int? latencySec;
  final double? avgHeartRate;
  final double? avgHrv;
  final double? respiratoryRate;
  final DateTime recordedAt;
  final DateTime syncedAt;
  final Map<String, dynamic>? rawData;

  SleepSession({
    required this.id,
    required this.source,
    required this.bedtime,
    required this.wakeTime,
    required this.totalSleepSec,
    required this.deepSleepSec,
    required this.remSleepSec,
    required this.lightSleepSec,
    required this.awakeSec,
    required this.efficiency,
    this.sleepScore,
    this.latencySec,
    this.avgHeartRate,
    this.avgHrv,
    this.respiratoryRate,
    required this.recordedAt,
    required this.syncedAt,
    this.rawData,
  });

  factory SleepSession.fromMap(Map<String, dynamic> map) {
    return SleepSession(
      id: map['id'] as String,
      source: BrandProvider.values.firstWhere(
        (e) => e.name == map['source']['provider'],
        orElse: () => BrandProvider.healthKit,
      ),
      bedtime: DateTime.fromMillisecondsSinceEpoch(map['bedtime'] as int),
      wakeTime: DateTime.fromMillisecondsSinceEpoch(map['wakeTime'] as int),
      totalSleepSec: map['totalSleepSec'] as int,
      deepSleepSec: map['deepSleepSec'] as int,
      remSleepSec: map['remSleepSec'] as int,
      lightSleepSec: map['lightSleepSec'] as int,
      awakeSec: map['awakeSec'] as int,
      efficiency: (map['efficiency'] as num).toDouble(),
      sleepScore: map['sleepScore'] as int?,
      latencySec: map['latencySec'] as int?,
      avgHeartRate: (map['avgHeartRate'] as num?)?.toDouble(),
      avgHrv: (map['avgHrv'] as num?)?.toDouble(),
      respiratoryRate: (map['respiratoryRate'] as num?)?.toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recordedAt'] as int),
      syncedAt: DateTime.now(),
      rawData: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'source': {'provider': source.name},
      'bedtime': bedtime.millisecondsSinceEpoch,
      'wakeTime': wakeTime.millisecondsSinceEpoch,
      'totalSleepSec': totalSleepSec,
      'deepSleepSec': deepSleepSec,
      'remSleepSec': remSleepSec,
      'lightSleepSec': lightSleepSec,
      'awakeSec': awakeSec,
      'efficiency': efficiency,
      'sleepScore': sleepScore,
      'latencySec': latencySec,
      'avgHeartRate': avgHeartRate,
      'avgHrv': avgHrv,
      'respiratoryRate': respiratoryRate,
      'recordedAt': recordedAt.millisecondsSinceEpoch,
    };
  }
}
