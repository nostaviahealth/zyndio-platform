import "../services/watch_service.dart";
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/health_repository.dart';
import '../services/health_intelligence_service.dart';
import '../services/vo2_max_service.dart';
import '../services/hrr_service.dart';
import '../providers/intelligence_provider.dart';
import '../services/notification_scheduler.dart';
import '../services/user_habit_service.dart';
import '../services/gamification_service.dart';
import 'rhythm_provider.dart';
import 'patient_provider.dart';
import 'gamification_provider.dart';
import '../services/correlation_engine.dart';
import '../services/proactive_intelligence_service.dart';
import '../services/meal_watchdog_service.dart';

class WearableSyncState {
  final bool isSyncing;
  final DateTime? lastSynced;
  final WearableSnapshot? snapshot;
  final String? error;
  
  // Extra data for the dashboard
  final List<Map<String, dynamic>> weeklySteps;
  final List<Map<String, dynamic>> hrHistory;
  final List<Map<String, dynamic>> rhrHistory;
  final List<Map<String, dynamic>> hrvHistory;
  final List<Map<String, dynamic>> rrHistory;
  final List<Map<String, dynamic>> spo2History;
  final List<Map<String, dynamic>> sleepHistoryDaily;
  final List<Map<String, dynamic>> activeEnergyHistory;
  final List<Map<String, dynamic>> exerciseMinutesHistory;
  final List<Map<String, dynamic>> skinTempHistory;
  final Map<String, List<double>> cumulativeWorkoutData;
  final double? hrvBaseline;
  final int? rhrBaseline;
  final int? exerciseHrAvg;
  final List<int> weeklyStrains;
  final int? userAge;
  final bool? isMale;
  final double? vo2Max;
  final DateTime? vo2MaxDate;
  final List<Map<String, dynamic>> vo2MaxHistory;
  final String hrrValue;
  final double hrrBpm;
  final String hrrRange;
  final int? lastHr;
  final DateTime? lastHrTime;
  final double? lastHrv;
  final DateTime? lastHrvTime;
  final int? lastStepCountForNudge;
  final DateTime? lastSedentaryNudgeTime;

  WearableSyncState({
    this.isSyncing = false,
    this.lastSynced,
    this.snapshot,
    this.error,
    this.weeklySteps = const [],
    this.hrHistory = const [],
    this.rhrHistory = const [],
    this.hrvHistory = const [],
    this.rrHistory = const [],
    this.spo2History = const [],
    this.sleepHistoryDaily = const [],
    this.activeEnergyHistory = const [],
    this.exerciseMinutesHistory = const [],
    this.skinTempHistory = const [],
    this.cumulativeWorkoutData = const {'current': [], 'previous': []},
    this.hrvBaseline,
    this.rhrBaseline,
    this.exerciseHrAvg,
    this.weeklyStrains = const [],
    this.userAge,
    this.isMale,
    this.vo2Max,
    this.vo2MaxDate,
    this.vo2MaxHistory = const [],
    this.hrrValue = 'No data',
    this.hrrBpm = 0,
    this.hrrRange = 'No range',
    this.lastHr,
    this.lastHrTime,
    this.lastHrv,
    this.lastHrvTime,
    this.lastStepCountForNudge,
    this.lastSedentaryNudgeTime,
  });

  WearableSyncState copyWith({
    bool? isSyncing,
    DateTime? lastSynced,
    WearableSnapshot? snapshot,
    String? error,
    List<Map<String, dynamic>>? weeklySteps,
    List<Map<String, dynamic>>? hrHistory,
    List<Map<String, dynamic>>? rhrHistory,
    List<Map<String, dynamic>>? hrvHistory,
    List<Map<String, dynamic>>? rrHistory,
    List<Map<String, dynamic>>? spo2History,
    List<Map<String, dynamic>>? sleepHistoryDaily,
    List<Map<String, dynamic>>? activeEnergyHistory,
    List<Map<String, dynamic>>? exerciseMinutesHistory,
    List<Map<String, dynamic>>? skinTempHistory,
    Map<String, List<double>>? cumulativeWorkoutData,
    double? hrvBaseline,
    int? rhrBaseline,
    int? exerciseHrAvg,
    List<int>? weeklyStrains,
    int? userAge,
    bool? isMale,
    double? vo2Max,
    DateTime? vo2MaxDate,
    List<Map<String, dynamic>>? vo2MaxHistory,
    String? hrrValue,
    double? hrrBpm,
    String? hrrRange,
    int? lastHr,
    DateTime? lastHrTime,
    double? lastHrv,
    DateTime? lastHrvTime,
    int? lastStepCountForNudge,
    DateTime? lastSedentaryNudgeTime,
  }) {
    return WearableSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSynced: lastSynced ?? this.lastSynced,
      snapshot: snapshot ?? this.snapshot,
      error: error,
      weeklySteps: weeklySteps ?? this.weeklySteps,
      hrHistory: hrHistory ?? this.hrHistory,
      rhrHistory: rhrHistory ?? this.rhrHistory,
      hrvHistory: hrvHistory ?? this.hrvHistory,
      rrHistory: rrHistory ?? this.rrHistory,
      spo2History: spo2History ?? this.spo2History,
      sleepHistoryDaily: sleepHistoryDaily ?? this.sleepHistoryDaily,
      activeEnergyHistory: activeEnergyHistory ?? this.activeEnergyHistory,
      exerciseMinutesHistory: exerciseMinutesHistory ?? this.exerciseMinutesHistory,
      skinTempHistory: skinTempHistory ?? this.skinTempHistory,
      cumulativeWorkoutData: cumulativeWorkoutData ?? this.cumulativeWorkoutData,
      hrvBaseline: hrvBaseline ?? this.hrvBaseline,
      rhrBaseline: rhrBaseline ?? this.rhrBaseline,
      exerciseHrAvg: exerciseHrAvg ?? this.exerciseHrAvg,
      weeklyStrains: weeklyStrains ?? this.weeklyStrains,
      userAge: userAge ?? this.userAge,
      isMale: isMale ?? this.isMale,
      vo2Max: vo2Max ?? this.vo2Max,
      vo2MaxDate: vo2MaxDate ?? this.vo2MaxDate,
      vo2MaxHistory: vo2MaxHistory ?? this.vo2MaxHistory,
      hrrValue: hrrValue ?? this.hrrValue,
      hrrBpm: hrrBpm ?? this.hrrBpm,
      hrrRange: hrrRange ?? this.hrrRange,
      lastHr: lastHr ?? this.lastHr,
      lastHrTime: lastHrTime ?? this.lastHrTime,
      lastHrv: lastHrv ?? this.lastHrv,
      lastHrvTime: lastHrvTime ?? this.lastHrvTime,
      lastStepCountForNudge: lastStepCountForNudge ?? this.lastStepCountForNudge,
      lastSedentaryNudgeTime: lastSedentaryNudgeTime ?? this.lastSedentaryNudgeTime,
    );
  }
}

class WearableSyncNotifier extends AsyncNotifier<WearableSyncState> {
  final HealthRepository _repo = HealthRepository();

  @override
  Future<WearableSyncState> build() async {
    // Initial state
    return WearableSyncState(isSyncing: false);
  }

  Future<void> sync({DateTime? date}) async {
    if (state.value?.isSyncing == true) {
      debugPrint('Sync aborted: already syncing');
      return;
    }

    final targetDate = date ?? DateTime.now();
    debugPrint('Starting wearable sync for date: $targetDate');

    state = AsyncData(state.value?.copyWith(isSyncing: true) ?? WearableSyncState(isSyncing: true));

    try {
      await _repo.configure();
      debugPrint('Health repo configured');

      final bool isLinked = await _repo.isLinked();
      debugPrint('Health repo isLinked: $isLinked');
      if (!isLinked) {
        debugPrint('Sync aborted: not linked');
        state = AsyncData(state.value!.copyWith(isSyncing: false, error: 'Not linked'));
        return;
      }

      final startOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day);
      final endOfDay = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);

      // --- DATE LOGIC GUARD ---
      // If the user selects a past date, we must query UNTIL THE END of that day.
      // If we use targetDate (which is 00:00:00 from the picker), the interval is empty.
      final now = DateTime.now();
      final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;
      final queryEnd = isToday ? now : endOfDay;

      // Fetch core metrics — these are essential, let errors propagate
      final results = await Future.wait([
        _repo.getDailyMetrics(startTime: startOfDay, endTime: queryEnd),
        _repo.getWeeklySteps(days: 365, endTime: queryEnd),
        _repo.getHeartRateHistory(endTime: queryEnd),
        _repo.getExerciseMinutesHistory(days: 365, endTime: queryEnd),
      ]);

      final metrics = results[0] as Map<String, dynamic>;
      final weeklySteps = results[1] as List<Map<String, dynamic>>;
      final hrHistory = results[2] as List<Map<String, dynamic>>;
      final exerciseMinutesHistory = results[3] as List<Map<String, dynamic>>;

      // Fetch 30-day histories — EACH wrapped individually to prevent
      // one unsupported metric from crashing the entire sync.
      // On Android, SKIN_TEMPERATURE, RESPIRATORY_RATE, and SpO2 are
      // frequently unavailable depending on the wearable brand.
      List<Map<String, dynamic>> rhrHist = [];
      List<Map<String, dynamic>> hrvHist = [];
      List<Map<String, dynamic>> rrHist = [];
      List<Map<String, dynamic>> spo2Hist = [];
      List<Map<String, dynamic>> sleepHist = [];
      List<Map<String, dynamic>> activeEnergyHist = [];
      List<Map<String, dynamic>> skinTempHist = [];
      Map<String, List<double>> cumulativeWorkout = {'current': [], 'previous': []};

      try { rhrHist = await _repo.getRhrHistory(days: 365, endTime: queryEnd); } catch (e) { debugPrint('RHR history fetch failed: $e'); }
      try { hrvHist = await _repo.getHrvHistory(days: 365, endTime: queryEnd); } catch (e) { debugPrint('HRV history fetch failed: $e'); }
      try { rrHist = await _repo.getRrHistory(days: 365, endTime: queryEnd); } catch (e) { debugPrint('RR history fetch failed: $e'); }
      try { spo2Hist = await _repo.getSpO2History(days: 365, endTime: queryEnd); } catch (e) { debugPrint('SpO2 history fetch failed: $e'); }
      try { sleepHist = await _repo.getSleepHistory(days: 365, endTime: queryEnd); } catch (e) { debugPrint('Sleep history fetch failed: $e'); }
      try { activeEnergyHist = await _repo.getActiveEnergyHistory(days: 365, endTime: queryEnd); } catch (e) { debugPrint('Active energy history fetch failed: $e'); }
      try { skinTempHist = await _repo.getSkinTempHistory(days: 365, endTime: queryEnd); } catch (e) { debugPrint('Skin temp history fetch failed: $e'); }
      try { cumulativeWorkout = await _repo.getCumulativeWorkoutDuration(periodDays: 30, endTime: queryEnd); } catch (e) { debugPrint('Cumulative workout fetch failed: $e'); }

      // Baselines
      final baselineResults = await Future.wait([
        _repo.getHrvBaseline(days: 7),
        _repo.getRhrBaseline(days: 7),
        _repo.getWorkoutHrAvg(targetDate),
        _repo.getWeeklyStrainHistory(days: 7, endTime: queryEnd),
        _repo.getUserAge(),
      ]);

      // Last bits
      final lastHrData = await _repo.getLatestHeartRateData(queryEnd.subtract(const Duration(hours: 24)), queryEnd);
      final lastHrvData = await _repo.getLatestHrvData(queryEnd.subtract(const Duration(hours: 24)), queryEnd);

      // VO2 Max / HRR
      double? vo2MaxVal;
      DateTime? vo2MaxDate;
      List<Map<String, dynamic>> vo2MaxHist = [];
      String hrrValText = 'No data';
      double hrrBpmVal = 0;
      String hrrRangeText = 'No range';

      if (Platform.isIOS) {
        try {
          final vo2Data = await Vo2MaxService.getVo2Max();
          if (vo2Data != null) {
            vo2MaxVal = vo2Data['value'] as double;
            vo2MaxDate = vo2Data['date'] as DateTime;
          }
          vo2MaxHist = await Vo2MaxService.getVo2MaxHistory(days: 365);
          
          final hrrData = await HrrService.getHrr();
          if (hrrData != null && (hrrData['value'] as num) > 0) {
            hrrBpmVal = hrrData['value'] as double;
            hrrValText = '${hrrBpmVal.round()} bpm';
            hrrRangeText = HrrService.classifyHrr(hrrBpmVal);
          } else {
            // Fallback: Find latest valid HRR from history
            final history = await HrrService.getHrrHistory(days: 30);
            final validHistory = history.where((d) => (d['value'] as num) > 0).toList();
            if (validHistory.isNotEmpty) {
              validHistory.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
              hrrBpmVal = validHistory.last['value'] as double;
              hrrValText = '${hrrBpmVal.round()} bpm';
              hrrRangeText = HrrService.classifyHrr(hrrBpmVal);
            }
          }
        } catch (e) { debugPrint('IOS Sync details failed: $e'); }
      } else {
        try {
          final vo2Data = await _repo.getVo2MaxFromHealthConnect();
          if (vo2Data != null) {
            vo2MaxVal = vo2Data['value'] as double;
            vo2MaxDate = vo2Data['date'] as DateTime;
          }
        } catch (e) { debugPrint('Android Sync details failed: $e'); }
      }

      // Calculate snapshot scores
      final steps = metrics['steps'] as int? ?? 0;
      final hr = metrics['heartRate'] as int? ?? 0;
      final hrAvg = metrics['heartRateAvg'] as int? ?? 0;
      final sleepHours = (metrics['sleepHours'] as num?)?.toDouble() ?? 0.0;
      final sleepEff = (metrics['sleepEfficiency'] as num?)?.toDouble() ?? 0.0;
      final hrv = (metrics['hrv'] as num?)?.toDouble();
      final rhr = metrics['restingHeartRate'] as int?;
      final exerciseMin = metrics['exerciseMinutes'] as int? ?? 0;
      final rr = (metrics['respiratoryRate'] as num?)?.toDouble();
      final spo2 = (metrics['bloodOxygen'] as num?)?.toDouble();
      final skinTemp = (metrics['skinTemperature'] as num?)?.toDouble();
      final activeEnergy = (metrics['activeEnergy'] as num?)?.toDouble() ?? 0.0;
      final sleepSessions = metrics['sleepSessions'] as List<dynamic>? ?? [];
      
      final age = baselineResults[4] as int?;
      final hrvBase = baselineResults[0] as double?;
      final rhrBase = baselineResults[1] as int?;
      final exHrAvg = baselineResults[2] as int?;

      final strain = HealthIntelligenceService.calculateStrainScore(
        exerciseMinutes: exerciseMin, exerciseHrAvg: exHrAvg,
        allDayHrAvg: hrAvg > 0 ? hrAvg : null,
        restingHeartRate: rhr, steps: steps, ageYears: age,
      );
      final recovery = HealthIntelligenceService.calculateRecoveryScore(
        hrv: hrv, restingHeartRate: rhr, sleepHours: sleepHours,
        hrvBaseline: hrvBase, rhrBaseline: rhrBase,
        sleepEfficiency: sleepEff > 0 ? sleepEff : null,
      );
      final stress = HealthIntelligenceService.calculateStressScore(
        hrv: hrv, heartRate: hr > 0 ? hr : null,
        restingHeartRate: rhr, hrvBaseline: hrvBase,
      );
      final sleep = HealthIntelligenceService.calculateSleepScore(
        sleepHours: sleepHours, sleepEfficiency: sleepEff > 0 ? sleepEff : null,
      );
      final energy = HealthIntelligenceService.calculateEnergyScore(
        hrv: hrv, sleepHours: sleepHours, restingHeartRate: rhr,
        heartRate: hr > 0 ? hr : null, steps: steps, strainScore: strain,
        sleepEfficiency: sleepEff > 0 ? sleepEff : null,
        hrvBaseline: hrvBase, rhrBaseline: rhrBase,
      );

      // Calculate daily stress stats from HR samples
      int stressMin = 100;
      int stressMax = 0;
      double stressSum = 0;
      int stressCount = 0;

      for (var point in hrHistory) {
        final hrVal = (point['value'] as num).toInt();
        if (hrVal > 0) {
          final s = HealthIntelligenceService.calculateStressScore(
            hrv: hrv, 
            heartRate: hrVal,
            restingHeartRate: rhr,
            hrvBaseline: hrvBase,
          );
          if (s < stressMin) stressMin = s;
          if (s > stressMax) stressMax = s;
          stressSum += s;
          stressCount++;
        }
      }

      final finalStressAvg = stressCount > 0 ? (stressSum / stressCount).round() : stress;
      final finalStressHigh = stressCount > 0 ? stressMax : stress;
      final finalStressLow = stressCount > 0 ? stressMin : stress;

      WearableSnapshot snapshot = WearableSnapshot(
        strainScore: strain,
        recoveryScore: recovery,
        stressScore: stress,
        stressHigh: finalStressHigh,
        stressLow: finalStressLow,
        stressAvg: finalStressAvg,
        sleepScore: sleep,
        energyScore: energy,
        sleepHours: sleepHours,
        sleepEfficiency: sleepEff,
        hrv: hrv,
        rhr: rhr,
        hrvBaseline: hrvBase,
        rhrBaseline: rhrBase,
        steps: steps,
        exerciseMinutes: exerciseMin,
        respiratoryRate: rr,
        bloodOxygen: spo2,
        skinTemperature: skinTemp,
        vo2Max: vo2MaxVal,
        activeEnergy: activeEnergy,
        heartRateAvg: hrAvg,
      );

      // --- SYNCHRONIZATION GUARD ---
      // Ensure the snapshot metric (Hero value) exactly matches the latest point in the history graph
      // This prevents visual discrepancies where the 1M chart shows a different value than the header

      // HRV Guard
      if (hrvHist.isNotEmpty) {
        // Find if there's a point for today
        for (var point in hrvHist.reversed) {
          final date = point['date'] as DateTime;
          if (date.year == targetDate.year && date.month == targetDate.month && date.day == targetDate.day) {
            snapshot = snapshot.copyWith(hrv: (point['value'] as num).toDouble());
            break;
          }
        }
      }

      // RR Guard
      if (rrHist.isNotEmpty) {
        for (var point in rrHist.reversed) {
          final date = point['date'] as DateTime;
          if (date.year == targetDate.year && date.month == targetDate.month && date.day == targetDate.day) {
            snapshot = snapshot.copyWith(respiratoryRate: (point['value'] as num).toDouble());
            break;
          }
        }
      }

      state = AsyncData(WearableSyncState(
        isSyncing: false,
        lastSynced: DateTime.now(),
        snapshot: snapshot,
        weeklySteps: weeklySteps,
        hrHistory: hrHistory,
        rhrHistory: rhrHist,
        hrvHistory: hrvHist,
        rrHistory: rrHist,
        spo2History: spo2Hist,
        sleepHistoryDaily: sleepHist,
        activeEnergyHistory: activeEnergyHist,
        exerciseMinutesHistory: exerciseMinutesHistory,
        skinTempHistory: skinTempHist,
        cumulativeWorkoutData: cumulativeWorkout,
        hrvBaseline: hrvBase,
        rhrBaseline: rhrBase,
        exerciseHrAvg: exHrAvg,
        weeklyStrains: (baselineResults[3] as List<int>?) ?? [],
        userAge: age,
        isMale: ref.read(patientProfileProvider).value?.questionnaireData?['gender'] == 'Male',
        vo2Max: vo2MaxVal,
        vo2MaxDate: vo2MaxDate,
        vo2MaxHistory: vo2MaxHist,
        hrrValue: hrrValText,
        hrrBpm: hrrBpmVal,
        hrrRange: hrrRangeText,
        lastHr: lastHrData != null ? (lastHrData['value'] as double).round() : null,
        lastHrTime: lastHrData != null ? lastHrData['timestamp'] as DateTime : null,
        lastHrv: lastHrvData != null ? lastHrvData['value'] as double : null,
        lastHrvTime: lastHrvData != null ? lastHrvData['timestamp'] as DateTime : null,
      ));

      // Invalidate the legacy provider to ensure it picks up the latest data too if any part of the app still uses it
      ref.invalidate(wearableStateProvider);

      // Sync to Apple Watch
      if (Platform.isIOS) {
        WatchService.syncStateToWatch(state.value!);
      }

      final profile = ref.read(patientProfileProvider).value;
      final name = profile?.name ?? 'there';
      final firstName = name.split(' ').first;
      final scheduler = NotificationScheduler();

      // ── PILLAR 1 & 2: Correlation Discovery & Proactive Insights ──
      if (isToday) {
        final correlations = await CorrelationEngine.discoverCorrelations(repo: _repo);
        final proactiveService = ProactiveIntelligenceService();
        final habitProfile = await UserHabitService.generateProfile();
        
        await proactiveService.generateAndScheduleInsights(
          snapshot: snapshot,
          correlations: correlations,
          habitProfile: habitProfile,
        );
      }

      // ── PILLAR 3: Check for pending meal validations ──
      if (isToday) {
        await MealWatchdogService.checkPendingSessions(
          currentHR: hr,
          currentHRV: hrv,
          scheduler: scheduler,
          firstName: firstName,
        );
      }

      // 🏋️ Post-Workout Nudge + Auto-Completion (ONLY FOR TODAY)
      if (isToday && exerciseMin > 15) {
        final prevExercise = state.value?.snapshot?.exerciseMinutes ?? 0;
        // Only fire if this is NEW exercise data (not a re-sync of the same session)
        if (exerciseMin > prevExercise + 10) {
          
          // ── ADAPTIVE EVOLUTION ENGINE: Record Workout ──
          UserHabitService.recordWorkoutEvent(DateTime.now(), exerciseMin);
          
          scheduler.firePostWorkoutNudge(
            exerciseMinutes: exerciseMin,
            calories: activeEnergy.round(),
            avgHr: exHrAvg,
            userName: firstName,
          );

          // ✨ ZERO-FRICTION: Auto-complete the next fitness task
          ref.read(dailyRhythmProvider.notifier)
              .autoCompleteRelevantTask('fitness');

          // ── GAMIFICATION: Award XP for workout ──
          final dateStr = '${targetDate.year}-${targetDate.month}-${targetDate.day}';
          ref.read(gamificationProvider.notifier).awardReward(
            RewardType.workoutComplete,
            referenceId: 'workout_$dateStr',
          );
        }
      }

      // ── ADAPTIVE EVOLUTION ENGINE: Record Sleep ──
      if (sleepHours > 0 && sleepSessions.isNotEmpty) {
        try {
          DateTime? bedtime;
          DateTime? waketime;

          // ── GAMIFICATION: Award XP for daily step goal (ONLY FOR TODAY)
          if (isToday && steps >= 10000) {
            final dateStr = '${targetDate.year}-${targetDate.month}-${targetDate.day}';
            ref.read(gamificationProvider.notifier).awardReward(
              RewardType.dailyStepsGoal,
              referenceId: 'steps_$dateStr',
            );
          }
          for (var s in sleepSessions) {
            final start = s.dateFrom as DateTime?;
            final end = s.dateTo as DateTime?;
            if (start != null) {
              if (bedtime == null || start.isBefore(bedtime)) bedtime = start;
            }
            if (end != null) {
              if (waketime == null || end.isAfter(waketime)) waketime = end;
            }
          }
          if (isToday && bedtime != null && waketime != null) {
            final prevSleep = state.value?.snapshot?.sleepHours ?? 0.0;
            if ((sleepHours - prevSleep).abs() > 0.5) {
              UserHabitService.recordSleepEvent(bedtime, waketime, sleepHours);
            }
          }
        } catch (_) {}
      }

      // ═══════════════════════════════════════════════════════
      // PROACTIVE ALERTS — The "Intelligence" Concierge
      // ═══════════════════════════════════════════════════════
      
      // 1. Stress Intervention (Sympathetic Overdrive) (ONLY FOR TODAY)
      if (isToday && finalStressHigh >= 75) {
        scheduler.fireStressIntervention(
          userName: firstName,
          stressScore: finalStressHigh,
        );
      }

      // 2. Sedentary Nudge (Movement Check-in)
      final lastNudgeTime = state.value?.lastSedentaryNudgeTime;
      final lastSteps = state.value?.lastStepCountForNudge ?? 0;
      
      // If we haven't nudged in 90m AND steps are flat (delta < 50) (ONLY FOR TODAY)
      if (isToday && (lastNudgeTime == null || now.difference(lastNudgeTime).inMinutes >= 90)) {
        if (steps > 0 && (steps - lastSteps).abs() < 50) {
           // Don't fire if it's late night (sleeping)
           if (now.hour >= 8 && now.hour < 21) {
             scheduler.fireSedentaryNudge(
               userName: firstName,
               minutesIdle: 90,
             );
             // Update state for next check
             state = AsyncData(state.value!.copyWith(
               lastSedentaryNudgeTime: now,
               lastStepCountForNudge: steps,
             ));
           }
        } else {
           // Steps are moving, update the counter but not the time
           state = AsyncData(state.value!.copyWith(
             lastStepCountForNudge: steps,
           ));
        }
      }

      // 3. Hydration Check (Data-Driven)
      if (steps > 5000 && now.hour > 10 && now.hour < 18) {
        // Simple logic: fire once if we pass 5k steps during workday
        final lastHydrationDate = await _repo.getLastHydrationPromptDate(); 
        if (lastHydrationDate == null || lastHydrationDate.day != now.day) {
          scheduler.fireHydrationNudge(
            userName: firstName,
            currentSteps: steps,
          );
          await _repo.setLastHydrationPromptDate(now);
        }
      }

      // 4. Late-Night Guard
      if (now.hour >= 23) {
        final lastLateNightDate = await _repo.getLastLateNightPromptDate();
        if (lastLateNightDate == null || lastLateNightDate.day != now.day) {
           scheduler.fireLateNightNudge(userName: firstName);
           await _repo.setLastLateNightPromptDate(now);
        }
      }

    } catch (e, stack) {
      debugPrint('Global Sync Error: $e\n$stack');
      state = AsyncData(state.value?.copyWith(isSyncing: false, error: e.toString()) ?? WearableSyncState(isSyncing: false, error: e.toString()));
    }
  }
}

final wearableSyncProvider = AsyncNotifierProvider<WearableSyncNotifier, WearableSyncState>(() {
  return WearableSyncNotifier();
});
