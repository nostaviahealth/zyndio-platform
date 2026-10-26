import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/audio_engine.dart';
import '../config/supabase_config.dart';
import '../screens/settings/meditation_stats_screen.dart';

part 'meditation_state_provider.g.dart';

class MeditationState {
  final int selectedMinutes;
  final int remainingSeconds;
  final bool isRunning;
  final bool isAtmosphereActive;
  final DateTime? lastTick;

  MeditationState({
    this.selectedMinutes = 10,
    this.remainingSeconds = 600,
    this.isRunning = false,
    this.isAtmosphereActive = false,
    this.lastTick,
  });

  MeditationState copyWith({
    int? selectedMinutes,
    int? remainingSeconds,
    bool? isRunning,
    bool? isAtmosphereActive,
    DateTime? lastTick,
  }) {
    return MeditationState(
      selectedMinutes: selectedMinutes ?? this.selectedMinutes,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      isAtmosphereActive: isAtmosphereActive ?? this.isAtmosphereActive,
      lastTick: lastTick ?? this.lastTick,
    );
  }
}

@riverpod
class MeditationNotifier extends _$MeditationNotifier {
  Timer? _timer;

  @override
  MeditationState build() {
    ref.onDispose(() => _timer?.cancel());
    return MeditationState();
  }

  void setDuration(int minutes) {
    if (state.isRunning) return;
    state = state.copyWith(
      selectedMinutes: minutes,
      remainingSeconds: minutes * 60,
    );
  }

  Future<void> toggleTimer() async {
    if (state.isRunning) {
      await stopTimer();
    } else {
      await startTimer();
    }
  }

  Future<void> startTimer() async {
    if (state.remainingSeconds <= 0) {
      state = state.copyWith(remainingSeconds: state.selectedMinutes * 60);
    }

    state = state.copyWith(
      isRunning: true,
      lastTick: DateTime.now(),
    );

    if (state.isAtmosphereActive) {
      AudioEngine().start(AudioMode.flow, flowVariant: FlowVariant.pink);
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  Future<void> stopTimer() async {
    _timer?.cancel();
    await AudioEngine().stop();
    state = state.copyWith(isRunning: false, lastTick: null);
  }

  Future<void> toggleAtmosphere() async {
    final newState = !state.isAtmosphereActive;
    state = state.copyWith(isAtmosphereActive: newState);
    
    if (state.isRunning) {
      if (newState) {
        AudioEngine().start(AudioMode.flow, flowVariant: FlowVariant.pink);
      } else {
        AudioEngine().stop();
      }
    }
  }

  void _tick() {
    if (!state.isRunning || state.lastTick == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(state.lastTick!).inSeconds;
    
    if (elapsed >= 1) {
      final newRemaining = (state.remainingSeconds - elapsed).clamp(0, 7200);
      state = state.copyWith(
        remainingSeconds: newRemaining,
        lastTick: now,
      );

      if (newRemaining <= 0) {
        _onSessionComplete();
      }
    }
  }

  Future<void> _onSessionComplete() async {
    final minutesCompleted = state.selectedMinutes;
    final mode = state.isAtmosphereActive ? 'flow' : 'void';
    
    // Stop the UI timer immediately
    _timer?.cancel();
    state = state.copyWith(isRunning: false, lastTick: null);

    // Play completion chime
    await AudioEngine().playBell();

    // Trigger Supabase log early so it happens while audio fades out
    final logFuture = () async {
      try {
        final client = SupabaseConfig.client;
        final userId = SupabaseConfig.currentUser?.id;
        
        if (client != null && userId != null) {
          await client.from('meditation_sessions').insert({
            'user_id': userId,
            'date': DateTime.now().toIso8601String().split('T').first,
            'minutes': minutesCompleted,
            'mode': mode,
          });
          
          ref.invalidate(meditationStatsProvider);
        }
      } catch (e) {
        debugPrint('Failed to log meditation session: $e');
      }
    }();

    // Fade out audio
    await AudioEngine().stop();
    await logFuture;
  }
}
