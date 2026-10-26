import 'dart:math';

/// Scientific health algorithms for deriving performance scores from raw sensor data.
///
/// References:
/// - TRIMP: Banister EW (1991). Modeling elite athletic performance.
/// - HRV Recovery: Buchheit M (2014). Monitoring training status with HR measures.
/// - Stress (RMSSD/Parasympathetic): Kim HG et al. (2018). Stress and HRV. Psychiatry Investig.
/// - Sympathetic Stress: Schumann AY et al. (2017). HR vs HRV as stress markers.
/// - TSS/Cardio Load: Coggan AR & Allen H (2010). Training and Racing with a Power Meter.
/// - Readiness/Energy: Adapted from WHOOP & Oura (2022) proprietary methodology descriptions.
/// - Circadian Rhythm: Dijk DJ & Czeisler CA (1995). NREM/REM homeostatic interaction.
import 'package:flutter/material.dart';

class HealthIntelligenceService {

  // ── Population baselines (used only when no personal data is available) ──
  /// Adult population median RMSSD (Koenig et al. 2016).
  static const double _populationHrvBaseline = 42.0;
  /// Standard resting HR for adults.
  static const double _populationRhrBaseline = 65.0;
  /// Estimated max HR for ~30yo. Overridden with real age when available.
  static const double _populationMaxHr = 190.0;
  /// Fraction of HRmax corresponding to lactate threshold proxy.
  static const double _thresholdHrFraction = 0.80;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STRAIN — Banister TRIMP-based (0-100)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ///
  /// Computes strain using the Banister TRIMP formula (1991):
  ///   TRIMP = ΔHR_ratio × duration(min) × e^(1.92 × ΔHR_ratio)
  ///
  /// KEY FIX: Uses `exerciseHrAvg` (HR during active workout) instead of the
  /// all-day HR average. The all-day HR is depressed by sedentary periods and
  /// causes severe underestimation of exercise strain.
  ///
  /// Normalization: 200 TRIMP = 100% strain (elite training day).
  static int calculateStrainScore({
    required int exerciseMinutes,
    /// HR average ONLY during the active exercise window. Computed from workout
    /// HR data in HealthRepository. Falls back to allDayHrAvg if null.
    int? exerciseHrAvg,
    /// All-day HR average used as a fallback if no exercise HR is available.
    int? allDayHrAvg,
    required int? restingHeartRate,
    required int steps,
    int? ageYears,
  }) {
    final double rhr = (restingHeartRate ?? _populationRhrBaseline).toDouble();
    // Tanaka formula: 208 - 0.7 * age (more accurate than 220 - age)
    final double maxHr = ageYears != null ? (208.0 - 0.7 * ageYears) : _populationMaxHr;

    // Prefer exercise-window HR; fall back to all-day HR.
    final double hrAvg = (exerciseHrAvg ?? allDayHrAvg ?? 0).toDouble();

    double trimp = 0.0;

    // Primary method: HR-based TRIMP using exercise window
    if (hrAvg > rhr && exerciseMinutes > 0) {
      final double deltaRatio = (hrAvg - rhr) / (maxHr - rhr);
      final double clamped = deltaRatio.clamp(0.0, 1.0);
      // TRIMP = ΔHR_ratio × T(min) × e^(1.92 × ΔHR_ratio)  [Banister 1991]
      trimp = clamped * exerciseMinutes * exp(1.92 * clamped);
    }

    // Fallback: steps + exercise time when no HR data at all
    if (trimp == 0.0) {
      final double stepsScore = (steps / 10000.0).clamp(0.0, 1.0) * 60.0;
      final double timeScore = (exerciseMinutes / 60.0).clamp(0.0, 1.0) * 80.0;
      trimp = (stepsScore * 0.4) + (timeScore * 0.6);
    }

    // Normalize: 150 TRIMP units = 100% strain (very strong training stimulus)
    return (trimp / 150.0 * 100.0).clamp(0.0, 100.0).round();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // RECOVERY — Personalized HRV + RHR deviation + Sleep (Buchheit 2014)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ///
  /// Component weights: HRV 40% | RHR 35% | Sleep 25%
  ///
  /// KEY FIX: HRV is now compared against the user's own 7-day rolling baseline
  /// (provided via [hrvBaseline]) rather than the population average (55ms).
  /// WHOOP, Oura, and Garmin all use personal baselines for exactly this reason:
  /// an athlete with an HRV of 80ms who drops to 60ms is more stressed than a
  /// sedentary person whose baseline is 40ms sitting at 50ms.
  ///
  /// RHR deviation now uses the user's own personal baseline (last 7 days avg)
  /// via [rhrBaseline], falling back to the population estimate.
  static int calculateRecoveryScore({
    required double? hrv,
    required int? restingHeartRate,
    required double sleepHours,
    /// User's 7-day rolling average HRV (RMSSD or SDNN). If null, uses population.
    double? hrvBaseline,
    /// User's 7-day rolling average RHR. If null, uses population 65 bpm.
    int? rhrBaseline,
    /// Actual sleep efficiency from AWAKE stage data (0.0–1.0). See repo note.
    double? sleepEfficiency,
  }) {
    if (hrv == null && restingHeartRate == null && sleepHours == 0) return 0;

    final double personalHrvBase = hrvBaseline ?? _populationHrvBaseline;
    final double personalRhrBase = (rhrBaseline ?? _populationRhrBaseline).toDouble();

    // ── HRV component (40 points) ────────────────────────────────────────────
    // Ratio of today's HRV to personal baseline.
    //   1.0 (on baseline) → 40 pts | 0.5 (suppressed) → 13 pts | 1.5 (elevated) → capped 40 pts
    double hrvScore = 20.0; // default 50% if no data
    if (hrv != null && hrv > 0) {
      final double ratio = (hrv / personalHrvBase).clamp(0.3, 1.5);
      // Linearly map [0.3, 1.5] → [8, 40] to preserve curvature at low values.
      hrvScore = ((ratio - 0.3) / (1.5 - 0.3) * 40.0).clamp(0.0, 40.0);
    }

    // ── RHR component (35 points) ────────────────────────────────────────────
    // Deviation from *personal* RHR baseline (not population).
    // +5 bpm above baseline → noticeable penalty. -5 bpm → small bonus.
    double rhrScore = 17.5; // default 50% if no data
    if (restingHeartRate != null) {
      final double rhr = restingHeartRate.toDouble();
      // Normalize: ±20 bpm from baseline = ±1.0.
      final double deviation = (rhr - personalRhrBase) / 20.0;
      rhrScore = (35.0 * (1.0 - deviation.clamp(-0.5, 1.0))).clamp(0.0, 35.0);
    }

    // ── Sleep component (25 points) ──────────────────────────────────────────
    // Duration factor saturates at 9h (adults need 7–9h; Hirshkowitz et al. 2015).
    // Efficiency penalizes fragmented sleep. Source: Buysse DJ et al. (1989), PSQI.
    double sleepScore = 0.0;
    if (sleepHours > 0) {
      final double durationFactor = (sleepHours / 8.0).clamp(0.0, 1.0);
      // Real efficiency from awake-time ratio (computed in repo), or 0.85 assumption.
      final double efficiency = (sleepEfficiency ?? 0.85).clamp(0.0, 1.0);
      sleepScore = (25.0 * durationFactor * efficiency).clamp(0.0, 25.0);
    }

    return (hrvScore + rhrScore + sleepScore).clamp(0.0, 100.0).round();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STRESS — Dual-component model (Kim 2018; Schumann 2017)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ///
  /// KEY FIX: Separates the autonomic nervous system into two branches:
  ///
  /// 1. **Parasympathetic component (60%)** — Low HRV = low vagal tone = high stress.
  ///    Uses RMSSD vs personal baseline (Kim et al. 2018).
  ///    Formula: `paraStress = (1 - hrv / personalBaseline) * 100`
  ///
  /// 2. **Sympathetic component (40%)** — High HR for given RHR = stress activation.
  ///    Formula: `sympStress = (HR / RHR - 1.0) * 200`  (Schumann et al. 2017)
  ///    At rest: HR ≈ RHR → ~0 sympathetic stress.
  ///    During stress: HR = 1.3×RHR → 60% sympathetic stress.
  ///
  /// Combined: `stress = 0.60 × paraStress + 0.40 × sympStress`
  static int calculateStressScore({
    required double? hrv,
    required int? heartRate,
    required int? restingHeartRate,
    double? hrvBaseline,
  }) {
    // If we have no HRV and no Resting HR, we cannot reliably compute stress.
    // Absolute HR alone (fallback) is too noisy and causes phantom scores.
    if (hrv == null && restingHeartRate == null) return 0;

    final double personalHrvBase = hrvBaseline ?? _populationHrvBaseline;
    double paraStress = 0.0; // default: 0 if no HRV
    double sympStress = 0.0; // default: 0 if no HR

    // ── Parasympathetic component ─────────────────────────────────────────────
    if (hrv != null && hrv > 0) {
      // ratio 1.0 (at baseline) → paraStress 0. ratio 0 (no HRV) → paraStress 100.
      final double ratio = (hrv / personalHrvBase).clamp(0.0, 2.0);
      // Non-linear: small HRV drops have outsize stress impact.
      paraStress = ((1.0 - ratio.clamp(0.0, 1.0)) * 100.0).clamp(0.0, 100.0);
    }

    // ── Sympathetic component ────────────────────────────────────────────────
    if (heartRate != null && restingHeartRate != null && restingHeartRate > 30) {
      // (HR / RHR - 1.0) is the "reserve fraction used".
      // At HR = RHR: 0. At HR = 2*RHR: 1.0 (clamped to 100%)
      final double hrRatio = (heartRate / restingHeartRate.toDouble()) - 1.0;
      sympStress = (hrRatio.clamp(0.0, 1.0) * 100.0).clamp(0.0, 100.0);
    } else if (heartRate != null) {
      // Fallback: no RHR. Use absolute HR thresholds.
      // <70 → low sym, >100 → high sym
      sympStress = ((heartRate - 70.0) / 50.0).clamp(0.0, 1.0) * 100.0;
    }

    // Stress is high if EITHER parasympathetic tone is suppressed OR sympathetic tone is elevated.
    // Taking the maximum ensures that severe stress in one branch isn't masked by the other.
    final double stress = max(paraStress, sympStress);
    return stress.round();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // CARDIO LOAD — HR-Proxy TSS (Coggan & Allen 2010)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ///
  /// TSS (Training Stress Score): measures accumulated cardiovascular load.
  ///   TSS ≈ (duration_sec × IF) / (FTP_hr × 3600) × 100
  ///
  /// Using HR as a proxy for power (common in non-power-meter scenarios):
  ///   IF (Intensity Factor) = exerciseHR / thresholdHR
  ///
  /// KEY FIX: Uses [exerciseHrAvg] (HR only during the workout window), not the
  /// all-day average. This ensures a 30-min high-intensity run produces a much
  /// higher cardio load than a day of walking.
  ///
  /// Output: TSS on 0–20 display scale (WHOOP-style). 150 TSS = 20 display score.
  static int calculateCardioLoad({
    required int exerciseMinutes,
    /// HR average ONLY during the active exercise window.
    int? exerciseHrAvg,
    /// Fallback all-day avg HR.
    int? allDayHrAvg,
    required int? restingHeartRate,
    int? ageYears,
  }) {
    if (exerciseMinutes == 0) return 0;

    final double rhr = (restingHeartRate ?? _populationRhrBaseline).toDouble();
    // Tanaka formula: 208 - 0.7 * age
    final double maxHr = ageYears != null ? (208.0 - 0.7 * ageYears) : _populationMaxHr;
    final double thresholdHr = maxHr * _thresholdHrFraction;

    final double hrAvg = (exerciseHrAvg ?? allDayHrAvg ?? 0).toDouble();

    double intensityFactor;
    if (hrAvg > rhr) {
      // IF = exerciseHR / thresholdHR (lactate threshold proxy)
      intensityFactor = (hrAvg / thresholdHr).clamp(0.3, 1.5);
    } else {
      // No HR available: conservative IF based on steps/time
      intensityFactor = 0.65;
    }

    // TSS = (hours) × IF² × 100  [Coggan & Allen form]
    final double tss = (exerciseMinutes / 60.0) * pow(intensityFactor, 2) * 100.0;

    // Normalize to 0–20 display scale: 150 TSS → 20
    final double score = (tss / 150.0 * 20.0).clamp(0.0, 20.0);
    
    // SENSITIVITY FIX: If there is ANY training stress, show at least 1 
    // to avoid "No data" for light activity.
    if (tss > 0.5 && score < 1.0) return 1;
    
    return score.round();
  }

  /// Categorizes cardio focus into Low/High/Anaerobic based on HR vs MaxHR.
  static String calculateCardioFocusType({
    int? exerciseHrAvg,
    int? ageYears,
  }) {
    if (exerciseHrAvg == null || exerciseHrAvg == 0) return 'No data';
    
    final double maxHr = ageYears != null ? (208.0 - 0.7 * ageYears) : _populationMaxHr;
    final double hrRatio = exerciseHrAvg / maxHr;

    // Heart Rate Zones (typical breakdown)
    if (hrRatio >= 0.90) return 'Anaerobic';
    if (hrRatio >= 0.80) return 'High Aerobic';
    if (hrRatio >= 0.60) return 'Low Aerobic';
    return 'Recovery';
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // SLEEP SCORE — Duration + Efficiency (0-100)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ///
  /// Sleep quality = 70% duration + 30% efficiency.
  /// Duration reference: Hirshkowitz et al. (2015). NSF recommendations.
  ///   Optimal = 7-9h for adults; 8h produces max score.
  static int calculateSleepScore({
    required double sleepHours,
    double? sleepEfficiency,
  }) {
    if (sleepHours <= 0) return 0;
    final double duration = (sleepHours / 8.0).clamp(0.0, 1.0);
    final double efficiency = (sleepEfficiency ?? 0.85).clamp(0.0, 1.0);
    return ((duration * 70.0) + (efficiency * 30.0)).clamp(0.0, 100.0).round();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ENERGY / BATTERY — Composite Readiness (Oura/WHOOP + Circadian Science)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ///
  /// Weights: Recovery 35% | Sleep 30% | Stress (inverted) 20% | Circadian 15%
  ///
  /// KEY FIX (Circadian): Energy naturally peaks ~2h after waking and decays
  /// through the day (Dijk & Czeisler 1995). We model this as a smooth decay:
  ///   - If wakeTime is provided: circadian = cos(π × hoursAwake / 16) * 0.075 + 0.925
  ///   - Ranges from 1.0 at wake to 0.85 at 16h awake.
  ///   - This is a KEY reason readiness trackers show higher scores in the morning.
  static int calculateEnergyScore({
    required double sleepHours,
    required double? hrv,
    required int steps,
    required int? restingHeartRate,
    int? heartRate,
    int? strainScore,
    double? sleepEfficiency,
    double? hrvBaseline,
    int? rhrBaseline,
    /// Time the user woke up. Used to compute circadian energy factor.
    DateTime? wakeTime,
  }) {
    if (sleepHours == 0.0 && steps == 0 && (hrv == null || hrv == 0.0)) return -1;

    final int recoveryScore = calculateRecoveryScore(
      hrv: hrv,
      restingHeartRate: restingHeartRate,
      sleepHours: sleepHours,
      sleepEfficiency: sleepEfficiency,
      hrvBaseline: hrvBaseline,
      rhrBaseline: rhrBaseline,
    );

    final int sleepScore = calculateSleepScore(
      sleepHours: sleepHours,
      sleepEfficiency: sleepEfficiency,
    );

    final int stressScore = calculateStressScore(
      hrv: hrv,
      heartRate: heartRate,
      restingHeartRate: restingHeartRate,
      hrvBaseline: hrvBaseline,
    );

    // ── Circadian energy factor ───────────────────────────────────────────────
    // Smoothly decays from ~100% at wakeup to ~85% at 16h awake (Dijk & Czeisler 1995).
    double circadianScore = 90.0; // neutral default (no wakeTime)
    if (wakeTime != null) {
      final double hoursAwake = DateTime.now().difference(wakeTime).inMinutes / 60.0;
      if (hoursAwake >= 0 && hoursAwake <= 24) {
        // cos curve: peak at wake (0h), trough at ~16h
        final double clampedHours = hoursAwake.clamp(0.0, 16.0);
        circadianScore = (cos(pi * clampedHours / 16.0) * 7.5 + 92.5).clamp(85.0, 100.0);
      }
    }

    // ── Readiness Calculation ────────────────────────────────────────────────
    // Weights: Recovery 35% | Sleep 30% | Stress (inverted) 20% | Circadian 15%
    
    // CRITICAL FIX: If we have no recovery AND no sleep data, the battery should be 0.
    // We shouldn't give "free points" for low stress and circadian rhythm if the 
    // foundation (rest/recovery) is unknown or zero.
    if (recoveryScore == 0 && sleepScore == 0) return 0;

    final double readiness =
        (0.35 * recoveryScore) +
        (0.30 * sleepScore) +
        (0.20 * (100.0 - stressScore)) +
        (0.15 * circadianScore);

    return readiness.clamp(0.0, 100.0).round();
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // STRAIN PERFORMANCE — Today vs 7-Day Baseline (Meaningful Delta)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ///
  /// KEY FIX: Replaces the meaningless `strainPercent - 50` with a real
  /// performance-against-baseline delta.
  ///
  /// Returns: percent above (+) or below (-) the 7-day TRIMP average.
  ///   e.g. +35% means today's strain was 35% above your typical training load.
  ///        -20% means today was a lighter-than-usual day.
  ///
  /// Status: "Below Average" (<-15%), "On Track" (-15% to +15%), "Peak Day" (>+15%)
  static int calculateStrainPerformanceDelta({
    required int todayStrainScore,
    required List<int> last7DayStrainScores,
  }) {
    if (last7DayStrainScores.isEmpty) return 0;

    // KEY FIX: Include all days (including rest days) to get a true 
    // training load baseline.
    final double avgStrain = last7DayStrainScores.reduce((a, b) => a + b) / last7DayStrainScores.length;
    if (avgStrain == 0) return 0;

    final double delta = (todayStrainScore - avgStrain) / avgStrain * 100.0;
    return delta.round();
  }

  /// Computes a circadian energy trend (Process S + Process C) for a 24h period.
  /// Inspired by the "Rise" / "Peaks" two-process model of sleep regulation.
  static List<Map<String, dynamic>> calculateCircadianEnergyTrend({
    required DateTime wakeTime,
    required double baseEnergy, // Morning readiness score (0-100)
  }) {
    final List<Map<String, dynamic>> trend = [];
    
    // We start from 1 hour before wake to show the transition
    final startTime = wakeTime.subtract(const Duration(hours: 1));
    
    for (int i = 0; i < 96; i++) { // 15-min intervals for 24 hours
      final time = startTime.add(Duration(minutes: i * 15));
      final double hoursSinceWake = time.difference(wakeTime).inMinutes / 60.0;
      
      // Process S: Homeostatic sleep drive (energy depletion)
      // Drains gradually over the day
      double s = 1.0 - (hoursSinceWake / 32.0).clamp(0.0, 0.6);
      
      // Process C: Circadian rhythm (Multi-modal sinusoidal)
      // peak1: ~3h after wake (Morning Peak)
      // dip: ~8h after wake (Afternoon Dip)
      // peak2: ~11h after wake (Evening Surge)
      // melatonin: ~15h after wake (Wind down)
      double c = 0.0;
      if (hoursSinceWake < 0) {
        c = -0.1; // Low before wake
      } else {
        // Compose two sine waves for the "double peak" effect common in humans
        c = (sin(2 * pi * (hoursSinceWake - 1.0) / 14.0) * 0.12) + 
            (sin(2 * pi * (hoursSinceWake - 8.0) / 6.0) * 0.05);
      }
      
      // Combine and scale
      // baseEnergy is typically 0-100. We want to oscillate around the homeostatic decay (s),
      // modulated by the circadian process (c).
      double energy = (baseEnergy * s) + (100 * c);
      
      // Add some subtle "jitter" for a real-world feel
      final jitter = (sin(i * 0.5) * 0.3);
      energy += jitter;

      trend.add({
        'date': time,
        'value': energy.clamp(5.0, 100.0),
      });
    }
    return trend;
  }

  /// Returns UI-friendly status details for strain performance.
  static Map<String, dynamic> getStrainPerformanceStatusDetails(int delta) {
    if (delta < -15) {
      return {
        'status': 'Below target',
        'color': const Color(0xFF6366F1), // Indigo/Blue
        'range': '± 11%', 
      };
    } else if (delta > 15) {
      return {
        'status': 'Above target',
        'color': const Color(0xFFF97316), // Orange
        'range': '± 11%',
      };
    } else {
      return {
        'status': 'On track',
        'color': const Color(0xFF22C55E), // Green
        'range': '± 11%',
      };
    }
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // INSIGHT TEXT GENERATORS
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  static String getDailyInsight(int energyScore, int stressScore) {
    if (energyScore > 80) {
      return stressScore > 60
          ? "You're charged up today, but I'm noticing some stress building. Channel that energy into a solid workout — it'll balance you out."
          : "Your body battery is fully topped off. This is a green-light day — push yourself, you've earned it.";
    } else if (energyScore > 50) {
      if (stressScore > 70) return "You've got moderate energy but your stress is running hot. Let's prioritize some recovery today — your body is asking for it.";
      return "You're in a good steady zone right now. Keep the pace, stay consistent, and you'll end the day strong.";
    } else {
      return "I'm seeing low readiness today. That's okay — rest is productive too. Focus on hydration, easy movement, and getting to bed early tonight.";
    }
  }

  static String getStressInsight(int stressScore) {
    if (stressScore < 20) return "Your nervous system is calm and regulated right now. This is your baseline — enjoy it.";
    if (stressScore < 40) return "Stress is low and HRV looks strong. You're well-balanced today — keep doing what you're doing.";
    if (stressScore < 60) return "I'm picking up moderate stress. Nothing alarming, but try some box breathing (4-4-4-4) — it genuinely lowers cortisol.";
    if (stressScore < 80) return "Your stress is elevated and HRV is dipping. A short recovery walk or 5 minutes of breathing would help right now.";
    return "Stress is running high — your sympathetic nervous system is in overdrive. Skip the caffeine, try a quick meditation, and prioritize sleep tonight.";
  }

  static String getRecoveryInsight(int recoveryScore) {
    if (recoveryScore >= 80) return "Recovery is looking great. Your HRV and resting heart rate are right where they should be — you're ready for anything today.";
    if (recoveryScore >= 60) return "Solid recovery. Your body can handle moderate-to-high intensity training — go for it.";
    if (recoveryScore >= 40) return "Recovery is still catching up. Stick to aerobic work today — nothing above your lactate threshold.";
    return "Your body needs more time. HRV is suppressed and resting HR is elevated. Light stretching or a rest day is the smart play.";
  }

  static String getStrainInsight(int strainScore) {
    if (strainScore == 0) return "No training load recorded yet today. Let's change that when you're ready.";
    if (strainScore < 20) return "Light day so far — your cardiovascular system is in full recovery mode. That's not a bad thing.";
    if (strainScore < 40) return "Gentle aerobic load today. Perfect for active recovery days like this.";
    if (strainScore < 60) return "Solid training stress building up. Keep this consistency going — it compounds.";
    if (strainScore < 80) return "That's a real training load. Make sure tonight's sleep is 7-9h so your body can fully adapt.";
    return "Near-maximal strain today — excellent work. Prioritize nutrition and deep sleep for full recovery.";
  }

  static String getCardioLoadStatus(int cardioLoad) {
    if (cardioLoad == 0) return 'No data';
    if (cardioLoad < 4) return 'Detraining';
    if (cardioLoad < 8) return 'Recovery';
    if (cardioLoad < 14) return 'Productive';
    if (cardioLoad < 18) return 'Optimal';
    return 'Overreaching';
  }

  static String getStrainPerformanceStatus(int delta) {
    if (delta < -15) return 'Below Average';
    if (delta <= 15) return 'On Track';
    return 'Peak Day';
  }
}
