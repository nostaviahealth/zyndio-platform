import 'package:flutter/material.dart';

/// Sedentary Lifestyle Activity Meter — Scoring Engine
///
/// Computes a 0–100 Activity Score from wearable + lab + dietary signals.
/// Zones: Critical (0–20) → Sedentary (21–40) → Low (41–55)
///        → Moderate (56–70) → Active (71–85) → Optimal (86–100)
///
/// References:
/// - ACSM Guidelines for Exercise Testing and Prescription (11th ed.)
/// - WHO Physical Activity Guidelines (2020): 150-300 min moderate/week
/// - Ekelund U et al. (2016). Activity volume and mortality.
class ActivityMeterService {
  /// Compute the Activity Score (0–100).
  ///
  /// Primary signals (wearables — 85 pts max):
  ///   steps (35), exerciseMinutes (25), strainScore (10),
  ///   sleepScore (10), recoveryScore (5)
  ///
  /// Boosters (+/- 15 pts):
  ///   labBooster (-5 to +5), foodBooster (-3 to +5), trendBooster (0 to +5)
  static int calculateActivityScore({
    required int steps,
    required int exerciseMinutes,
    required int strainScore,
    required int sleepScore,
    required int recoveryScore,
    int? labBooster,
    int? foodBooster,
    int? trendBooster,
  }) {
    // ── Wearable components (max 85) ──
    final double stepsComp = (steps / 10000.0).clamp(0.0, 1.0) * 35.0;
    final double exerciseComp = (exerciseMinutes / 30.0).clamp(0.0, 1.0) * 25.0;
    final double strainComp = (strainScore / 60.0).clamp(0.0, 1.0) * 10.0;
    final double sleepComp = (sleepScore / 100.0).clamp(0.0, 1.0) * 10.0;
    final double recoveryComp = (recoveryScore / 100.0).clamp(0.0, 1.0) * 5.0;

    final double baseScore =
        stepsComp + exerciseComp + strainComp + sleepComp + recoveryComp;

    // ── Boosters ──
    final int lab = (labBooster ?? 0).clamp(-5, 5);
    final int food = (foodBooster ?? 0).clamp(-3, 5);
    final int trend = (trendBooster ?? 0).clamp(0, 5);

    return (baseScore + lab + food + trend).clamp(0.0, 100.0).round();
  }

  /// Compute a lab-based booster from intelligence health domain scores.
  /// Looks for inflammation / metabolic markers.
  ///   Normal → +5, Borderline → 0, Elevated → -5
  static int calculateLabBooster({
    List<Map<String, dynamic>> healthDomains = const [],
  }) {
    if (healthDomains.isEmpty) return 0;

    // Look for relevant domains: Metabolic, Inflammation, Cardiovascular
    int flagCount = 0;
    int goodCount = 0;

    for (final domain in healthDomains) {
      final score = domain['score'] as int? ?? 50;
      final name = (domain['name'] as String? ?? '').toLowerCase();

      if (name.contains('metabolic') ||
          name.contains('inflam') ||
          name.contains('cardio') ||
          name.contains('lipid')) {
        if (score >= 70) {
          goodCount++;
        } else if (score < 40) {
          flagCount++;
        }
      }
    }

    if (flagCount >= 2) return -5;
    if (flagCount == 1) return -3;
    if (goodCount >= 2) return 5;
    if (goodCount == 1) return 3;
    return 0;
  }

  /// Compute a food-log-based booster.
  ///   Adequate protein + calories → +5
  ///   Severely under-eating → -3
  ///   No data → 0
  static int calculateFoodBooster({
    double? totalCalories,
    double? proteinGrams,
  }) {
    if (totalCalories == null && proteinGrams == null) return 0;

    int bonus = 0;
    if (totalCalories != null) {
      if (totalCalories >= 1400 && totalCalories <= 3000) {
        bonus += 2;
      } else if (totalCalories < 800) {
        bonus -= 3; // severe under-eating
      }
    }
    if (proteinGrams != null) {
      if (proteinGrams >= 40) {
        bonus += 3; // adequate protein
      }
    }
    return bonus.clamp(-3, 5);
  }

  /// Compute a trend booster from the 7-day rolling average.
  ///   Improvement >= 10% → +5
  ///   Improvement >= 5%  → +3
  ///   Stable             → 0
  static int calculateTrendBooster({
    required double currentDayScore,
    required double sevenDayAvg,
  }) {
    if (sevenDayAvg <= 0) return currentDayScore > 20 ? 5 : 0;

    final double pctChange =
        ((currentDayScore - sevenDayAvg) / sevenDayAvg) * 100;
    if (pctChange >= 10) return 5;
    if (pctChange >= 5) return 3;
    return 0;
  }

  // ─── Zone Classification ──────────────────────────────────────────────────

  static ActivityZone getZone(int score) {
    if (score <= 20) return ActivityZone.critical;
    if (score <= 40) return ActivityZone.sedentary;
    if (score <= 55) return ActivityZone.lowActive;
    if (score <= 70) return ActivityZone.moderate;
    if (score <= 85) return ActivityZone.active;
    return ActivityZone.optimal;
  }

  // ─── Risk Messages ────────────────────────────────────────────────────────

  static String getRiskMessage(int score) {
    final zone = getZone(score);
    switch (zone) {
      case ActivityZone.critical:
        return 'High risk: Prolonged inactivity increases cardiovascular disease, metabolic syndrome, and early mortality risk.';
      case ActivityZone.sedentary:
        return 'Elevated risk: Sedentary patterns can lead to insulin resistance, weight gain, and chronic fatigue.';
      case ActivityZone.lowActive:
        return 'Moderate risk: Suboptimal movement levels may affect metabolic health over time.';
      case ActivityZone.moderate:
        return 'Low risk: You\'re moving, but there\'s room to unlock more health benefits.';
      case ActivityZone.active:
        return 'Minimal risk: Your activity levels support strong cardiovascular and metabolic health.';
      case ActivityZone.optimal:
        return 'Negligible risk: Peak physical engagement — you\'re doing incredibly well.';
    }
  }

  // ─── Praise / Motivational Messages ───────────────────────────────────────

  static String getPraiseMessage(int score, double trendPct) {
    final zone = getZone(score);

    // ── Improving ──
    if (trendPct >= 10) {
      switch (zone) {
        case ActivityZone.critical:
        case ActivityZone.sedentary:
          return 'You\'re climbing out of the sedentary zone! Keep this momentum going — every step counts. 💪';
        case ActivityZone.lowActive:
          return 'Nice improvement! You\'re building a healthier baseline. A short walk today keeps the trend alive.';
        case ActivityZone.moderate:
        case ActivityZone.active:
          return 'You\'re on fire! 🔥 Activity up ${trendPct.round()}% this week. Your body is thanking you.';
        case ActivityZone.optimal:
          return 'Unstoppable! You\'re in the optimal zone and still improving. Truly elite. 🏆';
      }
    }

    // ── Stable ──
    if (trendPct > -5) {
      switch (zone) {
        case ActivityZone.critical:
          return 'Your body needs movement. Even a 5-minute walk can spark a positive change.';
        case ActivityZone.sedentary:
          return 'Small wins matter. Try adding a 10-minute walk to your day to start moving the needle.';
        case ActivityZone.lowActive:
          return 'You\'re close to a breakthrough. One more short activity session could push you higher.';
        case ActivityZone.moderate:
          return 'Solid consistency! You\'re in a good rhythm — keep it steady.';
        case ActivityZone.active:
          return 'Well done! You\'re meeting recommended activity levels. Keep it up! 👏';
        case ActivityZone.optimal:
          return 'You\'re in peak form. Maintain this and you\'re building long-term vitality. 🌟';
      }
    }

    // ── Declining ──
    switch (zone) {
      case ActivityZone.critical:
      case ActivityZone.sedentary:
        return 'Your movement dropped this week. A 10-minute walk can help reverse the trend.';
      case ActivityZone.lowActive:
      case ActivityZone.moderate:
        return 'Activity dipped slightly. A quick stretch or walk can get you back on track.';
      case ActivityZone.active:
      case ActivityZone.optimal:
        return 'Slight dip from your peak — rest days are okay, just stay mindful of the trend.';
    }
  }

  // ─── Actionable Recommendation ────────────────────────────────────────────

  static String getRecommendation(int score) {
    final zone = getZone(score);
    switch (zone) {
      case ActivityZone.critical:
        return 'Start with just 5 minutes of walking every hour. Set a timer to remind yourself.';
      case ActivityZone.sedentary:
        return 'Aim for a 15-minute walk after each meal today. It\'s the simplest metabolic hack.';
      case ActivityZone.lowActive:
        return 'Add one 20-minute brisk walk or light exercise session to your day.';
      case ActivityZone.moderate:
        return 'Try adding 10 more minutes of moderate activity or take the stairs whenever possible.';
      case ActivityZone.active:
        return 'Great work! Consider mixing in strength training or yoga for balanced fitness.';
      case ActivityZone.optimal:
        return 'You\'re crushing it! Focus on recovery quality and nutrition to sustain peak performance.';
    }
  }

  // ─── Zone Details for UI ──────────────────────────────────────────────────

  static Color getZoneColor(ActivityZone zone) {
    switch (zone) {
      case ActivityZone.critical:
        return const Color(0xFFEF4444); // Red
      case ActivityZone.sedentary:
        return const Color(0xFFF97316); // Orange
      case ActivityZone.lowActive:
        return const Color(0xFFF59E0B); // Amber
      case ActivityZone.moderate:
        return const Color(0xFF84CC16); // Yellow-Green
      case ActivityZone.active:
        return const Color(0xFF22C55E); // Green
      case ActivityZone.optimal:
        return const Color(0xFF10B981); // Emerald
    }
  }

  static String getZoneLabel(ActivityZone zone) {
    switch (zone) {
      case ActivityZone.critical:
        return 'Critical';
      case ActivityZone.sedentary:
        return 'Sedentary';
      case ActivityZone.lowActive:
        return 'Low Active';
      case ActivityZone.moderate:
        return 'Moderate';
      case ActivityZone.active:
        return 'Active';
      case ActivityZone.optimal:
        return 'Optimal';
    }
  }

  static IconData getZoneIcon(ActivityZone zone) {
    switch (zone) {
      case ActivityZone.critical:
        return Icons.warning_rounded;
      case ActivityZone.sedentary:
        return Icons.airline_seat_recline_normal_rounded;
      case ActivityZone.lowActive:
        return Icons.directions_walk_rounded;
      case ActivityZone.moderate:
        return Icons.trending_up_rounded;
      case ActivityZone.active:
        return Icons.directions_run_rounded;
      case ActivityZone.optimal:
        return Icons.emoji_events_rounded;
    }
  }
}

/// Activity zones — ordered from worst to best.
enum ActivityZone {
  critical,
  sedentary,
  lowActive,
  moderate,
  active,
  optimal,
}
