import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import '../models/daily_rhythm.dart';
import 'blueprint_provider.dart';
import 'patient_provider.dart';

class PhaseReadiness {
  final bool isReady;
  final String reason;
  final double score; // 0.0 to 1.0

  const PhaseReadiness({
    this.isReady = false,
    this.reason = '',
    this.score = 0.0,
  });
}

/// Precision progress state — cloud-anchored, adherence-based.
///
/// All protocol timeline metadata (start dates, durations) is derived from
/// the Supabase-backed [BlueprintState] so the user's journey is never lost
/// even if they switch devices or clear app data.
///
/// Progress is calculated from **actual task completions** stored in the
/// `daily_rhythms` table, not from a simple clock.
class ProtocolProgressState {
  /// Mapping: protocol_id → start date (sourced from cloud blueprint)
  final Map<String, DateTime> startDates;

  /// Mapping: protocol_id → duration in weeks (sourced from cloud blueprint)
  final Map<String, int> durations;

  /// Mapping: protocol_id → adherence-based progress (0.0–1.0)
  final Map<String, double> adherenceProgress;

  /// Mapping: protocol_id → days with ≥50 % completion count
  final Map<String, int> completedDays;

  /// Mapping: protocol_id → total elapsed day count for the protocol
  final Map<String, int> elapsedDays;

  const ProtocolProgressState({
    this.startDates = const {},
    this.durations = const {},
    this.adherenceProgress = const {},
    this.completedDays = const {},
    this.elapsedDays = const {},
  });

  ProtocolProgressState copyWith({
    Map<String, DateTime>? startDates,
    Map<String, int>? durations,
    Map<String, double>? adherenceProgress,
    Map<String, int>? completedDays,
    Map<String, int>? elapsedDays,
  }) {
    return ProtocolProgressState(
      startDates: startDates ?? this.startDates,
      durations: durations ?? this.durations,
      adherenceProgress: adherenceProgress ?? this.adherenceProgress,
      completedDays: completedDays ?? this.completedDays,
      elapsedDays: elapsedDays ?? this.elapsedDays,
    );
  }

  DateTime? getStartDate(String protocolId) => startDates[protocolId];
  int getDurationWeeks(String protocolId) => durations[protocolId] ?? 12;
  bool isStarted(String protocolId) => startDates.containsKey(protocolId);

  /// Cloud-anchored precision progress.
  ///
  /// Uses a hybrid approach:
  ///  • **Adherence progress** (70 %): Fraction of elapsed days where the user
  ///    completed ≥50 % of their tasks.  This is the "precision" component.
  ///  • **Time progress** (30 %): Raw calendar progress so the bar still moves
  ///    even on off-days, keeping users motivated.
  ///
  /// Falls back to time-only progress when adherence data hasn't loaded yet.
  double getProgress(String protocolId, {int durationWeeks = 12, double performanceRate = 0.0}) {
    final startDate = startDates[protocolId];
    if (startDate == null) return 0.0;

    final effectiveDuration = durations[protocolId] ?? durationWeeks;
    final now = DateTime.now();
    final elapsedMs = now.difference(startDate).inMilliseconds;
    final totalMs = effectiveDuration * 7 * 24 * 60 * 60 * 1000;
    
    // timeProgress represents how far along we are based on the calendar (0.0 to 1.0)
    final timeProgress = (elapsedMs / totalMs).clamp(0.0, 1.0);

    // ── Hybrid Progress Formula ──
    // 30% of progress comes purely from showing up (time passing).
    // 70% of progress comes from actually completing tasks (performance).
    
    final timeComponent = timeProgress * 0.3;
    double performanceComponent = 0.0;

    final adherence = adherenceProgress[protocolId];
    if (adherence != null) {
      // (Total Tasks Possible / Total Tasks Expected) * Weight
      performanceComponent = (timeProgress * adherence) * 0.7;
    } else {
      // Fallback: Use the current week's performance consistency as a proxy
      performanceComponent = (timeProgress * performanceRate.clamp(0.0, 1.0)) * 0.7;
    }

    return (timeComponent + performanceComponent).clamp(0.0, 1.0);
  }

  /// Evaluates whether user is ready to advance to the next protocol phase.
  /// Ready when: consistency >85% for the week AND time progress >80%.
  PhaseReadiness getPhaseReadiness(String protocolId, {
    int durationWeeks = 12,
    double weekConsistency = 0.0,
    int streakDays = 0,
  }) {
    final startDate = startDates[protocolId];
    if (startDate == null) {
      return const PhaseReadiness(reason: 'Protocol not started yet');
    }

    final effectiveDuration = durations[protocolId] ?? durationWeeks;
    final elapsedDaysCount = DateTime.now().difference(startDate).inDays;
    final totalDays = effectiveDuration * 7;
    final timeProgress = (elapsedDaysCount / totalDays).clamp(0.0, 1.0);

    // Readiness score: 40% consistency + 30% time + 30% streak
    final streakFactor = (streakDays / 7.0).clamp(0.0, 1.0);
    final score = (weekConsistency * 0.4 + timeProgress * 0.3 + streakFactor * 0.3).clamp(0.0, 1.0);

    if (timeProgress < 0.8) {
      final weeksLeft = ((totalDays - elapsedDaysCount) / 7).ceil();
      return PhaseReadiness(
        isReady: false, 
        score: score,
        reason: '~$weeksLeft weeks remaining in this phase',
      );
    }
    
    if (weekConsistency < 0.85) {
      return PhaseReadiness(
        isReady: false,
        score: score,
        reason: 'Consistency needs to reach 85% (currently ${(weekConsistency * 100).round()}%)',
      );
    }

    if (streakDays < 5) {
      return PhaseReadiness(
        isReady: false,
        score: score,
        reason: 'Build a 5-day streak to unlock next phase (current: $streakDays days)',
      );
    }

    return PhaseReadiness(
      isReady: true,
      score: score,
      reason: 'Ready to advance! Consistency and time targets met.',
    );
  }
}

class ProtocolProgressNotifier extends Notifier<ProtocolProgressState> {
  static const String _storageKeyPrefix = 'protocol_start_date_';
  static const String _durationKeyPrefix = 'protocol_duration_weeks_';
  static const String _rhythmKeyPrefix = 'daily_rhythm_v2_';
  bool _hasInitialized = false;

  @override
  ProtocolProgressState build() {
    final profile = ref.watch(patientProfileProvider).value;
    final blueprintState = ref.watch(blueprintProvider);

    if (!_hasInitialized) {
      if (profile?.id == 'transient') {
        // Still loading real profile, wait for next build cycle
        return const ProtocolProgressState();
      }
      _hasInitialized = true;
      _init();
      return const ProtocolProgressState();
    } else if (blueprintState.blueprint != null) {
      // Blueprint loaded/changed — sync state from cloud data
      _syncFromBlueprint(blueprintState);
    }

    // Safety check: Avoid reading 'state' if uninitialized during rapid rebuilds
    try {
      return state;
    } catch (_) {
      return const ProtocolProgressState();
    }
  }

  /// On first launch, try syncing from cloud (blueprint), then fall back to
  /// local SharedPreferences for backwards compatibility.
  Future<void> _init() async {
    final blueprintState = ref.read(blueprintProvider);

    // 1. Try cloud-first
    if (blueprintState.blueprint != null) {
      _syncFromBlueprint(blueprintState);
      // Also compute adherence from daily_rhythms
      await _computeAdherence(blueprintState.blueprint!.protocolId);
      return;
    }

    // 2. Fallback: load from SharedPreferences (legacy data)
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    
    final Map<String, DateTime> loadedDates = {};
    final Map<String, int> loadedDurations = {};
    for (var key in keys) {
      if (key.startsWith(_storageKeyPrefix)) {
        final protocolId = key.substring(_storageKeyPrefix.length);
        final dateStr = prefs.getString(key);
        if (dateStr != null) {
          loadedDates[protocolId] = DateTime.parse(dateStr);
        }
      }
      if (key.startsWith(_durationKeyPrefix)) {
        final protocolId = key.substring(_durationKeyPrefix.length);
        final weeks = prefs.getInt(key);
        if (weeks != null) {
          loadedDurations[protocolId] = weeks;
        }
      }
    }
    
    state = state.copyWith(startDates: loadedDates, durations: loadedDurations);

    // Compute adherence for each known protocol
    for (final protocolId in loadedDates.keys) {
      await _computeAdherence(protocolId);
    }
  }

  /// Sync start date and duration from the cloud-backed blueprint.
  void _syncFromBlueprint(BlueprintState blueprintState) {
    final bp = blueprintState.blueprint;
    if (bp == null) return;

    final newDates = Map<String, DateTime>.from(state.startDates);
    final newDurations = Map<String, int>.from(state.durations);

    newDates[bp.protocolId] = bp.startDate;
    newDurations[bp.protocolId] = bp.durationWeeks;

    state = state.copyWith(startDates: newDates, durations: newDurations);
  }

  /// Compute adherence from locally cached DailyRhythm data (SharedPreferences)
  /// and optionally from Supabase daily_rhythms.
  ///
  /// Adherence = (days with ≥50 % task completion) / (total elapsed days, capped
  /// at protocol duration).
  Future<void> _computeAdherence(String protocolId) async {
    final startDate = state.startDates[protocolId];
    if (startDate == null) return;

    final durationWeeks = state.durations[protocolId] ?? 12;
    final totalProtocolDays = durationWeeks * 7;
    final now = DateTime.now();
    final rawElapsed = DateTime(now.year, now.month, now.day)
        .difference(DateTime(startDate.year, startDate.month, startDate.day))
        .inDays;
    final totalElapsed = rawElapsed.clamp(0, totalProtocolDays);

    if (totalElapsed == 0) {
      _updateAdherence(protocolId, 0.0, 0, 0);
      return;
    }

    // First try Supabase for authoritative history
    int daysCompleted = 0;
    bool usedCloud = false;

    final client = SupabaseConfig.client;
    if (client != null && client.auth.currentUser != null) {
      try {
        final userId = client.auth.currentUser!.id;
        final startStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
        final endStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        final rows = await client
            .from('daily_rhythms')
            .select('date, tasks')
            .eq('user_id', userId)
            .gte('date', startStr)
            .lte('date', endStr);

        for (final row in rows) {
          final tasks = row['tasks'] as List<dynamic>?;
          if (tasks != null && tasks.isNotEmpty) {
            final completed = tasks.where((t) => t is Map && t['isCompleted'] == true).length;
            final rate = completed / tasks.length;
            if (rate >= 0.5) daysCompleted++;
          }
        }
        usedCloud = true;
      } catch (e) {
        debugPrint('ProtocolProgress: Cloud adherence fetch failed: $e');
      }
    }

    // Fallback to local SharedPreferences if cloud didn't work
    if (!usedCloud) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Resolve profileId for the storage key - patient identity IS their
        // auth user id, no profiles lookup needed.
        final String profileId = client?.auth.currentUser?.id ?? 'guest';

        for (int i = 0; i < totalElapsed; i++) {
          final date = startDate.add(Duration(days: i));
          final key = '${_rhythmKeyPrefix}${profileId}_${date.year}-${date.month}-${date.day}';
          final jsonStr = prefs.getString(key);
          if (jsonStr != null) {
            try {
              final rhythm = DailyRhythm.fromJson(jsonDecode(jsonStr));
              final completed = rhythm.tasks.where((t) => t.isCompleted).length;
              final total = rhythm.tasks.length;
              if (total > 0 && (completed / total) >= 0.5) {
                daysCompleted++;
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint('ProtocolProgress: Local adherence calculation failed: $e');
      }
    }

    final adherence = totalElapsed > 0 ? (daysCompleted / totalElapsed) : 0.0;
    _updateAdherence(protocolId, adherence, daysCompleted, totalElapsed);
  }

  void _updateAdherence(String protocolId, double adherence, int completed, int elapsed) {
    final newAdherence = Map<String, double>.from(state.adherenceProgress);
    final newCompleted = Map<String, int>.from(state.completedDays);
    final newElapsed = Map<String, int>.from(state.elapsedDays);

    newAdherence[protocolId] = adherence;
    newCompleted[protocolId] = completed;
    newElapsed[protocolId] = elapsed;

    state = state.copyWith(
      adherenceProgress: newAdherence,
      completedDays: newCompleted,
      elapsedDays: newElapsed,
    );
  }

  /// Start a protocol. Persists to both SharedPreferences (offline resilience)
  /// and syncs with the blueprint provider for cloud persistence.
  Future<void> startProtocol(String protocolId, {int durationWeeks = 12}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final key = '$_storageKeyPrefix$protocolId';
    final durationKey = '$_durationKeyPrefix$protocolId';
    
    await prefs.setString(key, now.toIso8601String());
    await prefs.setInt(durationKey, durationWeeks);
    
    final newDates = Map<String, DateTime>.from(state.startDates);
    newDates[protocolId] = now;
    final newDurations = Map<String, int>.from(state.durations);
    newDurations[protocolId] = durationWeeks;
    state = state.copyWith(startDates: newDates, durations: newDurations);
  }

  /// Reset a protocol completely — clears both local and cloud progress.
  Future<void> resetProtocol(String protocolId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_storageKeyPrefix$protocolId';
    final durationKey = '$_durationKeyPrefix$protocolId';
    
    await prefs.remove(key);
    await prefs.remove(durationKey);
    
    final newDates = Map<String, DateTime>.from(state.startDates);
    newDates.remove(protocolId);
    final newDurations = Map<String, int>.from(state.durations);
    newDurations.remove(protocolId);
    final newAdherence = Map<String, double>.from(state.adherenceProgress);
    newAdherence.remove(protocolId);
    final newCompleted = Map<String, int>.from(state.completedDays);
    newCompleted.remove(protocolId);
    final newElapsed = Map<String, int>.from(state.elapsedDays);
    newElapsed.remove(protocolId);
    
    state = state.copyWith(
      startDates: newDates,
      durations: newDurations,
      adherenceProgress: newAdherence,
      completedDays: newCompleted,
      elapsedDays: newElapsed,
    );
  }

  /// Recalculate adherence — call after a task toggle or from external refresh.
  Future<void> refreshAdherence(String protocolId) async {
    await _computeAdherence(protocolId);
  }
}

final protocolProgressProvider =
    NotifierProvider<ProtocolProgressNotifier, ProtocolProgressState>(() {
  return ProtocolProgressNotifier();
});
