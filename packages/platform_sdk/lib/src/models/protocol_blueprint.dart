import 'daily_rhythm.dart';

/// Generation status for a protocol blueprint
enum BlueprintStatus {
  pending,
  generating,
  complete,
  failed;

  static BlueprintStatus fromString(String s) {
    switch (s) {
      case 'generating':
        return BlueprintStatus.generating;
      case 'complete':
        return BlueprintStatus.complete;
      case 'failed':
        return BlueprintStatus.failed;
      default:
        return BlueprintStatus.pending;
    }
  }

  String toValue() => name;
}

/// A single day within the protocol blueprint
class BlueprintDay {
  final int dayNumber; // 1-indexed
  final int weekNumber; // 1-indexed
  final DateTime date;
  final String summary;
  final List<RhythmTask> tasks;

  const BlueprintDay({
    required this.dayNumber,
    required this.weekNumber,
    required this.date,
    required this.summary,
    required this.tasks,
  });

  Map<String, dynamic> toJson() {
    return {
      'day': dayNumber,
      'week': weekNumber,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'summary': summary,
      'tasks': tasks.map((t) => t.toJson()).toList(),
    };
  }

  factory BlueprintDay.fromJson(Map<String, dynamic> json) {
    return BlueprintDay(
      dayNumber: json['day'] ?? 1,
      weekNumber: json['week'] ?? 1,
      date: DateTime.parse(json['date']),
      summary: json['summary'] ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((t) => RhythmTask.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert this blueprint day to a DailyRhythm for use in the rhythm system
  DailyRhythm toDailyRhythm() {
    return DailyRhythm(
      id: 'blueprint_day_$dayNumber',
      date: date,
      summary: summary,
      tasks: tasks,
      source: 'blueprint',
      blueprintDayNumber: dayNumber,
    );
  }
}

/// The full pre-generated protocol blueprint
class ProtocolBlueprint {
  final String id;
  final String userId;
  final String protocolId;
  final int durationWeeks;
  final DateTime startDate;
  final BlueprintStatus status;
  final int weeksGenerated;
  final List<BlueprintDay> days;

  const ProtocolBlueprint({
    required this.id,
    required this.userId,
    required this.protocolId,
    required this.durationWeeks,
    required this.startDate,
    this.status = BlueprintStatus.pending,
    this.weeksGenerated = 0,
    this.days = const [],
  });

  ProtocolBlueprint copyWith({
    BlueprintStatus? status,
    int? weeksGenerated,
    List<BlueprintDay>? days,
  }) {
    return ProtocolBlueprint(
      id: id,
      userId: userId,
      protocolId: protocolId,
      durationWeeks: durationWeeks,
      startDate: startDate,
      status: status ?? this.status,
      weeksGenerated: weeksGenerated ?? this.weeksGenerated,
      days: days ?? this.days,
    );
  }

  /// Total number of days in the protocol
  int get totalDays => durationWeeks * 7;

  /// Get the day number for a given date (1-indexed), or null if out of range.
  ///
  /// Uses midnight-normalized dates to avoid timezone drift. If the user
  /// starts a protocol at 11:55 PM, Day 1 is still that calendar day.
  int? dayNumberForDate(DateTime date) {
    // Normalize both dates to midnight to prevent timezone drift
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);
    final daysSinceStart = normalizedDate.difference(normalizedStart).inDays;
    final dayNum = daysSinceStart + 1;
    if (dayNum < 1 || dayNum > totalDays) return null;
    return dayNum;
  }

  /// Get the BlueprintDay for a specific day number
  BlueprintDay? getDayByNumber(int dayNumber) {
    try {
      return days.firstWhere((d) => d.dayNumber == dayNumber);
    } catch (_) {
      return null;
    }
  }

  /// Get the BlueprintDay for a given date
  BlueprintDay? getDayByDate(DateTime date) {
    final dayNum = dayNumberForDate(date);
    if (dayNum == null) return null;
    return getDayByNumber(dayNum);
  }

  /// Current day number based on today's date
  int? get todayDayNumber => dayNumberForDate(DateTime.now());

  /// Progress as fraction (0.0 to 1.0) based on generation
  double get generationProgress {
    if (durationWeeks == 0) return 0.0;
    return (weeksGenerated / durationWeeks).clamp(0.0, 1.0);
  }

  /// Whether generation is fully done
  bool get isFullyGenerated => status == BlueprintStatus.complete;

  factory ProtocolBlueprint.fromSupabase(Map<String, dynamic> row) {
    final blueprintDataRaw = row['blueprint_data'];
    List<BlueprintDay> parsedDays = [];

    if (blueprintDataRaw is List) {
      for (var dayJson in blueprintDataRaw) {
        if (dayJson is Map<String, dynamic>) {
          try {
            parsedDays.add(BlueprintDay.fromJson(dayJson));
          } catch (_) {}
        }
      }
    }

    return ProtocolBlueprint(
      id: row['id'],
      userId: row['user_id'],
      protocolId: row['protocol_id'],
      durationWeeks: row['duration_weeks'] ?? 12,
      startDate: DateTime.parse(row['start_date']),
      status: BlueprintStatus.fromString(row['generation_status'] ?? 'pending'),
      weeksGenerated: row['weeks_generated'] ?? 0,
      days: parsedDays,
    );
  }
}
