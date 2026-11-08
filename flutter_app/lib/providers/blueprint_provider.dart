import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../data/protocol_repository.dart';
import '../models/protocol_blueprint.dart';
import '../services/azure_openai_service.dart';
import 'protocol_provider.dart';

/// State for the Blueprint system
class BlueprintState {
  final ProtocolBlueprint? blueprint;
  final bool isLoading;
  final bool isGenerating;
  final String? syncProgress;
  final String? error;

  const BlueprintState({
    this.blueprint,
    this.isLoading = false,
    this.isGenerating = false,
    this.syncProgress,
    this.error,
  });

  /// Creates a copy of this state with the given fields replaced.
  ///
  /// To explicitly clear [blueprint] or [syncProgress] to null, pass
  /// `clearBlueprint: true` or `clearSyncProgress: true` respectively.
  BlueprintState copyWith({
    ProtocolBlueprint? blueprint,
    bool clearBlueprint = false,
    bool? isLoading,
    bool? isGenerating,
    String? syncProgress,
    bool clearSyncProgress = false,
    String? error,
  }) {
    return BlueprintState(
      blueprint: clearBlueprint ? null : (blueprint ?? this.blueprint),
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      syncProgress: clearSyncProgress ? null : (syncProgress ?? this.syncProgress),
      error: error,
    );
  }
}

class BlueprintNotifier extends Notifier<BlueprintState> with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isLoopRunning = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      final bp = state.blueprint;
      if (bp != null && bp.status == BlueprintStatus.generating && !_isLoopRunning) {
        debugPrint('BlueprintProvider: App resumed, automatically continuing generation...');
        _resumeGeneration(bp);
      }
    }
  }

  @override
  BlueprintState build() {
    // Watch the selected protocol so we reload blueprint when protocol changes
    final protocolState = ref.watch(protocolProvider);
    final selectedId = protocolState.selectedProtocolId;

    if (selectedId != null && _isInitialized) {
      // Trigger a reload when protocol changes (after initial setup)
      Future.microtask(() => fetchBlueprint(selectedId));
    }

    if (!_isInitialized) {
      _isInitialized = true;
      WidgetsBinding.instance.addObserver(this);
      ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
      
      if (selectedId != null) {
        Future.microtask(() => fetchBlueprint(selectedId));
      }
    }

    return const BlueprintState();
  }

  AzureOpenAIService get _aiService => ref.read(azureOpenAIServiceProvider);

  /// Fetch the existing blueprint for a protocol from Supabase
  Future<void> fetchBlueprint(String protocolId) async {
    // Check if we already have it to avoid flicker, but still sync in background
    final currentBp = state.blueprint;
    if (currentBp == null || currentBp.protocolId != protocolId) {
      state = state.copyWith(isLoading: true, error: null, clearBlueprint: true);
    } else {
      // Background refresh — keep current data visible but mark as loading if we want
      // For now, let's NOT mark as loading to avoid UI jitter if we have data
    }

    try {
      final client = SupabaseConfig.client;
      if (client == null || client.auth.currentUser == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      final userId = client.auth.currentUser!.id;

      final response = await client
          .from('protocol_blueprints')
          .select()
          .eq('user_id', userId)
          .eq('protocol_id', protocolId)
          .maybeSingle();

      if (response != null) {
        final blueprint = ProtocolBlueprint.fromSupabase(response);
        // Only block UI with 'isGenerating' if NO weeks are ready yet
        state = BlueprintState(
          blueprint: blueprint,
          isLoading: false,
          isGenerating: blueprint.status == BlueprintStatus.generating && blueprint.weeksGenerated == 0,
          error: null,
        );

        // Resume generation if it was interrupted
        if (blueprint.status == BlueprintStatus.generating) {
          _resumeGeneration(blueprint);
        }
      } else {
        // No blueprint found for this protocol
        state = state.copyWith(isLoading: false, clearBlueprint: true, error: null);
      }
    } catch (e) {
      debugPrint('BlueprintProvider fetch error: $e');
      state = state.copyWith(isLoading: false, error: 'Failed to sync timeline: $e');
    }
  }

  /// Start a protocol with blueprint generation
  /// Called when user confirms the duration picker
  Future<void> startProtocolWithBlueprint(
    String protocolId,
    int durationWeeks,
  ) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return;

    final userId = client.auth.currentUser!.id;
    final startDate = DateTime.now();
    final startDateStr =
        '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    state = state.copyWith(isGenerating: true, error: null);

    try {
      // Upsert: if a blueprint already exists for this protocol, replace it
      final response = await client
          .from('protocol_blueprints')
          .upsert(
            {
              'user_id': userId,
              'protocol_id': protocolId,
              'duration_weeks': durationWeeks,
              'start_date': startDateStr,
              'generation_status': 'generating',
              'weeks_generated': 0,
              'blueprint_data': [],
            },
            onConflict: 'user_id, protocol_id',
          )
          .select()
          .single();

      final blueprint = ProtocolBlueprint.fromSupabase(response);
      state = state.copyWith(blueprint: blueprint, isGenerating: true);

      // Start background generation
      _generateAllWeeks(blueprint);
    } catch (e) {
      debugPrint('BlueprintProvider start error: $e');
      state = state.copyWith(isGenerating: false, error: e.toString());
    }
  }

  /// Resume generation from where it left off
  void _resumeGeneration(ProtocolBlueprint blueprint) {
    if (_isLoopRunning) return;
    if (blueprint.weeksGenerated < blueprint.durationWeeks) {
      _generateAllWeeks(blueprint);
    }
  }

  /// Generate weeks in batches of 2, saving after each batch
  Future<void> _generateAllWeeks(ProtocolBlueprint blueprint) async {
    if (_isLoopRunning) return;
    _isLoopRunning = true;
    state = state.copyWith(syncProgress: 'Initializing...');

    try {
      final client = SupabaseConfig.client;
      if (client == null) {
        _isLoopRunning = false;
        return;
      }

      // Get the protocol data for prompting
      final protocolState = ref.read(protocolProvider);
      final protocol = protocolState.selectedProtocol ??
          await ProtocolRepository.fetchProtocol(profileId: null);
      if (protocol == null) {
        _isLoopRunning = false;
        state = state.copyWith(syncProgress: 'No plan published');
        return;
      }

      int currentWeek = blueprint.weeksGenerated + 1;
      List<BlueprintDay> allDays = List.from(blueprint.days);
      String? previousWeekSummary;

      while (currentWeek <= blueprint.durationWeeks) {
        try {
          // Always generate 1 week at a time — faster, more reliable, better progress visibility
          const int batchSize = 1;
          final batchStartDate =
              blueprint.startDate.add(Duration(days: (currentWeek - 1) * 7));

          debugPrint(
              'BlueprintProvider: Generating Weeks $currentWeek to ${currentWeek + batchSize - 1}/${blueprint.durationWeeks}...');

          List<BlueprintDay>? batchDays;
          int retries = 0;
          Exception? lastError;

          while (retries < 3) {
            try {
              batchDays = await _aiService.generateBlueprintWeeksBatch(
                protocol,
                startWeek: currentWeek,
                count: batchSize,
                totalWeeks: blueprint.durationWeeks,
                startDate: batchStartDate,
                previousWeekSummary: previousWeekSummary,
              );
              
              if (batchDays == null || batchDays.isEmpty) {
                throw Exception('Azure API returned null or empty batch (possible timeout/rate-limit)');
              }
              
              break; // Success
            } catch (e) {
              lastError = e is Exception ? e : Exception(e.toString());
              retries++;
              if (retries < 3) {
                debugPrint('BlueprintProvider: Batch failed ($e). Retrying $retries/3 in ${2 * retries}s...');
                await Future.delayed(Duration(seconds: 2 * retries));
              }
            }
          }

          if (batchDays != null && batchDays.isNotEmpty) {
            allDays.addAll(batchDays);

            // Build a brief summary for the next batch's context
            previousWeekSummary =
                'Weeks $currentWeek-${currentWeek + batchSize - 1} generated. '
                'Focus was on ${batchDays.expand((d) => d.tasks).map((t) => t.category).toSet().take(3).join(', ')}.';

            currentWeek += batchSize;

            // Persist after each batch
            final isComplete = currentWeek > blueprint.durationWeeks;
            await client
                .from('protocol_blueprints')
                .update({
                  'weeks_generated': currentWeek - 1,
                  'blueprint_data': allDays.map((d) => d.toJson()).toList(),
                  'generation_status': isComplete ? 'complete' : 'generating',
                })
                .eq('id', blueprint.id);

            // Update local state. Unlock UI (isGenerating=false) once Week 1 is available.
            final totalWeeks = blueprint.durationWeeks;
            final completedWeeks = currentWeek - 1;
            state = state.copyWith(
              blueprint: blueprint.copyWith(
                weeksGenerated: completedWeeks,
                days: allDays,
                status:
                    isComplete ? BlueprintStatus.complete : BlueprintStatus.generating,
              ),
              isGenerating: completedWeeks == 0 && !isComplete,
              syncProgress: isComplete ? null : 'Week $completedWeeks/$totalWeeks ready',
              clearSyncProgress: isComplete,
            );
          } else {
            throw lastError ?? Exception('Batch generation failed after $retries retries');
          }
        } catch (e) {
          debugPrint('BlueprintProvider batch error: $e');
          // Update status to failed in Supabase
          await client
              .from('protocol_blueprints')
              .update({'generation_status': 'failed'}).eq('id', blueprint.id);

          state = state.copyWith(
            blueprint: blueprint.copyWith(status: BlueprintStatus.failed),
            isGenerating: false,
            clearSyncProgress: true,
            error: 'Generation paused at Week $currentWeek. Tap to retry.',
          );
          _isLoopRunning = false;
          return;
        }
      }

      // All weeks generated
      state = state.copyWith(isGenerating: false, clearSyncProgress: true);
      debugPrint(
          'BlueprintProvider: Blueprint complete! ${allDays.length} days generated.');
    } finally {
      _isLoopRunning = false;
    }
  }

  /// Retry failed generation
  Future<void> retryGeneration() async {
    final bp = state.blueprint;
    if (bp == null || bp.status != BlueprintStatus.failed) return;

    state = state.copyWith(isGenerating: true, error: null);

    // Update Supabase status back to generating
    final client = SupabaseConfig.client;
    if (client != null) {
      await client
          .from('protocol_blueprints')
          .update({'generation_status': 'generating'}).eq('id', bp.id);
    }

    _generateAllWeeks(bp);
  }

  /// Get the BlueprintDay for today
  BlueprintDay? get todayBlueprint {
    final bp = state.blueprint;
    if (bp == null) return null;
    return bp.getDayByDate(DateTime.now());
  }

  /// Get the BlueprintDay for any specific day number
  BlueprintDay? getBlueprintDay(int dayNumber) {
    return state.blueprint?.getDayByNumber(dayNumber);
  }

  /// Check if blueprint is available (at least today's week is generated)
  bool get isBlueprintAvailableForToday {
    final bp = state.blueprint;
    if (bp == null) return false;
    final todayNum = bp.todayDayNumber;
    if (todayNum == null) return false;
    final todayWeek = ((todayNum - 1) / 7).floor() + 1;
    return bp.weeksGenerated >= todayWeek;
  }

  /// Reset the protocol blueprint entirely
  Future<void> resetBlueprint(String protocolId) async {
    final client = SupabaseConfig.client;
    if (client == null || client.auth.currentUser == null) return;

    final userId = client.auth.currentUser!.id;

    try {
      // 1. Kill any active generation loop
      _isLoopRunning = false;

      // 2. Delete from Supabase
      await client
          .from('protocol_blueprints')
          .delete()
          .eq('user_id', userId)
          .eq('protocol_id', protocolId);

      // 3. Clear local state
      state = const BlueprintState();
      
      debugPrint('BlueprintProvider: Blueprint for $protocolId has been reset.');
    } catch (e) {
      debugPrint('BlueprintProvider reset error: $e');
      state = state.copyWith(error: 'Failed to reset: $e');
    }
  }
}

/// Main provider for blueprint state
final blueprintProvider =
    NotifierProvider<BlueprintNotifier, BlueprintState>(() {
  return BlueprintNotifier();
});
