import '../data/health_repository.dart';
import 'health_intelligence_service.dart';
import 'shared_health_cache.dart';

/// Aggregates complete wearable history from [HealthRepository] into a
/// structured text block suitable for injection into the AI system prompt.
class WearableContextService {
  final HealthRepository _repo;

  WearableContextService(this._repo);

  /// Builds a comprehensive wearable context string.
  /// Returns an empty string if no meaningful data is available.
  ///
  /// If [cache] is provided, uses pre-fetched history data instead of
  /// making fresh database calls. This avoids duplicate fetches when
  /// CorrelationEngine also needs the same data.
  Future<String> buildContext({SharedHealthCache? cache}) async {
    final buf = StringBuffer();
    buf.writeln('=== WEARABLE DATA (REAL-TIME SENSOR FEED) ===');
    buf.writeln('The following is real physiological data from the user\'s wearable device.');
    buf.writeln('Use this data to ground every answer in the user\'s actual body state.');
    buf.writeln('');

    bool hasData = false;

    // ── 1. Today's Snapshot ──
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final metrics = await _repo.getDailyMetrics(
        startTime: startOfDay,
        endTime: now,
      );

      final steps = metrics['steps'] as int? ?? 0;
      final hr = metrics['heartRate'] as int? ?? 0;
      final hrAvg = metrics['heartRateAvg'] as int? ?? 0;
      final sleepHours = metrics['sleepHours'] as double? ?? 0;
      final sleepEff = metrics['sleepEfficiency'] as double? ?? 0;
      final hrv = metrics['hrv'] as double?;
      final rhr = metrics['restingHeartRate'] as int?;
      final spo2 = metrics['bloodOxygen'] as int?;
      final exerciseMin = metrics['exerciseMinutes'] as int? ?? 0;
      final activeEnergy = metrics['activeEnergy'] as int? ?? 0;
      final temp = metrics['skinTemperature'] as double?;
      final rr = metrics['respiratoryRate'] as double?;

      if (steps > 0 || hr > 0 || sleepHours > 0) hasData = true;

      // Compute today's derived scores
      final age = await _repo.getUserAge();
      final exHrAvg = await _repo.getWorkoutHrAvg(now);
      final hrvBaseline = await _repo.getHrvBaseline();
      final rhrBaseline = await _repo.getRhrBaseline();

      final strainScore = HealthIntelligenceService.calculateStrainScore(
        exerciseMinutes: exerciseMin,
        exerciseHrAvg: exHrAvg,
        allDayHrAvg: hrAvg > 0 ? hrAvg : null,
        restingHeartRate: rhr,
        steps: steps,
        ageYears: age,
      );

      final recoveryScore = HealthIntelligenceService.calculateRecoveryScore(
        hrv: hrv,
        restingHeartRate: rhr,
        sleepHours: sleepHours,
        hrvBaseline: hrvBaseline,
        rhrBaseline: rhrBaseline,
        sleepEfficiency: sleepEff > 0 ? sleepEff : null,
      );

      final stressScore = HealthIntelligenceService.calculateStressScore(
        hrv: hrv,
        heartRate: hr > 0 ? hr : null,
        restingHeartRate: rhr,
        hrvBaseline: hrvBaseline,
      );

      final sleepScore = HealthIntelligenceService.calculateSleepScore(
        sleepHours: sleepHours,
        sleepEfficiency: sleepEff > 0 ? sleepEff : null,
      );

      final energyScore = HealthIntelligenceService.calculateEnergyScore(
        hrv: hrv,
        sleepHours: sleepHours,
        restingHeartRate: rhr,
        heartRate: hr > 0 ? hr : null,
        steps: steps,
        strainScore: strainScore,
        sleepEfficiency: sleepEff > 0 ? sleepEff : null,
        hrvBaseline: hrvBaseline,
        rhrBaseline: rhrBaseline,
      );

      buf.writeln('── TODAY\'S LIVE SNAPSHOT ──');
      buf.writeln('Steps: $steps | Exercise: ${exerciseMin}min | Active Energy: ${activeEnergy}kcal');
      buf.writeln('Heart Rate: ${hr > 0 ? "$hr bpm" : "N/A"} | Avg HR: ${hrAvg > 0 ? "$hrAvg bpm" : "N/A"}');
      buf.writeln('RHR: ${rhr != null ? "$rhr bpm" : "N/A"} | HRV: ${hrv != null ? "${hrv.toStringAsFixed(1)} ms" : "N/A"}');
      buf.writeln('Sleep: ${sleepHours.toStringAsFixed(1)}h | Efficiency: ${(sleepEff * 100).toStringAsFixed(0)}%');
      if (spo2 != null) buf.writeln('SpO2: $spo2%');
      if (temp != null) buf.writeln('Skin Temp: ${temp.toStringAsFixed(1)}°C');
      if (rr != null) buf.writeln('Respiratory Rate: ${rr.toStringAsFixed(1)} breaths/min');
      buf.writeln('');
      buf.writeln('── COMPUTED SCORES (TODAY) ──');
      buf.writeln('Strain: $strainScore% | Recovery: $recoveryScore% | Stress: $stressScore/100');
      buf.writeln('Sleep Score: $sleepScore% | Energy: $energyScore%');
      buf.writeln('');

      // Personal baselines
      buf.writeln('── PERSONAL BASELINES (7-day rolling) ──');
      buf.writeln('HRV Baseline: ${hrvBaseline != null ? "${hrvBaseline.toStringAsFixed(1)} ms" : "N/A"}');
      buf.writeln('RHR Baseline: ${rhrBaseline != null ? "$rhrBaseline bpm" : "N/A"}');
      buf.writeln('');
    } catch (e) {
      print('WearableContextService: Today snapshot failed: $e');
    }

    // ── 2-9. Use pre-fetched cache if available, otherwise fetch fresh ──
    try {
      final data = cache ?? await SharedHealthCache.fetch(_repo);

      final sleepHistory = data.sleepHistory;
      final hrvHistory = data.hrvHistory;
      final rhrHistory = data.rhrHistory;
      final strainHistory = data.strainHistory;
      final spo2History = data.spo2History;
      final energyHistory = data.energyHistory;
      final cardioHistory = data.cardioHistory;
      final workouts = data.workoutHistory;

      // Sleep
      if (sleepHistory.isNotEmpty) {
        hasData = true;
        buf.writeln('── SLEEP HISTORY (14 days, hours per night) ──');
        for (final entry in sleepHistory) {
          buf.writeln('${_formatDate(entry['date'])}: ${(entry['value'] as num).toStringAsFixed(1)}h');
        }
        buf.writeln('');
      }

      // HRV
      if (hrvHistory.isNotEmpty) {
        hasData = true;
        buf.writeln('── HRV TREND (14 days, ms) ──');
        for (final entry in hrvHistory) {
          buf.writeln('${_formatDate(entry['date'])}: ${(entry['value'] as num).toStringAsFixed(1)} ms');
        }
        buf.writeln('');
      }

      // RHR
      if (rhrHistory.isNotEmpty) {
        hasData = true;
        buf.writeln('── RHR TREND (14 days, bpm) ──');
        for (final entry in rhrHistory) {
          buf.writeln('${_formatDate(entry['date'])}: ${(entry['value'] as num).round()} bpm');
        }
        buf.writeln('');
      }

      // Strain
      if (strainHistory.isNotEmpty && strainHistory.any((s) => s > 0)) {
        hasData = true;
        buf.writeln('── STRAIN HISTORY (last 6 days, %) ──');
        for (int i = 0; i < strainHistory.length; i++) {
          buf.writeln('${strainHistory.length - i}d ago: ${strainHistory[i]}%');
        }
        buf.writeln('');
      }

      // SpO2
      if (spo2History.isNotEmpty) {
        hasData = true;
        buf.writeln('── SpO2 HISTORY (7 days, %) ──');
        for (final entry in spo2History) {
          buf.writeln('${_formatDate(entry['date'])}: ${(entry['value'] as num).round()}%');
        }
        buf.writeln('');
      }

      // Active Energy
      if (energyHistory.isNotEmpty) {
        hasData = true;
        buf.writeln('── ACTIVE ENERGY (7 days, kcal) ──');
        for (final entry in energyHistory) {
          buf.writeln('${_formatDate(entry['date'])}: ${(entry['value'] as num).round()} kcal');
        }
        buf.writeln('');
      }

      // Cardio Load
      if (cardioHistory.isNotEmpty) {
        hasData = true;
        buf.writeln('── CARDIO LOAD (14 days, TSS score) ──');
        for (final entry in cardioHistory) {
          buf.writeln('${_formatDate(entry['date'])}: ${entry['value']}');
        }
        buf.writeln('');
      }

      // Workouts
      if (workouts.isNotEmpty) {
        hasData = true;
        buf.writeln('── WORKOUT LOG (last 30 days) ──');
        final capped = workouts.take(15).toList();
        for (final w in capped) {
          final date = w['date'] as String? ?? '';
          final type = w['type'] as String? ?? 'Workout';
          final duration = w['durationMinutes'] as int? ?? 0;
          final cals = w['calories'] as int? ?? 0;
          buf.writeln('$date: $type — ${duration}min, ${cals}kcal');
        }
        if (workouts.length > 15) {
          buf.writeln('... and ${workouts.length - 15} more workouts');
        }
        buf.writeln('');
      }

      // Meditation History
      if (data.meditationHistory.isNotEmpty) {
        hasData = true;
        buf.writeln('── MEDITATION & MINDFULNESS HISTORY (last 14 days) ──');
        for (final m in data.meditationHistory) {
          final date = m['date'] as String? ?? '';
          final mins = m['minutes'] as int? ?? 0;
          final mode = m['mode'] as String? ?? 'void';
          buf.writeln('$date: ${mins}min session (${mode.toUpperCase()} mode)');
        }
        buf.writeln('');
      }
    } catch (e) {
      print('WearableContextService: Parallel history fetch failed: $e');
    }

    buf.writeln('=== END WEARABLE DATA ===');

    if (!hasData) return '';
    return buf.toString();
  }

  String _formatDate(dynamic date) {
    if (date is DateTime) {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    return date.toString();
  }
}
