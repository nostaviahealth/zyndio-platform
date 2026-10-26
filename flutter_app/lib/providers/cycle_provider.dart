import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../models/menstrual_log.dart';
import 'patient_provider.dart';

class CycleIntelligenceState {
  final bool isLoading;
  final List<MenstrualLog> logs;
  final CyclePhase currentPhase;
  final int currentDayOfCycle;
  final DateTime? nextPredictedPeriod;
  final String? error;

  CycleIntelligenceState({
    this.isLoading = false,
    this.logs = const [],
    this.currentPhase = CyclePhase.unknown,
    this.currentDayOfCycle = 0,
    this.nextPredictedPeriod,
    this.error,
  });

  CycleIntelligenceState copyWith({
    bool? isLoading,
    List<MenstrualLog>? logs,
    CyclePhase? currentPhase,
    int? currentDayOfCycle,
    DateTime? nextPredictedPeriod,
    String? error,
  }) {
    return CycleIntelligenceState(
      isLoading: isLoading ?? this.isLoading,
      logs: logs ?? this.logs,
      currentPhase: currentPhase ?? this.currentPhase,
      currentDayOfCycle: currentDayOfCycle ?? this.currentDayOfCycle,
      nextPredictedPeriod: nextPredictedPeriod ?? this.nextPredictedPeriod,
      error: error ?? this.error,
    );
  }
}

class CycleIntelligenceNotifier extends Notifier<CycleIntelligenceState> {
  @override
  CycleIntelligenceState build() {
    // Start fetch in background
    Future.microtask(() => fetchLogs());
    return CycleIntelligenceState();
  }

  Future<void> fetchLogs() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = SupabaseConfig.client;
      final userId = SupabaseConfig.currentUser?.id;
      
      if (client == null || userId == null) {
        state = state.copyWith(isLoading: false, error: 'User not authenticated');
        return;
      }

      final response = await client
          .from('menstrual_logs')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false);

      final List<MenstrualLog> logs = (response as List)
          .map((json) => MenstrualLog.fromJson(json))
          .toList();

      _calculateCurrentPhase(logs);

    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _calculateCurrentPhase(List<MenstrualLog> logs) {
    if (logs.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        logs: [],
        currentPhase: CyclePhase.unknown,
        currentDayOfCycle: 0,
        nextPredictedPeriod: null,
      );
      return;
    }

    final latestLog = logs.first;
    final now = DateTime.now();
    
    // Calculate days since the start of the last period
    final start = DateTime(latestLog.startDate.year, latestLog.startDate.month, latestLog.startDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysSinceStart = today.difference(start).inDays + 1; // Day 1 is the start date
    
    // Standard 28 day cycle mapping (V1)
    // Menstrual: Days 1-5
    // Follicular: Days 6-13
    // Ovulatory: Day 14
    // Luteal: Days 15-28
    
    CyclePhase phase = CyclePhase.unknown;
    int currentDay = daysSinceStart;
    
    final profile = ref.read(patientProfileProvider).value;
    int cycleLength = 28;
    if (profile?.questionnaireData != null) {
      cycleLength = int.tryParse(profile!.questionnaireData!['cycle_length']?.toString() ?? '28') ?? 28;
    }
    
    DateTime nextPeriod = start.add(Duration(days: cycleLength));
    
    int activeDay = currentDay % cycleLength;
    if (activeDay == 0) activeDay = cycleLength; // Keep it 1-cycleLength
    
    // Proportional phase mapping based on user's cycle length
    // Menstrual: Days 1-5 (usually constant)
    // Follicular: Days 6 to (cycleLength/2 - 1)
    // Ovulatory: Day (cycleLength/2)
    // Luteal: Remaining days
    
    if (activeDay >= 1 && activeDay <= 5) {
      phase = CyclePhase.menstrual;
    } else if (activeDay >= 6 && activeDay < (cycleLength / 2).floor()) {
      phase = CyclePhase.follicular;
    } else if (activeDay == (cycleLength / 2).floor()) {
      phase = CyclePhase.ovulatory;
    } else {
      phase = CyclePhase.luteal;
    }

    // Adjust next predicted period
    while (nextPeriod.isBefore(today) || nextPeriod.isAtSameMomentAs(today)) {
      nextPeriod = nextPeriod.add(Duration(days: cycleLength));
    }

    state = state.copyWith(
      isLoading: false,
      logs: logs,
      currentPhase: phase,
      currentDayOfCycle: currentDay, // Keep actual day count since last log
      nextPredictedPeriod: nextPeriod,
    );
  }

  Future<void> logPeriodStart(DateTime startDate) async {
    final client = SupabaseConfig.client;
    final userId = SupabaseConfig.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      final dateStr = startDate.toIso8601String().substring(0, 10);
      
      // Fetch latest logs to ensure we have current state
      final response = await client
          .from('menstrual_logs')
          .select()
          .eq('user_id', userId)
          .order('start_date', ascending: false)
          .limit(1);

      final List<dynamic> data = response as List;
      final latestLog = data.isNotEmpty ? MenstrualLog.fromJson(data.first) : null;
      
      bool shouldUpdate = false;
      if (latestLog != null) {
        // If the new date is within 20 days of the latest log, we treat it as an adjustment/edit
        // 20 days covers most "oops I selected the wrong day" scenarios while allowing a very short cycle
        final diff = startDate.difference(latestLog.startDate).inDays.abs();
        if (diff < 20) {
          shouldUpdate = true;
        }
      }

      if (shouldUpdate && latestLog != null) {
        await client
            .from('menstrual_logs')
            .update({
              'start_date': dateStr,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', latestLog.id);
        debugPrint('✅ Updated cycle log ${latestLog.id} to $dateStr');
      } else {
        await client.from('menstrual_logs').insert({
          'user_id': userId,
          'start_date': dateStr,
        });
        debugPrint('✅ Inserted new cycle log for $dateStr');
      }
      
      await fetchLogs(); // Refresh state
    } catch (e) {
      debugPrint('❌ Error logging period: $e');
      state = state.copyWith(error: 'Failed to log period: $e');
    }
  }

  Future<void> deleteLatestLog() async {
    if (state.logs.isEmpty) return;
    
    final client = SupabaseConfig.client;
    if (client == null) return;

    final latestLog = state.logs.first;
    
    try {
      state = state.copyWith(isLoading: true);
      await client
          .from('menstrual_logs')
          .delete()
          .eq('id', latestLog.id);
      
      debugPrint('🗑️ Deleted cycle log ${latestLog.id}');
      await fetchLogs();
    } catch (e) {
      debugPrint('❌ Error deleting cycle log: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to delete log: $e');
    }
  }
}

final cycleIntelligenceProvider = NotifierProvider<CycleIntelligenceNotifier, CycleIntelligenceState>(() {
  return CycleIntelligenceNotifier();
});

/// Exposes whether the current user is female (to conditionally show UI elements)
final isFemaleUserProvider = Provider<bool>((ref) {
  final profile = ref.watch(patientProfileProvider).value;
  if (profile?.questionnaireData != null) {
    final gender = profile!.questionnaireData!['gender'];
    return gender == 'Female';
  }
  return false; // Default to false if unknown
});
