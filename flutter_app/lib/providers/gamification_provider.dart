import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gamification_service.dart';
import '../config/supabase_config.dart';
import '../models/patient_profile.dart'; // <--- Added Import
import 'patient_provider.dart';

// ─── State ──────────────────────────────────────────────────────────────────

class GamificationState {
  final int xp; // Lifetime XP
  final int coins; // Lifetime Coins
  final int leagueXp; // Monthly XP
  final League league;
  final double leagueProgress;
  final Map<String, int> badges;
  final RewardEvent? lastReward;

  const GamificationState({
    this.xp = 0,
    this.coins = 0,
    this.leagueXp = 0,
    this.league = League.bronze,
    this.leagueProgress = 0.0,
    this.badges = const {},
    this.lastReward,
  });

  GamificationState copyWith({
    int? xp,
    int? coins,
    int? leagueXp,
    League? league,
    double? leagueProgress,
    Map<String, int>? badges,
    RewardEvent? lastReward,
    bool clearReward = false,
  }) {
    return GamificationState(
      xp: xp ?? this.xp,
      coins: coins ?? this.coins,
      leagueXp: leagueXp ?? this.leagueXp,
      league: league ?? this.league,
      leagueProgress: leagueProgress ?? this.leagueProgress,
      badges: badges ?? this.badges,
      lastReward: clearReward ? null : (lastReward ?? this.lastReward),
    );
  }
}

/// A reward event for the UI to display.
class RewardEvent {
  final String label;
  final int xp;
  final int coins;
  final bool leveledUp; // Kept for backward compatibility or general "tier up"
  final League? promotedTo;
  final DateTime timestamp;

  const RewardEvent({
    required this.label,
    required this.xp,
    required this.coins,
    this.leveledUp = false,
    this.promotedTo,
    required this.timestamp,
  });
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class GamificationNotifier extends Notifier<GamificationState> {
  @override
  GamificationState build() {
    // Listen for profile changes to keep gamification state in sync reactively.
    // We use ref.listen instead of ref.watch in build to avoid rebuilding the entire
    // notifier and wiping the 'lastReward' ephemeral state during reward events.
    ref.listen<AsyncValue<PatientProfile?>>(patientProfileProvider, (previous, next) {
      next.whenData((profile) {
        if (profile == null) return;
        
        // Update the numbers but preserve any existing 'lastReward' event
        state = state.copyWith(
          xp: profile.xp,
          coins: profile.coins,
          leagueXp: profile.leagueXp,
          league: GamificationService.calculateLeague(profile.leagueXp),
          leagueProgress: GamificationService.leagueProgress(profile.leagueXp),
          badges: profile.leagueBadges,
        );
        
        // Check for resets if this is a fresh profile load
        _checkMonthlyReset(profile);
      });
    });

    // Initial seeding if profile is already available
    final profile = ref.read(patientProfileProvider).value;
    if (profile == null) return const GamificationState();

    return GamificationState(
      xp: profile.xp,
      coins: profile.coins,
      leagueXp: profile.leagueXp,
      league: GamificationService.calculateLeague(profile.leagueXp),
      leagueProgress: GamificationService.leagueProgress(profile.leagueXp),
      badges: profile.leagueBadges,
    );
  }

  /// Checks if the league needs to be reset for a new month.
  void _checkMonthlyReset(PatientProfile profile) {
    final now = DateTime.now();
    final resetDate = profile.leagueResetAt;
    
    // If current time is after the stored reset date, trigger reset
    if (now.isAfter(resetDate)) {
      // Calculate next reset (1st of next month)
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      final nextReset = DateTime(nextYear, nextMonth, 1);
      
      GamificationService.resetLeague(nextReset).then((result) {
        if (result != null && result['success'] == true) {
          debugPrint('[GAMIFICATION] League reset successful for new season');
          refresh(); // Pull new state from server
        }
      });
    }
  }

  /// Awards a reward. Calls Supabase RPC and updates local state.
  /// Returns true if the reward was successfully granted (not a duplicate).
  Future<bool> awardReward(RewardType type, {String? referenceId}) async {
    final result = await GamificationService.awardReward(
      type,
      referenceId: referenceId,
    );

    if (!result.success) {
      debugPrint('[GAMIFICATION] Reward skipped: ${result.message}');
      return false;
    }

    final oldLeague = state.league;
    final newXp = result.totalXp;
    final newCoins = result.totalCoins;
    final newLeagueXp = result.leagueXp;
    final newLeague = GamificationService.calculateLeague(newLeagueXp);
    final promoted = newLeague.index > oldLeague.index;

    state = state.copyWith(
      xp: newXp,
      coins: newCoins,
      leagueXp: newLeagueXp,
      league: newLeague,
      leagueProgress: GamificationService.leagueProgress(newLeagueXp),
      lastReward: RewardEvent(
        label: type.label,
        xp: result.xpEarned,
        coins: result.coinsEarned,
        leveledUp: promoted,
        promotedTo: promoted ? newLeague : null,
        timestamp: DateTime.now(),
      ),
    );

    // Update the profile provider's local state to stay in sync
    final profileNotifier = ref.read(patientProfileProvider.notifier);
    final currentProfile = ref.read(patientProfileProvider).value;
    if (currentProfile != null) {
      profileNotifier.state = AsyncData(currentProfile.copyWith(
        xp: newXp,
        coins: newCoins,
        leagueXp: newLeagueXp,
        currentLeague: newLeague.name,
      ));
    }

    // Haptic feedback
    if (promoted) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    debugPrint('[GAMIFICATION] ✨ ${type.label}: +${result.xpEarned} XP, +${result.coinsEarned} Coins (Total: $newXp XP, $newCoins Coins, League ${newLeague.displayName})');
    return true;
  }

  /// Clears the last reward event (after UI has displayed it).
  void clearLastReward() {
    state = state.copyWith(clearReward: true);
  }

  /// Force refresh from server.
  Future<void> refresh() async {
    final client = SupabaseConfig.client;
    final userId = SupabaseConfig.currentUser?.id;
    if (client == null || userId == null) return;

    try {
      final response = await client
          .from('profiles')
          .select('xp, coins, league_xp, league_badges')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final xp = response['xp'] as int? ?? 0;
        final coins = response['coins'] as int? ?? 0;
        final leagueXp = response['league_xp'] as int? ?? 0;
        final badges = (response['league_badges'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v as int),
            ) ?? const {};

        state = GamificationState(
          xp: xp,
          coins: coins,
          leagueXp: leagueXp,
          league: GamificationService.calculateLeague(leagueXp),
          leagueProgress: GamificationService.leagueProgress(leagueXp),
          badges: badges,
        );
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Provider refresh error: $e');
    }
  }
}

// ─── Providers ──────────────────────────────────────────────────────────────

final gamificationProvider =
    NotifierProvider<GamificationNotifier, GamificationState>(() {
  return GamificationNotifier();
});

/// Fetches the standings for the user's current league.
final leagueStandingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  // Global leaderboard: league parameter is ignored in the service now
  return GamificationService.fetchStandings(League.bronze); 
});

/// Convenience: just the last reward event for the UI toast.
final lastRewardEventProvider = Provider<RewardEvent?>((ref) {
  return ref.watch(gamificationProvider).lastReward;
});
