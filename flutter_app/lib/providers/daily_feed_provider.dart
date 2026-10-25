import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/health_repository.dart';

enum LongevityTier {
  ethereal, // 95+
  titanium, // 90-94
  elite,    // 85-89
  standard  // <85
}

class HealthAura {
  final String name;
  final List<Color> colors;
  const HealthAura({required this.name, required this.colors});
}

/// A single day's health snapshot for the feed.
/// Rich data model powering the premium timeline cards.
class DaySnapshot {
  final DateTime date;
  final int steps;
  final double sleepHours;
  final double? hrv;
  final double activeEnergy;
  final String summary;
  
  // Enriched fields
  final int? restingHeartRate;
  final int exerciseMinutes;
  final int? bloodOxygen;
  final double sleepEfficiency;

  // ── NEW: Competitive & Sharable Fields ──
  final double distanceKm;
  final String? workoutType;       // e.g. "Running", "Cycling", "Yoga"
  final String? workoutPace;       // e.g. "5:32 /km"
  
  // Enriched streak and tier data
  int consistencyStreak;           // Number of consecutive days meeting basic activity/sleep goals
  LongevityTier longevityTier;     // Derived from day score

  DaySnapshot({
    required this.date,
    required this.steps,
    required this.sleepHours,
    this.hrv,
    required this.activeEnergy,
    required this.summary,
    this.restingHeartRate,
    this.exerciseMinutes = 0,
    this.bloodOxygen,
    this.sleepEfficiency = 0.85,
    this.distanceKm = 0,
    this.workoutType,
    this.workoutPace,
    this.consistencyStreak = 0,
    this.longevityTier = LongevityTier.standard,
  });

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String get dayLabel {
    if (isToday) return 'Today';
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  // ── Computed Scores ──

  /// Composite day score (0-100) combining sleep, activity, and recovery signals.
  int get dayScore {
    double score = 0;
    int signals = 0;

    // Sleep score (0-30 pts): 8h = perfect, <5h = poor
    if (sleepHours > 0) {
      final sleepScore = ((sleepHours / 8.0).clamp(0.0, 1.0) * 30);
      score += sleepScore;
      signals++;
    }

    // Activity score (0-25 pts): 10k steps = perfect
    if (steps > 0) {
      final stepScore = ((steps / 10000.0).clamp(0.0, 1.0) * 25);
      score += stepScore;
      signals++;
    }

    // Energy score (0-15 pts): 400 kcal = perfect
    if (activeEnergy > 0) {
      final energyScore = ((activeEnergy / 400.0).clamp(0.0, 1.0) * 15);
      score += energyScore;
      signals++;
    }

    // HRV score (0-15 pts): >60ms = excellent
    if (hrv != null && hrv! > 0) {
      final hrvScore = ((hrv! / 60.0).clamp(0.0, 1.0) * 15);
      score += hrvScore;
      signals++;
    }

    // RHR score (0-15 pts): <60bpm = excellent, >90 = poor (inverted)
    if (restingHeartRate != null && restingHeartRate! > 0) {
      final rhrNorm = 1.0 - ((restingHeartRate! - 45) / 45.0).clamp(0.0, 1.0);
      score += rhrNorm * 15;
      signals++;
    }

    if (signals == 0) return 0;
    // Normalize: if fewer signals, scale proportionally
    final maxPossible = signals == 5 ? 100.0 : (signals / 5.0) * 100;
    return ((score / maxPossible) * 100).round().clamp(0, 100);
  }

  /// Sleep quality grade based on hours + efficiency.
  String get sleepGrade {
    if (sleepHours <= 0) return '--';
    final qualityScore = (sleepHours / 8.0) * 0.6 + sleepEfficiency * 0.4;
    if (qualityScore >= 0.95) return 'A+';
    if (qualityScore >= 0.85) return 'A';
    if (qualityScore >= 0.70) return 'B';
    if (qualityScore >= 0.55) return 'C';
    return 'D';
  }

  /// Activity level descriptor.
  String get activityLevel {
    if (steps >= 10000 || activeEnergy >= 400) return 'High';
    if (steps >= 5000 || activeEnergy >= 200) return 'Moderate';
    if (steps > 0 || activeEnergy > 0) return 'Low';
    return 'None';
  }

  /// Recovery status based on HRV + RHR + sleep.
  String get recoveryStatus {
    int recoverySignals = 0;
    int goodSignals = 0;

    if (hrv != null && hrv! > 0) {
      recoverySignals++;
      if (hrv! >= 50) goodSignals++;
    }
    if (restingHeartRate != null && restingHeartRate! > 0) {
      recoverySignals++;
      if (restingHeartRate! <= 65) goodSignals++;
    }
    if (sleepHours > 0) {
      recoverySignals++;
      if (sleepHours >= 7) goodSignals++;
    }

    if (recoverySignals == 0) return 'Unknown';
    final ratio = goodSignals / recoverySignals;
    if (ratio >= 0.8) return 'Optimal';
    if (ratio >= 0.4) return 'Adequate';
    return 'Strained';
  }

  /// Recovery ratio 0.0-1.0 for the progress bar.
  double get recoveryRatio {
    int recoverySignals = 0;
    double totalRatio = 0;

    if (hrv != null && hrv! > 0) {
      recoverySignals++;
      totalRatio += (hrv! / 80.0).clamp(0.0, 1.0);
    }
    if (restingHeartRate != null && restingHeartRate! > 0) {
      recoverySignals++;
      totalRatio += 1.0 - ((restingHeartRate! - 45) / 45.0).clamp(0.0, 1.0);
    }
    if (sleepHours > 0) {
      recoverySignals++;
      totalRatio += (sleepHours / 8.0).clamp(0.0, 1.0);
    }
    if (recoverySignals == 0) return 0.5;
    return (totalRatio / recoverySignals).clamp(0.0, 1.0);
  }

  /// Steps progress 0.0-1.0 (target 10k).
  double get stepsProgress => (steps / 10000.0).clamp(0.0, 1.0);

  /// Sleep progress 0.0-1.0 (target 8h).
  double get sleepProgress => (sleepHours / 8.0).clamp(0.0, 1.0);

  /// Energy progress 0.0-1.0 (target 500 kcal).
  double get energyProgress => (activeEnergy / 500.0).clamp(0.0, 1.0);

  // ══════════════════════════════════════════════════════
  // NEW: Competitive & Sharable Computed Properties
  // ══════════════════════════════════════════════════════

  /// Whether this card should use the "Zenith" dark premium theme.
  /// Refined Logic: Score >= 90 OR (Personal Best AND meaningful metrics).
  /// This prevents a "Today - 100 steps" card from turning Zenith just because it's a PB.
  bool get isZenith => dayScore >= 90 || (isPersonalBest && _isExceptionalData);

  /// Whether the data is high enough to warrant the premium 'Zenith' aesthetic.
  bool get _isExceptionalData => steps >= 8000 || sleepHours >= 7.0 || distanceKm >= 3.0 || (hrv != null && hrv! >= 45);

  /// Whether this day has a personal best in any metric.
  /// Set externally by the provider after comparing against history.
  bool get isPersonalBest => _isPersonalBest;
  bool _isPersonalBest = false;

  /// The most impressive, sharable metric of the day.
  /// Returns a HighlightMetric with icon, value, label, and optional context.
  HighlightMetric? get highlightMetric {
    // Priority: Distance run/cycle > Steps milestone > Sleep record > HRV peak
    
    // 1. Distance-based workouts (most sharable)
    if (distanceKm >= 1.0 && workoutType != null) {
      final icon = _workoutIcon(workoutType!);
      return HighlightMetric(
        icon: icon,
        value: '${distanceKm.toStringAsFixed(1)} km',
        label: workoutType!,
        subtitle: workoutPace,
      );
    }

    // 2. High step count (>12k is impressive)
    if (steps >= 12000) {
      return HighlightMetric(
        icon: Icons.directions_walk_rounded,
        value: _formatNumber(steps),
        label: 'Steps',
        subtitle: 'Outstanding movement',
      );
    }

    // 3. Great sleep (8h+)
    if (sleepHours >= 8.0) {
      return HighlightMetric(
        icon: Icons.bedtime_rounded,
        value: '${sleepHours.toStringAsFixed(1)}h',
        label: 'Deep Recovery',
        subtitle: 'Grade $sleepGrade',
      );
    }

    // 4. High HRV (>60ms is elite for most age groups)
    if (hrv != null && hrv! >= 60) {
      return HighlightMetric(
        icon: Icons.monitor_heart_rounded,
        value: '${hrv!.toStringAsFixed(0)} ms',
        label: 'HRV Peak',
        subtitle: 'Autonomic balance',
      );
    }

    // 5. Active calories burn (>400 kcal)
    if (activeEnergy >= 400) {
      return HighlightMetric(
        icon: Icons.local_fire_department_rounded,
        value: '${activeEnergy.round()} kcal',
        label: 'Energy Burned',
        subtitle: 'High output day',
      );
    }

    // 6. Good exercise session
    if (exerciseMinutes >= 30) {
      return HighlightMetric(
        icon: Icons.fitness_center_rounded,
        value: '${exerciseMinutes} min',
        label: workoutType ?? 'Exercise',
        subtitle: null,
      );
    }

    return null;
  }

  /// Percentile text for competitive context.
  /// Based on WHO/AHA benchmarks for general adult population.
  String? get percentileText {
    // Steps percentile (CDC NHANES data: US adult avg ~4800 steps/day)
    if (steps >= 15000) return 'Top 1% in Mumbai';
    if (steps >= 12000) return 'Top 5% of Peers';
    if (steps >= 10000) return 'Top 10% Overall';

    // Sleep percentile (CDC: avg US adult ~6.8h)
    if (sleepHours >= 8.5) return 'Top 3% Deep Sleep';
    if (sleepHours >= 8.0) return 'Top 10% Rest';

    // HRV percentile (general: >60ms is top 15% for 25-45 age)
    if (hrv != null && hrv! >= 80) return 'Top 1% Recovery';
    if (hrv != null && hrv! >= 60) return 'Top 10% Autonomic Base';

    // RHR (AHA: <60 bpm is athletic)
    if (restingHeartRate != null && restingHeartRate! <= 52) return 'Athlete Heart';
    if (restingHeartRate != null && restingHeartRate! <= 58) return 'Elite Cardio Profile';

    // Distance
    if (distanceKm >= 10) return 'Top 2% Run Distance';
    if (distanceKm >= 5) return 'Top 8% Active Base';

    return null;
  }

  /// Physical equivalent of the caloric burn (Idea 9)
  String get metabolicTrophy {
    if (activeEnergy >= 1500) return 'Solar Flare';
    if (activeEnergy >= 800) return 'Roaring Campfire';
    if (activeEnergy >= 400) return 'Warm Hearth';
    if (activeEnergy >= 150) return 'Gentle Candle';
    return 'Dormant Ember';
  }

  /// Dynamic visual "vibe" of the day (Idea 8)
  HealthAura get healthAura {
    final score = dayScore;
    if (score >= 95) {
      return const HealthAura(
        name: 'Radiant Divine',
        colors: [Color(0xFFFBBF24), Colors.white, Color(0xFFF59E0B)],
      );
    }
    if (score >= 90) {
      return const HealthAura(
        name: 'Pulsing Azure',
        colors: [Color(0xFF38BDF8), Color(0xFF818CF8), Color(0xFF3B82F6)],
      );
    }
    if (score >= 80) {
      return const HealthAura(
        name: 'Vibrant Jade',
        colors: [Color(0xFF34D399), Color(0xFF059669), Color(0xFF10B981)],
      );
    }
    if (score >= 60) {
      return const HealthAura(
        name: 'Solar Glow',
        colors: [Color(0xFFFB923C), Color(0xFFF97316), Color(0xFFEA580C)],
      );
    }
    return const HealthAura(
      name: 'Midnight Calm',
      colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF3730A3)],
    );
  }

  IconData _workoutIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('run')) return Icons.directions_run_rounded;
    if (lower.contains('cycl') || lower.contains('bike')) return Icons.pedal_bike_rounded;
    if (lower.contains('swim')) return Icons.pool_rounded;
    if (lower.contains('yoga')) return Icons.self_improvement_rounded;
    if (lower.contains('hik')) return Icons.terrain_rounded;
    if (lower.contains('walk')) return Icons.directions_walk_rounded;
    return Icons.fitness_center_rounded;
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

/// A highlighted "hero" metric for a day — the most impressive, sharable stat.
class HighlightMetric {
  final IconData icon;
  final String value;
  final String label;
  final String? subtitle;

  const HighlightMetric({
    required this.icon,
    required this.value,
    required this.label,
    this.subtitle,
  });
}

/// Generates a natural-language daily summary from metrics — punchier, headline style for sharing.
String _generateSummary({
  required int steps,
  required double sleepHours,
  double? hrv,
  required double activeEnergy,
  int? restingHeartRate,
  int exerciseMinutes = 0,
  double distanceKm = 0,
  String? workoutType,
  required bool isPersonalBest,
}) {
  if (isPersonalBest) {
    if (distanceKm >= 2.0) {
      return 'NEW HORIZONS. You just set a personal best with a ${distanceKm.toStringAsFixed(1)}km output.';
    }
    if (hrv != null && hrv > 60) {
      return 'PEAK RECOVERY. Your nervous system is fully recharged at ${hrv.toStringAsFixed(0)}ms HRV.';
    }
    if (steps >= 12000) {
      return 'RELENTLESS. Crushed a new milestone with ${_formatNumber(steps)} steps today.';
    }
  }

  // High tier statements
  if (hrv != null && hrv > 65 && restingHeartRate != null && restingHeartRate < 55) {
    return 'ELITE READINESS. Your cardiovascular metrics are outperforming 90% of male peers.';
  }

  if (sleepHours >= 8.0 && activeEnergy >= 500) {
    return 'MAXIMUM EFFICIENCY. Perfect sleep foundation paired with extreme energy expenditure.';
  }

  final parts = <String>[];
  if (distanceKm >= 1.0 && workoutType != null) {
    parts.add('${distanceKm.toStringAsFixed(1)}km ${workoutType.toLowerCase()} — crushed it.');
  }

  if (sleepHours >= 7.5) {
    parts.add('${sleepHours.toStringAsFixed(1)}h sleep — optimal cellular repair.');
  } else if (sleepHours > 0 && sleepHours < 6) {
    parts.add('Only ${sleepHours.toStringAsFixed(1)}h sleep — expect CNS fatigue today.');
  }

  if (steps >= 10000) {
    parts.add('${_formatNumber(steps)} steps logged.');
  }

  if (parts.isEmpty) {
    return 'No data recorded. Connect your wearable to build your Zenith profile.';
  }

  return parts.join(' ');
}

String _formatNumber(int n) {
  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1)}k';
  }
  return n.toString();
}

/// Provider that builds a 7-day feed of daily snapshots with enriched data.
final dailyFeedProvider = FutureProvider.autoDispose<List<DaySnapshot>>((ref) async {
  final repo = HealthRepository();

  // Fetch all weekly data in parallel — including new enriched metrics
  final results = await Future.wait([
    repo.getWeeklySteps(),           // 0
    repo.getWeeklySleep(),           // 1
    repo.getHrvHistory(days: 7),     // 2
    repo.getActiveEnergyHistory(days: 7),  // 3
    repo.getRhrHistory(days: 7),     // 4
    repo.getSpO2History(days: 7),    // 5
    repo.getWorkoutHistory(days: 7), // 6 — NEW: workout data for highlights
  ]);

  final weeklySteps = results[0] as List<Map<String, dynamic>>;
  final weeklySleep = results[1] as List<Map<String, dynamic>>;
  final hrvHistory = results[2] as List<Map<String, dynamic>>;
  final energyHistory = results[3] as List<Map<String, dynamic>>;
  final rhrHistory = results[4] as List<Map<String, dynamic>>;
  final spo2History = results[5] as List<Map<String, dynamic>>;
  final workoutHistory = results[6] as List<Map<String, dynamic>>;

  // Index by date for quick lookup
  final hrvByDate = <String, double>{};
  for (final entry in hrvHistory) {
    final date = entry['date'] as DateTime;
    hrvByDate['${date.year}-${date.month}-${date.day}'] = (entry['value'] as num).toDouble();
  }

  final energyByDate = <String, double>{};
  for (final entry in energyHistory) {
    final date = entry['date'] as DateTime;
    energyByDate['${date.year}-${date.month}-${date.day}'] = (entry['value'] as num).toDouble();
  }

  final sleepByDate = <String, double>{};
  for (final entry in weeklySleep) {
    final date = entry['date'] as DateTime;
    sleepByDate['${date.year}-${date.month}-${date.day}'] = (entry['hours'] as num).toDouble();
  }

  final rhrByDate = <String, int>{};
  for (final entry in rhrHistory) {
    final date = entry['date'] as DateTime;
    rhrByDate['${date.year}-${date.month}-${date.day}'] = (entry['value'] as num).toInt();
  }

  final spo2ByDate = <String, int>{};
  for (final entry in spo2History) {
    final date = entry['date'] as DateTime;
    spo2ByDate['${date.year}-${date.month}-${date.day}'] = (entry['value'] as num).toInt();
  }

  // ── NEW: Index workouts by date (pick best workout per day) ──
  final workoutByDate = <String, Map<String, dynamic>>{};
  for (final w in workoutHistory) {
    final date = w['date'] as DateTime;
    final key = '${date.year}-${date.month}-${date.day}';
    final existing = workoutByDate[key];
    // Keep the workout with the longest distance, or longest duration
    if (existing == null) {
      workoutByDate[key] = w;
    } else {
      final existDist = (existing['distance'] as num?)?.toDouble() ?? 0;
      final newDist = (w['distance'] as num?)?.toDouble() ?? 0;
      if (newDist > existDist) {
        workoutByDate[key] = w;
      } else if (newDist == existDist) {
        final existDur = (existing['durationMin'] as num?)?.toInt() ?? 0;
        final newDur = (w['durationMin'] as num?)?.toInt() ?? 0;
        if (newDur > existDur) workoutByDate[key] = w;
      }
    }
  }

  // ── Pre-calculate maximums and streaks ──
  int maxSteps = 0;
  double maxSleep = 0;
  double maxHrv = 0;
  double maxDistance = 0;

  final List<Map<String, dynamic>> rawDays = [];

  for (final stepEntry in weeklySteps) {
    final date = stepEntry['date'] as DateTime;
    final key = '${date.year}-${date.month}-${date.day}';
    final steps = (stepEntry['steps'] as num?)?.toInt() ?? 0;
    final sleep = sleepByDate[key] ?? 0.0;
    final hrv = hrvByDate[key];
    final energy = energyByDate[key] ?? 0.0;
    final rhr = rhrByDate[key];
    final spo2 = spo2ByDate[key];
    
    final workout = workoutByDate[key];
    final distKm = (workout?['distance'] as num?)?.toDouble() ?? 0.0;
    final wType = workout?['type'] as String?;
    final wPace = workout?['paceString'] as String?;

    if (steps == 0 && sleep == 0 && hrv == null && energy == 0) continue;

    if (steps > maxSteps) maxSteps = steps;
    if (sleep > maxSleep) maxSleep = sleep;
    if (hrv != null && hrv > maxHrv) maxHrv = hrv;
    if (distKm > maxDistance) maxDistance = distKm;

    rawDays.add({
      'date': date,
      'steps': steps,
      'sleep': sleep,
      'hrv': hrv,
      'energy': energy,
      'rhr': rhr,
      'spo2': spo2,
      'distKm': distKm,
      'wType': wType,
      'wPace': wPace,
    });
  }

  // Calculate streaks (chronological order required: oldest to newest)
  rawDays.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
  
  int currentStreak = 0;
  final feed = <DaySnapshot>[];

  for (final raw in rawDays) {
    final steps = raw['steps'] as int;
    final sleep = raw['sleep'] as double;
    final hrv = raw['hrv'] as double?;
    final distKm = raw['distKm'] as double;

    // A "consistent" day is one where the user hits basic minimums
    if (steps >= 7000 || sleep >= 7.0 || distKm >= 2.0) {
      currentStreak++;
    } else {
      currentStreak = 0; // Reset streak
    }

    bool isPB = false;
    if (steps > 0 && steps == maxSteps && maxSteps >= 8000) isPB = true;
    if (sleep > 0 && sleep == maxSleep && maxSleep >= 7.5) isPB = true;
    if (hrv != null && hrv == maxHrv && maxHrv >= 40) isPB = true;
    if (distKm > 0 && distKm == maxDistance && maxDistance >= 2.0) isPB = true;

    final summary = _generateSummary(
      steps: steps,
      sleepHours: sleep,
      hrv: hrv,
      activeEnergy: raw['energy'] as double,
      restingHeartRate: raw['rhr'] as int?,
      distanceKm: distKm,
      workoutType: raw['wType'] as String?,
      isPersonalBest: isPB,
    );

    final snapshot = DaySnapshot(
      date: raw['date'] as DateTime,
      steps: steps,
      sleepHours: sleep,
      hrv: hrv,
      activeEnergy: raw['energy'] as double,
      restingHeartRate: raw['rhr'] as int?,
      bloodOxygen: raw['spo2'] as int?,
      distanceKm: distKm,
      workoutType: raw['wType'] as String?,
      workoutPace: raw['wPace'] as String?,
      summary: summary,
      consistencyStreak: currentStreak,
    );
    
    // Tag PB and Longevity Tier based on the generated day score
    snapshot._isPersonalBest = isPB;
    
    final score = snapshot.dayScore;
    if (score >= 95) {
      snapshot.longevityTier = LongevityTier.ethereal;
    } else if (score >= 90) {
      snapshot.longevityTier = LongevityTier.titanium;
    } else if (score >= 85) {
      snapshot.longevityTier = LongevityTier.elite;
    } else {
      snapshot.longevityTier = LongevityTier.standard;
    }

    feed.add(snapshot);
  }

  // Return reversed so newest is first
  return feed.reversed.toList();
});
