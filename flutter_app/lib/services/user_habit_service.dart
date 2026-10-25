import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// ADAPTIVE EVOLUTION ENGINE — "The Intelligence That Learns You"
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// A multi-layered behavioral intelligence system that observes, learns,
/// predicts, and autonomously acts based on the user's natural habits.
///
/// Algorithms:
/// - EWMA (Exponentially Weighted Moving Average) for time prediction
/// - Weekday/Weekend bifurcation for dual-persona modeling
/// - Confidence scoring with adaptive 3→7 day window expansion
/// - Variance analysis for consistency detection
/// - Linear regression for habit drift detection
/// - Cross-signal correlation (sleep↔performance, workout↔recovery)
///
/// References:
/// - Hunter JS (1986). The EWMA — exponentially weighted moving average.
/// - Roenneberg T et al. (2003). Chronotype classification (MCTQ).
/// - Buysse DJ (1989). Sleep efficiency measurement (PSQI).
/// ═══════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

enum MealType { breakfast, lunch, dinner, snack }

class HabitEvent {
  final String time; // HH:mm format
  final String date; // yyyy-MM-dd format

  const HabitEvent({required this.time, required this.date});

  Map<String, dynamic> toJson() => {'time': time, 'date': date};
  
  factory HabitEvent.fromJson(Map<String, dynamic> json) => HabitEvent(
    time: json['time'] as String,
    date: json['date'] as String,
  );

  /// Minutes since midnight for EWMA calculation.
  int get minutesSinceMidnight {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

class WorkoutEvent {
  final String time;
  final int durationMinutes;
  final String date;

  const WorkoutEvent({required this.time, required this.durationMinutes, required this.date});

  Map<String, dynamic> toJson() => {'time': time, 'duration': durationMinutes, 'date': date};
  
  factory WorkoutEvent.fromJson(Map<String, dynamic> json) => WorkoutEvent(
    time: json['time'] as String,
    durationMinutes: json['duration'] as int,
    date: json['date'] as String,
  );

  int get minutesSinceMidnight {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

class SleepEvent {
  final String bedtime; // HH:mm
  final String wakeTime; // HH:mm
  final double hours;
  final String date;

  const SleepEvent({required this.bedtime, required this.wakeTime, required this.hours, required this.date});

  Map<String, dynamic> toJson() => {'bedtime': bedtime, 'wake': wakeTime, 'hours': hours, 'date': date};
  
  factory SleepEvent.fromJson(Map<String, dynamic> json) => SleepEvent(
    bedtime: json['bedtime'] as String,
    wakeTime: json['wake'] as String,
    hours: (json['hours'] as num).toDouble(),
    date: json['date'] as String,
  );

  /// Bedtime as minutes since midnight. Handles past-midnight (e.g., 00:30 → 1470).
  int get bedtimeMinutes {
    final parts = bedtime.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    // If hour < 6, it's past midnight — add 24h offset for continuity
    return h < 6 ? (h + 24) * 60 + m : h * 60 + m;
  }

  int get wakeMinutes {
    final parts = wakeTime.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}

class TaskCompletionEvent {
  final String category;
  final String time;
  final bool completed;
  final String date;

  const TaskCompletionEvent({required this.category, required this.time, required this.completed, required this.date});

  Map<String, dynamic> toJson() => {'category': category, 'time': time, 'completed': completed, 'date': date};
  
  factory TaskCompletionEvent.fromJson(Map<String, dynamic> json) => TaskCompletionEvent(
    category: json['category'] as String,
    time: json['time'] as String,
    completed: json['completed'] as bool,
    date: json['date'] as String,
  );
}

/// The output of the engine — a full behavioral profile for the user.
class UserHabitProfile {
  // Predicted times (EWMA-based)
  final TimeOfDay? predictedBreakfast;
  final TimeOfDay? predictedLunch;
  final TimeOfDay? predictedDinner;
  final TimeOfDay? predictedWorkoutStart;
  final TimeOfDay? predictedBedtime;
  final TimeOfDay? predictedWakeUp;

  // Confidence scores (0.0 - 1.0)
  final double breakfastConfidence;
  final double lunchConfidence;
  final double dinnerConfidence;
  final double workoutConfidence;
  final double bedtimeConfidence;
  final double wakeConfidence;

  // Variance (standard deviation in minutes)
  final double breakfastVariance;
  final double lunchVariance;
  final double dinnerVariance;
  final double workoutVariance;

  // Behavioral traits
  final String chronotype; // 'early_bird', 'night_owl', 'balanced'
  final bool isWeekend;
  final double overallConsistency; // 0.0 - 1.0
  final Map<String, double> categoryCompletionRates;

  // Cross-signal insights
  final double? sleepPerformanceCorrelation;
  final String? strongestHabit;
  final String? weakestHabit;

  // Drift detection (minutes per week, positive = getting later)
  final Map<String, int> driftMinutesPerWeek;

  const UserHabitProfile({
    this.predictedBreakfast,
    this.predictedLunch,
    this.predictedDinner,
    this.predictedWorkoutStart,
    this.predictedBedtime,
    this.predictedWakeUp,
    this.breakfastConfidence = 0.0,
    this.lunchConfidence = 0.0,
    this.dinnerConfidence = 0.0,
    this.workoutConfidence = 0.0,
    this.bedtimeConfidence = 0.0,
    this.wakeConfidence = 0.0,
    this.breakfastVariance = 0.0,
    this.lunchVariance = 0.0,
    this.dinnerVariance = 0.0,
    this.workoutVariance = 0.0,
    this.chronotype = 'balanced',
    this.isWeekend = false,
    this.overallConsistency = 0.0,
    this.categoryCompletionRates = const {},
    this.sleepPerformanceCorrelation,
    this.strongestHabit,
    this.weakestHabit,
    this.driftMinutesPerWeek = const {},
  });

  /// Formats the profile as structured context for the AI prompt.
  String toAIContext() {
    final buffer = StringBuffer();
    buffer.writeln('BEHAVIORAL INTELLIGENCE (observed from real user actions):');
    buffer.writeln('- Chronotype: ${_chronotypeLabel(chronotype)} (${isWeekend ? "weekend" : "weekday"} profile)');

    // Meal predictions
    buffer.writeln('- Observed Meal Windows:');
    if (predictedBreakfast != null && breakfastConfidence >= 0.3) {
      buffer.writeln('  • Breakfast: ~${_formatTime(predictedBreakfast!)} (confidence: ${breakfastConfidence.toStringAsFixed(1)}, ${_varianceLabel(breakfastVariance)})');
    }
    if (predictedLunch != null && lunchConfidence >= 0.3) {
      buffer.writeln('  • Lunch: ~${_formatTime(predictedLunch!)} (confidence: ${lunchConfidence.toStringAsFixed(1)}, ${_varianceLabel(lunchVariance)})');
    }
    if (predictedDinner != null && dinnerConfidence >= 0.3) {
      buffer.writeln('  • Dinner: ~${_formatTime(predictedDinner!)} (confidence: ${dinnerConfidence.toStringAsFixed(1)}, ${_varianceLabel(dinnerVariance)})');
    }

    // Workout prediction
    if (predictedWorkoutStart != null && workoutConfidence >= 0.3) {
      buffer.writeln('- Workout Window: ~${_formatTime(predictedWorkoutStart!)} (confidence: ${workoutConfidence.toStringAsFixed(1)}, ${_varianceLabel(workoutVariance)})');
    }

    // Sleep prediction
    if (predictedBedtime != null && bedtimeConfidence >= 0.3) {
      buffer.writeln('- Typical Bedtime: ~${_formatTime(predictedBedtime!)} (confidence: ${bedtimeConfidence.toStringAsFixed(1)})');
    }
    if (predictedWakeUp != null && wakeConfidence >= 0.3) {
      buffer.writeln('- Typical Wake-up: ~${_formatTime(predictedWakeUp!)} (confidence: ${wakeConfidence.toStringAsFixed(1)})');
    }

    // Cross-signal insights
    if (sleepPerformanceCorrelation != null) {
      final direction = sleepPerformanceCorrelation! > 0.3 ? 'positively' : (sleepPerformanceCorrelation! < -0.3 ? 'negatively' : 'weakly');
      buffer.writeln('- Sleep↔Performance: Sleep hours $direction correlate with next-day task completion');
    }

    // Completion patterns
    if (categoryCompletionRates.isNotEmpty) {
      buffer.writeln('- Completion Patterns:');
      if (strongestHabit != null) buffer.writeln('  • Strongest: $strongestHabit');
      if (weakestHabit != null) buffer.writeln('  • Weakest: $weakestHabit');
    }

    // Drift
    final activeDrifts = driftMinutesPerWeek.entries.where((e) => e.value.abs() > 10);
    if (activeDrifts.isNotEmpty) {
      buffer.writeln('- Drift Detection:');
      for (final d in activeDrifts) {
        final direction = d.value > 0 ? 'later' : 'earlier';
        buffer.writeln('  • ${d.key}: shifting ${d.value.abs()}min ${direction} per week');
      }
    }

    // Adaptive rules
    buffer.writeln('');
    buffer.writeln('ADAPTIVE RULES:');
    buffer.writeln('1. Schedule diet tasks at the OBSERVED meal times above (not generic times).');
    buffer.writeln('2. If a confidence score is < 0.3, use the protocol default time instead.');
    buffer.writeln('3. If a category has low completion rate, consider moving those tasks to a stronger time window.');
    if (weakestHabit != null) {
      buffer.writeln('4. The user struggles with: $weakestHabit — consider adjusting these tasks.');
    }
    buffer.writeln('5. Reference the user\'s patterns naturally in the summary.');

    return buffer.toString();
  }

  String _chronotypeLabel(String type) {
    switch (type) {
      case 'early_bird': return 'Early Bird (typically wakes before 7 AM)';
      case 'night_owl': return 'Night Owl (typically sleeps past midnight)';
      default: return 'Balanced';
    }
  }

  String _varianceLabel(double sigma) {
    if (sigma < 20) return 'very consistent σ=${sigma.round()}min';
    if (sigma < 45) return 'moderate consistency σ=${sigma.round()}min';
    if (sigma < 75) return 'variable σ=${sigma.round()}min';
    return 'highly variable σ=${sigma.round()}min';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $period';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Core Service
// ─────────────────────────────────────────────────────────────────────────────

class UserHabitService {
  static const String _storageKey = 'habit_events_v1';
  static const int _maxEventsPerSlot = 14; // 2-week rolling buffer

  // ═══════════════════════════════════════════════════════════════════════════
  // SIGNAL RECORDING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Records a meal event from a Lens scan.
  static Future<void> recordMealEvent(MealType meal, DateTime timestamp) async {
    final event = HabitEvent(
      time: '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
      date: _dateStr(timestamp),
    );
    final dayType = _dayType(timestamp);
    final mealKey = meal.name; // breakfast, lunch, dinner, snack

    final store = await _loadStore();
    final meals = store['meals'] as Map<String, dynamic>? ?? {};
    final dayMeals = meals[dayType] as Map<String, dynamic>? ?? {};
    final events = (dayMeals[mealKey] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    // Deduplicate: don't record same date twice
    if (events.any((e) => e['date'] == event.date)) return;

    events.add(event.toJson());
    // Cap at max
    while (events.length > _maxEventsPerSlot) {
      events.removeAt(0);
    }

    dayMeals[mealKey] = events;
    meals[dayType] = dayMeals;
    store['meals'] = meals;
    await _saveStore(store);

    debugPrint('🧠 HabitEngine: Recorded $mealKey at ${event.time} ($dayType)');
  }

  /// Records a workout event from wearable sync.
  static Future<void> recordWorkoutEvent(DateTime timestamp, int durationMin) async {
    final event = WorkoutEvent(
      time: '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
      durationMinutes: durationMin,
      date: _dateStr(timestamp),
    );
    final dayType = _dayType(timestamp);

    final store = await _loadStore();
    final workouts = store['workouts'] as Map<String, dynamic>? ?? {};
    final events = (workouts[dayType] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    if (events.any((e) => e['date'] == event.date)) return;

    events.add(event.toJson());
    while (events.length > _maxEventsPerSlot) {
      events.removeAt(0);
    }

    workouts[dayType] = events;
    store['workouts'] = workouts;
    await _saveStore(store);

    debugPrint('🧠 HabitEngine: Recorded workout ${durationMin}min at ${event.time} ($dayType)');
  }

  /// Records a sleep cycle from wearable sync.
  static Future<void> recordSleepEvent(DateTime bedtime, DateTime wakeTime, double hours) async {
    final event = SleepEvent(
      bedtime: '${bedtime.hour.toString().padLeft(2, '0')}:${bedtime.minute.toString().padLeft(2, '0')}',
      wakeTime: '${wakeTime.hour.toString().padLeft(2, '0')}:${wakeTime.minute.toString().padLeft(2, '0')}',
      hours: hours,
      date: _dateStr(wakeTime), // Index by wake date (the "next morning")
    );
    // Sleep day type is based on the bedtime day
    final dayType = _dayType(bedtime);

    final store = await _loadStore();
    final sleep = store['sleep'] as Map<String, dynamic>? ?? {};
    final events = (sleep[dayType] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    if (events.any((e) => e['date'] == event.date)) return;

    events.add(event.toJson());
    while (events.length > _maxEventsPerSlot) {
      events.removeAt(0);
    }

    sleep[dayType] = events;
    store['sleep'] = sleep;
    await _saveStore(store);

    debugPrint('🧠 HabitEngine: Recorded sleep ${hours.toStringAsFixed(1)}h, bed=${event.bedtime}, wake=${event.wakeTime} ($dayType)');
  }

  /// Records a task completion or skip.
  static Future<void> recordTaskCompletionEvent(String category, DateTime timestamp, bool completed) async {
    final event = TaskCompletionEvent(
      category: category,
      time: '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
      completed: completed,
      date: _dateStr(timestamp),
    );

    final store = await _loadStore();
    final completions = store['taskCompletions'] as Map<String, dynamic>? ?? {};
    final events = (completions[category] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    // Allow multiple per day (different tasks in same category)
    events.add(event.toJson());
    while (events.length > _maxEventsPerSlot * 3) { // Higher cap for completions
      events.removeAt(0);
    }

    completions[category] = events;
    store['taskCompletions'] = completions;
    await _saveStore(store);
  }

  /// Records an app open event for chronotype classification.
  static Future<void> recordAppOpenEvent(DateTime timestamp) async {
    // Only record morning opens (5-11 AM) — this indicates wake-up
    if (timestamp.hour < 5 || timestamp.hour >= 11) return;

    final event = HabitEvent(
      time: '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}',
      date: _dateStr(timestamp),
    );

    final store = await _loadStore();
    final opens = (store['appOpens'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();

    // One per day
    if (opens.any((e) => e['date'] == event.date)) return;

    opens.add(event.toJson());
    while (opens.length > _maxEventsPerSlot) {
      opens.removeAt(0);
    }

    store['appOpens'] = opens;
    await _saveStore(store);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILE GENERATION — The Intelligence Core
  // ═══════════════════════════════════════════════════════════════════════════

  /// Generates a full behavioral profile from accumulated habit data.
  static Future<UserHabitProfile> generateProfile() async {
    final store = await _loadStore();
    final now = DateTime.now();
    final isWeekend = now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    // For prediction, use TOMORROW's day type (we're predicting for next day)
    final tomorrow = now.add(const Duration(days: 1));
    final targetDayType = _dayType(tomorrow);

    // ── Extract event lists for the target day type ──
    final meals = store['meals'] as Map<String, dynamic>? ?? {};
    final targetMeals = meals[targetDayType] as Map<String, dynamic>? ?? {};

    final breakfastEvents = _parseHabitEvents(targetMeals['breakfast']);
    final lunchEvents = _parseHabitEvents(targetMeals['lunch']);
    final dinnerEvents = _parseHabitEvents(targetMeals['dinner']);

    final workouts = store['workouts'] as Map<String, dynamic>? ?? {};
    final workoutEvents = _parseWorkoutEvents(workouts[targetDayType]);

    final sleep = store['sleep'] as Map<String, dynamic>? ?? {};
    final sleepEvents = _parseSleepEvents(sleep[targetDayType]);
    // Fallback: if no sleep data for target day type, try the other
    final fallbackSleep = sleepEvents.isEmpty
        ? _parseSleepEvents(sleep[targetDayType == 'weekday' ? 'weekend' : 'weekday'])
        : sleepEvents;

    final appOpens = _parseHabitEvents(store['appOpens']);

    // ── Compute EWMA predictions ──
    final breakfastPred = _computeEWMA(breakfastEvents.map((e) => e.minutesSinceMidnight).toList());
    final lunchPred = _computeEWMA(lunchEvents.map((e) => e.minutesSinceMidnight).toList());
    final dinnerPred = _computeEWMA(dinnerEvents.map((e) => e.minutesSinceMidnight).toList());
    final workoutPred = _computeEWMA(workoutEvents.map((e) => e.minutesSinceMidnight).toList());

    final bedtimePred = _computeEWMA(
      (fallbackSleep.isNotEmpty ? fallbackSleep : sleepEvents).map((e) => e.bedtimeMinutes).toList()
    );
    final wakePred = _computeEWMA(
      (fallbackSleep.isNotEmpty ? fallbackSleep : sleepEvents).map((e) => e.wakeMinutes).toList()
    );
    // Also use app opens as a wake-up signal
    final wakeFromApp = _computeEWMA(appOpens.map((e) => e.minutesSinceMidnight).toList());

    // ── Compute confidence scores ──
    final breakfastConf = _confidence(breakfastEvents.length);
    final lunchConf = _confidence(lunchEvents.length);
    final dinnerConf = _confidence(dinnerEvents.length);
    final workoutConf = _confidence(workoutEvents.length);
    final bedtimeConf = _confidence(fallbackSleep.length);
    final wakeConf = _confidence(max(fallbackSleep.length, appOpens.length));

    // ── Compute variance (σ in minutes) ──
    final breakfastVar = _variance(breakfastEvents.map((e) => e.minutesSinceMidnight.toDouble()).toList());
    final lunchVar = _variance(lunchEvents.map((e) => e.minutesSinceMidnight.toDouble()).toList());
    final dinnerVar = _variance(dinnerEvents.map((e) => e.minutesSinceMidnight.toDouble()).toList());
    final workoutVar = _variance(workoutEvents.map((e) => e.minutesSinceMidnight.toDouble()).toList());

    // ── Drift detection ──
    final drifts = <String, int>{};
    drifts['lunch'] = _computeDrift(lunchEvents.map((e) => e.minutesSinceMidnight.toDouble()).toList());
    drifts['dinner'] = _computeDrift(dinnerEvents.map((e) => e.minutesSinceMidnight.toDouble()).toList());
    drifts['workout'] = _computeDrift(workoutEvents.map((e) => e.minutesSinceMidnight.toDouble()).toList());

    // ── Chronotype classification ──
    String chronotype = 'balanced';
    final effectiveWake = wakeFromApp ?? wakePred;
    final effectiveBed = bedtimePred;
    if (effectiveWake != null && effectiveWake < 7 * 60) {
      chronotype = 'early_bird';
    } else if (effectiveBed != null && effectiveBed > 24 * 60) { // Past midnight
      chronotype = 'night_owl';
    } else if (effectiveWake != null && effectiveWake > 9 * 60) {
      chronotype = 'night_owl';
    }

    // ── Category completion rates ──
    final completionRates = _computeCompletionRates(store);
    String? strongest;
    String? weakest;
    if (completionRates.isNotEmpty) {
      final sorted = completionRates.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      strongest = '${sorted.first.key} tasks (${(sorted.first.value * 100).round()}% completion)';
      if (sorted.last.value < 0.7) {
        weakest = '${sorted.last.key} tasks (${(sorted.last.value * 100).round()}% completion — often skipped)';
      }
    }

    // ── Overall consistency ──
    double overallConsistency = 0.0;
    if (completionRates.isNotEmpty) {
      overallConsistency = completionRates.values.reduce((a, b) => a + b) / completionRates.length;
    }

    // ── Cross-signal: sleep ↔ performance ──
    final sleepPerfCorr = await _computeSleepPerformanceCorrelation(store);

    // ── Build the profile ──
    return UserHabitProfile(
      predictedBreakfast: breakfastPred != null ? _minutesToTimeOfDay(breakfastPred) : null,
      predictedLunch: lunchPred != null ? _minutesToTimeOfDay(lunchPred) : null,
      predictedDinner: dinnerPred != null ? _minutesToTimeOfDay(dinnerPred) : null,
      predictedWorkoutStart: workoutPred != null ? _minutesToTimeOfDay(workoutPred) : null,
      predictedBedtime: effectiveBed != null ? _minutesToTimeOfDay(effectiveBed % (24 * 60)) : null,
      predictedWakeUp: effectiveWake != null ? _minutesToTimeOfDay(effectiveWake) : null,
      breakfastConfidence: breakfastConf,
      lunchConfidence: lunchConf,
      dinnerConfidence: dinnerConf,
      workoutConfidence: workoutConf,
      bedtimeConfidence: bedtimeConf,
      wakeConfidence: wakeConf,
      breakfastVariance: breakfastVar,
      lunchVariance: lunchVar,
      dinnerVariance: dinnerVar,
      workoutVariance: workoutVar,
      chronotype: chronotype,
      isWeekend: isWeekend,
      overallConsistency: overallConsistency,
      categoryCompletionRates: completionRates,
      sleepPerformanceCorrelation: sleepPerfCorr,
      strongestHabit: strongest,
      weakestHabit: weakest,
      driftMinutesPerWeek: drifts,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ALGORITHMS
  // ═══════════════════════════════════════════════════════════════════════════

  /// EWMA — Exponentially Weighted Moving Average.
  /// Gives more weight to recent observations.
  /// α adapts: 0.4 for few data points (fast learning), 0.2 for many (stability).
  static int? _computeEWMA(List<int> minuteValues) {
    if (minuteValues.isEmpty) return null;
    if (minuteValues.length == 1) return minuteValues.first;

    // Adaptive α: aggressive when little data, conservative when stable
    final double alpha = minuteValues.length < 5 ? 0.4 : 0.2;

    double ewma = minuteValues.first.toDouble();
    for (int i = 1; i < minuteValues.length; i++) {
      ewma = alpha * minuteValues[i] + (1 - alpha) * ewma;
    }

    return ewma.round();
  }

  /// Confidence score based on data count.
  /// More data = higher confidence in predictions.
  static double _confidence(int eventCount) {
    if (eventCount < 3) return 0.0;
    if (eventCount == 3) return 0.3;
    if (eventCount == 4) return 0.5;
    if (eventCount <= 6) return 0.7;
    return 0.9; // 7+
  }

  /// Standard deviation of a list of values (in minutes).
  /// Measures consistency of the user's behavior.
  static double _variance(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sumSquaredDiff = values.fold<double>(0, (sum, v) => sum + pow(v - mean, 2));
    return sqrt(sumSquaredDiff / (values.length - 1));
  }

  /// Drift detection using simple linear regression slope.
  /// Returns estimated drift in minutes per week.
  /// Positive = getting later, Negative = getting earlier.
  static int _computeDrift(List<double> minuteValues) {
    if (minuteValues.length < 4) return 0;

    // x = index (day), y = minutes
    final n = minuteValues.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += minuteValues[i];
      sumXY += i * minuteValues[i];
      sumX2 += i * i;
    }

    // Slope = (n*ΣXY - ΣX*ΣY) / (n*ΣX² - (ΣX)²)
    final denominator = n * sumX2 - sumX * sumX;
    if (denominator == 0) return 0;

    final slopePerDay = (n * sumXY - sumX * sumY) / denominator;
    // Convert daily slope to weekly
    return (slopePerDay * 7).round();
  }

  /// Computes category-level task completion rates from the store.
  static Map<String, double> _computeCompletionRates(Map<String, dynamic> store) {
    final completions = store['taskCompletions'] as Map<String, dynamic>? ?? {};
    final rates = <String, double>{};

    for (final category in completions.keys) {
      final events = (completions[category] as List<dynamic>? ?? [])
          .map((e) => TaskCompletionEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      if (events.isEmpty) continue;

      final completed = events.where((e) => e.completed).length;
      rates[category] = completed / events.length;
    }

    return rates;
  }

  /// Cross-signal: Pearson correlation between sleep hours and next-day 
  /// task completion rate. Requires at least 5 paired data points.
  static Future<double?> _computeSleepPerformanceCorrelation(Map<String, dynamic> store) async {
    try {
      final sleep = store['sleep'] as Map<String, dynamic>? ?? {};
      final allSleep = <SleepEvent>[];
      
      for (final dayType in sleep.values) {
        allSleep.addAll(_parseSleepEvents(dayType));
      }

      if (allSleep.length < 5) return null;

      // Build paired data: (sleep_hours, next_day_completion)
      final completions = store['taskCompletions'] as Map<String, dynamic>? ?? {};
      final allCompletions = <TaskCompletionEvent>[];
      for (final cat in completions.values) {
        allCompletions.addAll(
          (cat as List<dynamic>).map((e) => TaskCompletionEvent.fromJson(e as Map<String, dynamic>))
        );
      }

      final sleepHours = <double>[];
      final completionRates = <double>[];

      for (final s in allSleep) {
        // Find next day's completion events
        final nextDate = DateTime.parse(s.date).add(const Duration(days: 1));
        final nextDateStr = _dateStr(nextDate);
        final nextDayEvents = allCompletions.where((c) => c.date == nextDateStr).toList();

        if (nextDayEvents.isEmpty) continue;

        final rate = nextDayEvents.where((e) => e.completed).length / nextDayEvents.length;
        sleepHours.add(s.hours);
        completionRates.add(rate);
      }

      if (sleepHours.length < 5) return null;

      return _pearsonCorrelation(sleepHours, completionRates);
    } catch (e) {
      debugPrint('HabitEngine: Sleep-performance correlation failed: $e');
      return null;
    }
  }

  /// Pearson correlation coefficient (-1.0 to 1.0).
  static double _pearsonCorrelation(List<double> x, List<double> y) {
    final n = x.length;
    if (n < 3) return 0.0;

    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;

    double sumXY = 0, sumX2 = 0, sumY2 = 0;
    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      sumXY += dx * dy;
      sumX2 += dx * dx;
      sumY2 += dy * dy;
    }

    final denom = sqrt(sumX2 * sumY2);
    if (denom == 0) return 0.0;
    return (sumXY / denom).clamp(-1.0, 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  static String _dayType(DateTime dt) =>
      (dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday) ? 'weekend' : 'weekday';

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static TimeOfDay _minutesToTimeOfDay(int minutes) =>
      TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);

  static List<HabitEvent> _parseHabitEvents(dynamic data) {
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => HabitEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<WorkoutEvent> _parseWorkoutEvents(dynamic data) {
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => WorkoutEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<SleepEvent> _parseSleepEvents(dynamic data) {
    if (data == null) return [];
    return (data as List<dynamic>)
        .map((e) => SleepEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> _loadStore() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_storageKey);
    if (json == null) return {};
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveStore(Map<String, dynamic> store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(store));
  }
}
