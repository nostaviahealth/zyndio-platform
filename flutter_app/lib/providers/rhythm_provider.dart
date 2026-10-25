import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/daily_rhythm.dart';
import '../models/food_analysis.dart';
import '../data/protocol_repository.dart';
import '../config/supabase_config.dart';
import 'chat_provider.dart'; 
import '../services/azure_openai_service.dart';
import '../services/memory_service.dart';
import 'patient_provider.dart';
import 'protocol_provider.dart';
import 'wearable_sync_provider.dart';
import 'intelligence_provider.dart';
import 'consistency_provider.dart';
import 'protocol_progress_provider.dart';
import 'blueprint_provider.dart';
import 'purchase_provider.dart';
import '../services/notification_scheduler.dart';
import '../services/notification_service.dart';
import '../services/user_habit_service.dart';
import '../services/gamification_service.dart';
import 'user_habit_provider.dart';
import 'gamification_provider.dart';
import '../services/live_activity_service.dart';

class RhythmState {
  final AsyncValue<DailyRhythm?> rhythm;
  final DateTime? lastUpdated;
  final bool isAdjusting;
  final bool isAdjusted;
  final bool isAutoAdaptEnabled;
  final String? lastAutoCompletedTaskId; // NEW: Track last auto-completed task for Undo
  
  RhythmState(
    this.rhythm, {
    this.lastUpdated, 
    this.isAdjusting = false, 
    this.isAdjusted = false,
    this.isAutoAdaptEnabled = false,
    this.lastAutoCompletedTaskId,
  });

  RhythmState copyWith({
    AsyncValue<DailyRhythm?>? rhythm,
    DateTime? lastUpdated,
    bool? isAdjusting,
    bool? isAdjusted,
    bool? isAutoAdaptEnabled,
    String? lastAutoCompletedTaskId,
    bool clearUndo = false,
  }) {
    return RhythmState(
      rhythm ?? this.rhythm,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isAdjusting: isAdjusting ?? this.isAdjusting,
      isAdjusted: isAdjusted ?? this.isAdjusted,
      isAutoAdaptEnabled: isAutoAdaptEnabled ?? this.isAutoAdaptEnabled,
      lastAutoCompletedTaskId: clearUndo ? null : (lastAutoCompletedTaskId ?? this.lastAutoCompletedTaskId),
    );
  }
}

class RhythmNotifier extends Notifier<RhythmState> {
  String? _profileId;
  SupabaseClient? _supabase;
  bool _isInitialized = false;

  @override
  RhythmState build() {
    final profile = ref.watch(patientProfileProvider).value;
    final newProfileId = profile?.id;
    _supabase = SupabaseConfig.client;

    if (!_isInitialized || (newProfileId != _profileId && newProfileId != 'transient')) {
      _profileId = newProfileId;
      _isInitialized = true;
      // Decouple from build to avoid circular dependencies during initialization
      Future.microtask(() => _init());
      // Return a fresh state instead of reading from 'state' which is not yet set
      return RhythmState(const AsyncValue.loading(), isAutoAdaptEnabled: false);
    }
    
    // Safety check: Avoid reading 'state' if uninitialized during rapid build cycles
    try {
      return state;
    } catch (_) {
      return RhythmState(const AsyncValue.loading(), isAutoAdaptEnabled: false);
    }
  }

  AzureOpenAIService get _aiService => ref.read(azureOpenAIServiceProvider);
  MemoryService get _memoryService => ref.read(memoryServiceProvider);

  /// Extracts the user's first name from their profile for personalization.
  String? get _userName {
    final profile = ref.read(patientProfileProvider).value;
    if (profile?.name == null || profile!.name!.isEmpty) return null;
    return profile.name!.split(' ').first;
  }

  /// Fetches relevant long-term memory facts about the user for AI context.
  Future<List<String>> _fetchUserContext() async {
    try {
      final memories = await _memoryService.recallMemories(
        'user health habits preferences goals injuries diet',
        count: 5,
      );
      return memories.map((m) => m.content).toList();
    } catch (e) {
      debugPrint('Memory recall failed (non-critical): $e');
      return [];
    }
  }

  static const String _storageKeyPrefix = 'daily_rhythm_';
  static const String _autoAdaptKey = 'auto_adapt_enabled';

  String get _storageKey {
    // Key format: daily_rhythm_{profileId}_{yyyy-MM-dd}
    final now = DateTime.now();
    return _getStorageKeyForDate(now);
  }

  String _getStorageKeyForDate(DateTime date) {
    if (_profileId == 'transient') return "${_storageKeyPrefix}v2_loading_$date";
    final dateStr = "${date.year}-${date.month}-${date.day}";
    return "${_storageKeyPrefix}v2_${_profileId ?? 'guest'}_$dateStr";
  }

  /// Returns true if current time is after midnight (12:00 AM) and before wakeup time (5:00 AM)
  bool _isAfterMidnightButBeforeWakeup() {
    final now = DateTime.now();
    return now.hour >= 0 && now.hour < 5;
  }

  Future<void> _init() async {
    // Guard: If we are logged in but still 'transient', do not initialize persistence yet
    // Wait for the next build cycle to provide a real ID.
    if (_profileId == 'transient') return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isPlus = ref.read(purchaseProvider).isPlus;
      // Default auto-adapt to ON for Plus members automatically on first launch
      final isAutoAdapt = prefs.getBool(_autoAdaptKey) ?? isPlus;
      
      final todayRhythm = await _getRhythmForDate(DateTime.now());

      if (todayRhythm != null) {
        state = RhythmState(
          AsyncValue.data(todayRhythm), 
          lastUpdated: DateTime.now(),
          isAutoAdaptEnabled: isAutoAdapt,
          isAdjusted: todayRhythm.source == 'optimized',
        );
        // Background Sync: Check if cloud has a newer version or if we need to push
        _syncWithCloud(todayRhythm);
        // Setup daily local push notifications
        NotificationScheduler().scheduleForRhythm(todayRhythm);

        // Auto-adapt automatically as the user wakes up (if loaded a non-optimized rhythm)
        if (isPlus && isAutoAdapt && !state.isAdjusted && !_isAfterMidnightButBeforeWakeup()) {
          debugPrint('RhythmProvider: Auto-Adapt triggered on initialization (wakeup)');
          intelligenceAdjust();
        }
      } else {
        // Only trigger a new refresh if we are NOT in the middle of a loading phase
        // and we definitely don't have a cloud version.
        final cloudRhythm = await _fetchFromSupabase(DateTime.now());
        if (cloudRhythm != null) {
          state = RhythmState(
            AsyncValue.data(cloudRhythm), 
            lastUpdated: DateTime.now(),
            isAutoAdaptEnabled: isAutoAdapt,
            isAdjusted: cloudRhythm.source == 'optimized',
          );
          await _saveLocal(cloudRhythm);
          NotificationScheduler().scheduleForRhythm(cloudRhythm);
        } else {
           // We are sure it doesn't exist anywhere
           state = state.copyWith(isAutoAdaptEnabled: isAutoAdapt);
           await refresh();
        }
      }
    } catch (e, st) {
      state = RhythmState(AsyncValue.error(e, st));
    }
  }

  Future<void> toggleAutoAdapt(bool enabled) async {
    state = state.copyWith(isAutoAdaptEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoAdaptKey, enabled);
    
    // If turning ON and not yet adjusted, trigger it immediately
    if (enabled && !state.isAdjusted && !state.isAdjusting) {
      if (!_isAfterMidnightButBeforeWakeup()) {
        intelligenceAdjust();
      }
    }
  }

  Future<DailyRhythm?> _getRhythmForDate(DateTime date) async {
    // 1. Try Local First
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKeyForDate(date);
      final jsonStr = prefs.getString(key);

      if (jsonStr != null) {
        return DailyRhythm.fromJson(jsonDecode(jsonStr));
      }
    } catch (e) {
      debugPrint("Error fetching local rhythm for date $date: $e");
    }

    // 2. Fallback to Cloud (if looking for past history or just missing local)
    // Only verify with cloud if we have a valid user session
    if (_supabase?.auth.currentUser != null) {
       return await _fetchFromSupabase(date);
    }

    return null;
  }

  Future<DailyRhythm?> _fetchFromSupabase(DateTime date) async {
    try {
      final client = _supabase;
      if (client == null) return null;
      final user = client.auth.currentUser;
      if (user == null) return null;

      final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
      
      final response = await client
          .from('daily_rhythms')
          .select()
          .eq('user_id', user.id)
          .eq('date', dateStr)
          .maybeSingle();

      if (response != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(response);
        final dateStr = data['date'] as String? ?? date.toIso8601String();
        return DailyRhythm.fromJson({
          'id': data['id'] ?? 'unknown',
          'date': dateStr,
          'summary': data['summary'] ?? "Let's make today count!",
          'tasks': data['tasks'] ?? [],
          'source': data['source'] ?? 'generated',
          'morningText': data['morning_text'],
          'lunchText': data['lunch_text'],
          'eveningText': data['evening_text'],
        });
      }
    } catch (e) {
      debugPrint("Error fetching from Supabase for date $date: $e");
    }
    return null;
  }
  
  Future<void> _syncWithCloud(DailyRhythm localRhythm) async {
    if (_supabase?.auth.currentUser != null) {
       await _saveToSupabase(localRhythm);
    }
  }

  /// Appends fixed supplement tasks from the protocol to a rhythm.
  DailyRhythm _appendSupplements(DailyRhythm rhythm, ProtocolData protocol) {
    final supplementTasks = protocol.supplements.map((s) => RhythmTask(
      id: 'supp_${s.title.hashCode}',
      title: s.title,
      detail: s.detail,
      time: s.time.isNotEmpty ? s.time : 'With Meal',
      category: 'supplement',
      isCompleted: false,
    )).toList();

    return DailyRhythm(
      id: rhythm.id,
      date: rhythm.date,
      summary: rhythm.summary,
      tasks: [...rhythm.tasks, ...supplementTasks],
      source: rhythm.source,
      blueprintDayNumber: rhythm.blueprintDayNumber,
      morningText: rhythm.morningText,
      lunchText: rhythm.lunchText,
      eveningText: rhythm.eveningText,
    );
  }

  /// Default refresh: Loads RAW blueprint tasks without AI optimization.
  /// This is the standard experience for all users.
  Future<void> refresh() async {
    state = state.copyWith(rhythm: const AsyncValue.loading(), isAdjusted: false);
    try {
      ProtocolData? protocol = ref.read(protocolProvider).selectedProtocol;
      protocol ??= await ProtocolRepository.fetchProtocol(profileId: _profileId);

      DailyRhythm? newRhythm;
      final blueprintNotifier = ref.read(blueprintProvider.notifier);

      // ── BLUEPRINT-FIRST: Load raw blueprint tasks (no AI call) ──
      if (blueprintNotifier.isBlueprintAvailableForToday) {
        final todayBlueprint = blueprintNotifier.todayBlueprint;
        if (todayBlueprint != null) {
          debugPrint('RhythmProvider: Loading raw Blueprint Day ${todayBlueprint.dayNumber}');
          newRhythm = todayBlueprint.toDailyRhythm();
        }
      }

      // ── FALLBACK: No blueprint → generate with AI ──
      if (newRhythm == null) {
        debugPrint('RhythmProvider: No blueprint available, using full generation');
        final yesterdayDate = DateTime.now().subtract(const Duration(days: 1));
        final yesterday = await _getRhythmForDate(yesterdayDate);
        WearableSnapshot? snapshot;
        try {
          final syncState = ref.read(wearableSyncProvider).value;
          snapshot = syncState?.snapshot;
        } catch (_) {}
        final progressState = ref.read(protocolProgressProvider);
        final durationWeeks = progressState.getDurationWeeks(protocol.id);
        final consistency = ref.read(consistencyProvider);
        final progress = progressState.getProgress(
          protocol.id,
          durationWeeks: durationWeeks,
          performanceRate: consistency.weekConsistency,
        );
        // Fetch personalization context for the Intelligence
        final userContext = await _fetchUserContext();
        final habitProfile = ref.read(userHabitProfileProvider);
        newRhythm = await _aiService.generateDailyRhythm(
          protocol,
          yesterday,
          wearable: snapshot,
          progress: progress,
          userName: _userName,
          userContext: userContext,
          habitProfile: habitProfile,
        );
      }

      if (newRhythm != null) {
        final finalRhythm = _appendSupplements(newRhythm, protocol);
        final isAlreadyAdjusted = finalRhythm.source == 'optimized';
        
        state = RhythmState(
          AsyncValue.data(finalRhythm), 
          lastUpdated: DateTime.now(),
          isAutoAdaptEnabled: state.isAutoAdaptEnabled,
          isAdjusted: isAlreadyAdjusted,
        );
        await _save(finalRhythm);
        NotificationScheduler().scheduleForRhythm(finalRhythm);
        ref.read(consistencyProvider.notifier).refresh();

        // Update Dynamic Island Rhythm Score
        final score = (finalRhythm.completionRate * 100).toInt();
        ref.read(liveActivityServiceProvider).startRhythmActivity(
          score: score,
          nextWindow: finalRhythm.summary.contains('Golden Window') 
            ? 'Active Now' 
            : 'Evaluating...',
        );

        // ── AUTO-ADAPT & INITIAL INTELLIGENCE ──
        final isPlus = ref.read(purchaseProvider).isPlus;
        final needsInitialAiText = finalRhythm.morningText == null;

        if (isPlus && (state.isAutoAdaptEnabled || needsInitialAiText)) {
          if (!_isAfterMidnightButBeforeWakeup()) {
            debugPrint('RhythmProvider: ${needsInitialAiText ? "Initial AI Text" : "Auto-Adapt"} triggered');
            intelligenceAdjust();
          } else {
            debugPrint('RhythmProvider: Auto-Adapt suppressed after midnight before wake-up');
          }
        }
      } else {
        state = state.copyWith(rhythm: const AsyncValue.error("Failed to generate rhythm", StackTrace.empty));
      }
    } catch (e, st) {
      state = state.copyWith(rhythm: AsyncValue.error(e, st));
    }
  }

  /// Intelligence Adjust: AI-optimizes the current blueprint tasks based on
  /// wearable data, yesterday's completion, recovery, etc. Plus-only feature.
  Future<void> intelligenceAdjust() async {
    if (state.isAdjusting) return;
    
    state = state.copyWith(isAdjusting: true);
    try {
      ProtocolData? protocol = ref.read(protocolProvider).selectedProtocol;
      protocol ??= await ProtocolRepository.fetchProtocol(profileId: _profileId);

      final blueprintNotifier = ref.read(blueprintProvider.notifier);
      var todayBlueprint = blueprintNotifier.todayBlueprint;

      // ── RECOVERY: If blueprint is missing, try to fetch it ──
      if (todayBlueprint == null) {
        debugPrint('RhythmProvider: Blueprint missing, attempting recovery fetch...');
        final selectedId = ref.read(protocolProvider).selectedProtocolId;
        if (selectedId != null) {
          await blueprintNotifier.fetchBlueprint(selectedId);
          todayBlueprint = blueprintNotifier.todayBlueprint;
        }
      }

      if (todayBlueprint == null) {
        state = state.copyWith(isAdjusting: false);
        throw Exception("Your timeline is still syncing. Please wait a moment.");
      }

      // Gather all context for AI optimization
      final yesterdayDate = DateTime.now().subtract(const Duration(days: 1));
      final yesterday = await _getRhythmForDate(yesterdayDate);
      WearableSnapshot? snapshot;
      try {
        final syncState = ref.read(wearableSyncProvider).value;
        snapshot = syncState?.snapshot;
      } catch (_) {}
      final progressState = ref.read(protocolProgressProvider);
      final durationWeeks = progressState.getDurationWeeks(protocol.id);
      final consistency = ref.read(consistencyProvider);
      final progress = progressState.getProgress(
        protocol.id,
        durationWeeks: durationWeeks,
        performanceRate: consistency.weekConsistency,
      );

      debugPrint('RhythmProvider: Intelligence Adjust — optimizing Day ${todayBlueprint.dayNumber}');
      // Fetch personalization context for the Intelligence
      final userContext = await _fetchUserContext();
      final habitProfile = ref.read(userHabitProfileProvider);
      final optimized = await _aiService.optimizeBlueprintDay(
        todayBlueprint,
        protocol,
        wearable: snapshot,
        yesterday: yesterday,
        progress: progress,
        userName: _userName,
        userContext: userContext,
        habitProfile: habitProfile,
      );

      if (optimized != null) {
        // Preserve completion state from current tasks
        final current = state.rhythm.value;
        final completedIds = current?.tasks
            .where((t) => t.isCompleted)
            .map((t) => t.id)
            .toSet() ?? <String>{};

        final preservedTasks = optimized.tasks.map((t) {
          if (completedIds.contains(t.id)) {
            return t.copyWith(isCompleted: true);
          }
          return t;
        }).toList();

        final adjustedRhythm = DailyRhythm(
          id: optimized.id,
          date: optimized.date,
          summary: optimized.summary,
          tasks: preservedTasks,
          source: 'optimized',
          blueprintDayNumber: todayBlueprint.dayNumber,
          morningText: optimized.morningText,
          lunchText: optimized.lunchText,
          eveningText: optimized.eveningText,
        );

        final finalRhythm = _appendSupplements(adjustedRhythm, protocol);
        state = RhythmState(
          AsyncValue.data(finalRhythm),
          lastUpdated: DateTime.now(),
          isAdjusted: true,
          isAdjusting: false,
          isAutoAdaptEnabled: state.isAutoAdaptEnabled,
        );
        await _save(finalRhythm);
        NotificationScheduler().scheduleForRhythm(finalRhythm);
        ref.read(consistencyProvider.notifier).refresh();

        // Update Dynamic Island Rhythm Score
        final score = (finalRhythm.completionRate * 100).toInt();
        ref.read(liveActivityServiceProvider).startRhythmActivity(
          score: score,
          nextWindow: 'Optimal Window Open',
        );
      } else {
        state = state.copyWith(isAdjusting: false);
      }
    } catch (e) {
      debugPrint('RhythmProvider: Intelligence Adjust failed: $e');
      state = state.copyWith(isAdjusting: false);
    }
  }

  Future<void> toggleTask(String taskId) async {
    final current = state.rhythm.value;
    if (current == null) return;

    final updatedTasks = current.tasks.map((t) {
      if (t.id == taskId) {
        final completed = !t.isCompleted;
        // ── ADAPTIVE EVOLUTION ENGINE: Record Task Completion ──
        UserHabitService.recordTaskCompletionEvent(t.category, DateTime.now(), completed);
        return t.copyWith(isCompleted: completed);
      }
      return t;
    }).toList();

    final updatedRhythm = DailyRhythm(
      id: current.id,
      date: current.date,
      summary: current.summary,
      tasks: updatedTasks,
      source: current.source,
      blueprintDayNumber: current.blueprintDayNumber,
      morningText: current.morningText,
      lunchText: current.lunchText,
      eveningText: current.eveningText,
    );

    RhythmTask? toggledTask;
    bool wasCompleted = false;
    for (int i = 0; i < current.tasks.length; i++) {
        if (current.tasks[i].id == taskId) {
            toggledTask = updatedTasks[i];
            wasCompleted = toggledTask.isCompleted;
            break;
        }
    }
    
    // Optimistic Update
    state = state.copyWith(rhythm: AsyncValue.data(updatedRhythm), lastUpdated: DateTime.now());
    await _save(updatedRhythm);
    // Refresh consistency to reflect change
    ref.read(consistencyProvider.notifier).refresh();
    // Refresh protocol adherence so progress bar updates immediately
    final selectedId = ref.read(protocolProvider).selectedProtocolId;
    if (selectedId != null) {
      ref.read(protocolProgressProvider.notifier).refreshAdherence(selectedId);
    }

    if (toggledTask != null && wasCompleted) {
       _fireRewardAndContextualAnchors(updatedRhythm, toggledTask);

       // ── GAMIFICATION: Award XP for task completion ──
       final dateStr = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
       ref.read(gamificationProvider.notifier).awardReward(
         RewardType.taskComplete,
         referenceId: '${taskId}_$dateStr',
       );

       // Check if ALL tasks are now complete → bonus reward
       final allDone = updatedTasks.every((t) => t.isCompleted);
       if (allDone && updatedTasks.isNotEmpty) {
         ref.read(gamificationProvider.notifier).awardReward(
           RewardType.allTasksComplete,
           referenceId: 'all_tasks_$dateStr',
         );
       }
    }
  }

  Future<void> _fireRewardAndContextualAnchors(DailyRhythm rhythm, RhythmTask task) async {
      try {
         // 1. Immediate Reward Nudge (Micro-Insight)
         final rewardMsg = await _aiService.generateRewardNudge(userName: _userName ?? 'there', task: task);
         if (rewardMsg != null && rewardMsg.isNotEmpty) {
            NotificationService().showLocalNotification(
               id: DateTime.now().millisecondsSinceEpoch % 100000,
               title: 'Task Complete',
               body: rewardMsg,
               categoryIdentifier: 'REWARD',
            );
         }

         // 2. Contextual Anchors (Only if before their respective times)
         final now = DateTime.now();
         final habitProfile = ref.read(userHabitProfileProvider);
         WearableSnapshot? snapshot;
         try {
           final syncState = ref.read(wearableSyncProvider).value;
           snapshot = syncState?.snapshot;
         } catch (_) {}
         final adherenceScore = ref.read(consistencyProvider).weekConsistency;

         String? updatedLunchText = rhythm.lunchText;
         String? updatedEveningText = rhythm.eveningText;

         if (now.hour < 13) {
            final lunchNudge = await _aiService.generateContextualNudge(
               anchorType: 'Lunch',
               userName: _userName ?? 'there',
               adherence: adherenceScore,
               todayTasks: rhythm.tasks,
               wearable: snapshot,
               habitProfile: habitProfile,
            );
            if (lunchNudge != null) updatedLunchText = lunchNudge['body'];
         }

         if (now.hour < 20 || (now.hour == 20 && now.minute < 30)) {
            final eveningNudge = await _aiService.generateContextualNudge(
               anchorType: 'Evening',
               userName: _userName ?? 'there',
               adherence: adherenceScore,
               todayTasks: rhythm.tasks,
               wearable: snapshot,
               habitProfile: habitProfile,
            );
            if (eveningNudge != null) updatedEveningText = eveningNudge['body'];
         }

         if (updatedLunchText != rhythm.lunchText || updatedEveningText != rhythm.eveningText) {
             final deeplyUpdatedRhythm = DailyRhythm(
                 id: rhythm.id,
                 date: rhythm.date,
                 summary: rhythm.summary,
                 tasks: rhythm.tasks,
                 source: rhythm.source,
                 blueprintDayNumber: rhythm.blueprintDayNumber,
                 morningText: rhythm.morningText,
                 lunchText: updatedLunchText,
                 eveningText: updatedEveningText,
             );
             state = state.copyWith(rhythm: AsyncValue.data(deeplyUpdatedRhythm));
             await _save(deeplyUpdatedRhythm);
             NotificationScheduler().scheduleForRhythm(deeplyUpdatedRhythm);
         }
      } catch (e) {
         debugPrint('AI Context Update Error: $e');
      }
  }

  /// ═══════════════════════════════════════════════════════
  /// ZERO-FRICTION AUTO-COMPLETION ENGINE V2
  /// ═══════════════════════════════════════════════════════
  /// Automatically marks ONLY the most relevant uncompleted task in a category as done.
  /// Triggered by external signals (Lens scan → diet, Workout → fitness).
  /// Now includes biological "Quality Checks" and "Human-like" matching.
  /// Returns the number of tasks successfully auto-completed.
  Future<int> autoCompleteRelevantTask(String category, {dynamic contextData}) async {
    final current = state.rhythm.value;
    if (current == null) return 0;

    final tasks = current.tasks;
    String? targetTaskId;

    // ── 1. DIET CONTEXT (Lens Analysis) ──
    if (category.toLowerCase() == 'diet' && contextData is FoodAnalysis) {
      final analysis = contextData;
      final foodName = analysis.foodName.toLowerCase();
      final now = DateTime.now();
      final hour = now.hour;

      // A. Quality Check: Don't auto-complete "Healthy" tasks if food is junk
      final isJunkFood = analysis.score < 45 || analysis.upfAnalysis.score > 7;
      
      // B. Human-like Matching: Look for titles that match the food or time window
      // We search for a specific match first, then a time-window match
      targetTaskId = _findTaskIdBySmartMatch(tasks, 'diet', foodName, isJunkFood);

      if (targetTaskId == null) {
        // Fallback to time window if no direct food match
        if (hour >= 5 && hour < 11) {
          targetTaskId = _findTaskIdByTitle(tasks, 'diet', ['breakfast', 'morning'], isJunkFood);
        } else if (hour >= 11 && hour < 16) {
          targetTaskId = _findTaskIdByTitle(tasks, 'diet', ['lunch', 'noon', 'afternoon'], isJunkFood);
        } else if (hour >= 16 || hour < 5) {
          targetTaskId = _findTaskIdByTitle(tasks, 'diet', ['dinner', 'evening', 'night'], isJunkFood);
        }
      }
    } 
    // ── 2. GENERAL CONTEXT (Fitness etc.) ──
    else {
      targetTaskId = _findFirstUncompleted(tasks, category);
    }

    if (targetTaskId == null) return 0;

    final updatedTasks = tasks.map((t) {
      if (t.id == targetTaskId) {
        return t.copyWith(isCompleted: true);
      }
      return t;
    }).toList();

    final updatedRhythm = DailyRhythm(
      id: current.id,
      date: current.date,
      summary: current.summary,
      tasks: updatedTasks,
      source: current.source,
      blueprintDayNumber: current.blueprintDayNumber,
      morningText: current.morningText,
      lunchText: current.lunchText,
      eveningText: current.eveningText,
    );

    state = state.copyWith(
      rhythm: AsyncValue.data(updatedRhythm), 
      lastUpdated: DateTime.now(),
      lastAutoCompletedTaskId: targetTaskId, // Store for Undo
    );

    await _save(updatedRhythm);
    _refreshProgess();

    final matchedTask = tasks.firstWhere((t) => t.id == targetTaskId);
    debugPrint('✨ Smarter Auto-complete: "${matchedTask.title}"');
    return 1;
  }

  /// Reverts the last auto-completed task to uncompleted.
  Future<void> undoLastAutoCompletion() async {
    final taskId = state.lastAutoCompletedTaskId;
    if (taskId == null) return;

    final current = state.rhythm.value;
    if (current == null) return;

    final updatedTasks = current.tasks.map((t) {
      if (t.id == taskId) return t.copyWith(isCompleted: false);
      return t;
    }).toList();

    final updatedRhythm = DailyRhythm(
      id: current.id,
      date: current.date,
      summary: current.summary,
      tasks: updatedTasks,
      source: current.source,
      blueprintDayNumber: current.blueprintDayNumber,
      morningText: current.morningText,
      lunchText: current.lunchText,
      eveningText: current.eveningText,
    );

    state = state.copyWith(
      rhythm: AsyncValue.data(updatedRhythm),
      lastUpdated: DateTime.now(),
      clearUndo: true,
    );

    await _save(updatedRhythm);
    _refreshProgess();
    debugPrint('↩️ Undo Auto-complete: $taskId');
  }

  void _refreshProgess() {
    ref.read(consistencyProvider.notifier).refresh();
    final selectedId = ref.read(protocolProvider).selectedProtocolId;
    if (selectedId != null) {
      ref.read(protocolProgressProvider.notifier).refreshAdherence(selectedId);
    }
  }

  /// Finds a task by matching food name keywords (e.g. "Egg" matches "Protein Breakfast")
  String? _findTaskIdBySmartMatch(List<RhythmTask> tasks, String category, String foodName, bool isJunkFood) {
    try {
      final match = tasks.firstWhere((t) {
        if (t.category.toLowerCase() != category.toLowerCase() || t.isCompleted) return false;
        
        // Quality Check: Junk food can't complete "Healthy" tasks
        if (isJunkFood && _isHealthyTask(t.title)) return false;

        // Smart keyword checking
        final title = t.title.toLowerCase();
        final keywords = foodName.split(' ').where((w) => w.length > 3).toList();
        if (keywords.isEmpty) keywords.add(foodName);

        return keywords.any((k) => title.contains(k)) || title.contains(foodName);
      });
      return match.id;
    } catch (_) {
      return null;
    }
  }

  String? _findTaskIdByTitle(List<RhythmTask> tasks, String category, List<String> keywords, bool isJunkFood) {
    try {
      final match = tasks.firstWhere((t) {
        if (t.category.toLowerCase() != category.toLowerCase() || t.isCompleted) return false;
        if (isJunkFood && _isHealthyTask(t.title)) return false;
        
        final title = t.title.toLowerCase();
        return keywords.any((k) => title.contains(k));
      });
      return match.id;
    } catch (_) {
      return null;
    }
  }

  bool _isHealthyTask(String title) {
    final lower = title.toLowerCase();
    return lower.contains('healthy') || 
           lower.contains('nutritious') || 
           lower.contains('clean') || 
           lower.contains('protein') ||
           lower.contains('greens');
  }

  String? _findFirstUncompleted(List<RhythmTask> tasks, String category) {
    try {
      final match = tasks.firstWhere((t) => 
        t.category.toLowerCase() == category.toLowerCase() && 
        !t.isCompleted
      );
      return match.id;
    } catch (_) {
      return null;
    }
  }

  Future<void> addTask(String title, String? timeOfDay) async {
      final current = state.rhythm.value;
      if (current == null) return;

      final newTask = RhythmTask(
          id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          detail: timeOfDay,
          time: timeOfDay ?? 'Anytime',
          category: 'lifestyle',
          isCompleted: false
      );

      final updatedTasks = [...current.tasks, newTask];
      final updatedRhythm = DailyRhythm(
          id: current.id,
          date: current.date,
          summary: current.summary,
          tasks: updatedTasks,
          source: current.source,
          blueprintDayNumber: current.blueprintDayNumber,
      );

      state = state.copyWith(rhythm: AsyncValue.data(updatedRhythm), lastUpdated: DateTime.now());
      await _save(updatedRhythm);
      // Refresh consistency to reflect change
      ref.read(consistencyProvider.notifier).refresh();
      // Refresh protocol adherence
      final selectedId = ref.read(protocolProvider).selectedProtocolId;
      if (selectedId != null) {
        ref.read(protocolProgressProvider.notifier).refreshAdherence(selectedId);
      }
  }

  Future<void> removeTask(String title) async {
      final current = state.rhythm.value;
      if (current == null) return;

      // Fuzzy match or exact match
      final updatedTasks = current.tasks.where((t) => t.title.toLowerCase() != title.toLowerCase()).toList();
      
      final updatedRhythm = DailyRhythm(
          id: current.id,
          date: current.date,
          summary: current.summary,
          tasks: updatedTasks,
          source: current.source,
          blueprintDayNumber: current.blueprintDayNumber,
      );

      state = state.copyWith(rhythm: AsyncValue.data(updatedRhythm), lastUpdated: DateTime.now());
      await _save(updatedRhythm);
      // Refresh consistency to reflect change
      ref.read(consistencyProvider.notifier).refresh();
      // Refresh protocol adherence
      final selectedId = ref.read(protocolProvider).selectedProtocolId;
      if (selectedId != null) {
        ref.read(protocolProgressProvider.notifier).refreshAdherence(selectedId);
      }
  }

  Future<void> completeTaskByTitle(String title) async {
      final current = state.rhythm.value;
      if (current == null) return;
      
      final task = current.tasks.firstWhere(
          (t) => t.title.toLowerCase().contains(title.toLowerCase()), 
          orElse: () => current.tasks.first // Fallback safely or handle null
      );
      
      if (current.tasks.contains(task)) {
         await toggleTask(task.id);
      }
  }

  Future<void> _save(DailyRhythm rhythm) async {
    await _saveLocal(rhythm);
    
    // Fire and forget cloud save
    _saveToSupabase(rhythm).ignore();
  }

  Future<void> _saveLocal(DailyRhythm rhythm) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(rhythm.toJson()));
    } catch (e) {
      debugPrint("Error saving local rhythm: $e");
    }
  }

  Future<void> _saveToSupabase(DailyRhythm rhythm) async {
    try {
      final client = _supabase;
      if (client == null) return;
      final user = client.auth.currentUser;
      if (user == null) return;

      final dateStr = "${rhythm.date.year}-${rhythm.date.month.toString().padLeft(2,'0')}-${rhythm.date.day.toString().padLeft(2,'0')}";

      await client.from('daily_rhythms').upsert({
        'user_id': user.id,
        'date': dateStr,
        'summary': rhythm.summary,
        'tasks': rhythm.tasks.map((t) => t.toJson()).toList(),
        'source': rhythm.source,
        if (rhythm.morningText != null) 'morning_text': rhythm.morningText,
        if (rhythm.lunchText != null) 'lunch_text': rhythm.lunchText,
        if (rhythm.eveningText != null) 'evening_text': rhythm.eveningText,
      }, onConflict: 'user_id, date'); 
      
    } catch (e) {
      debugPrint("Error saving to Supabase: $e");
    }
  }
}

// azureOpenAIServiceProvider is defined in chat_provider.dart

final dailyRhythmProvider = NotifierProvider<RhythmNotifier, RhythmState>(() {
  return RhythmNotifier();
});
