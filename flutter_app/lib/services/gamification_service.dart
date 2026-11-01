import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';

/// Reward type definitions with their XP and Coin values.
///
/// Kept minimal: each activity has a fixed payout.
/// Duplicate prevention is handled server-side via `reference_id`.
enum RewardType {
  taskComplete(xp: 25, coins: 5, label: 'Task Completed'),
  mealScan(xp: 30, coins: 8, label: 'Meal Scanned'),
  dailyStepsGoal(xp: 100, coins: 20, label: '10K Steps'),
  allTasksComplete(xp: 150, coins: 30, label: 'All Tasks Done'),
  streakDay(xp: 50, coins: 10, label: 'Streak Day'),
  workoutComplete(xp: 40, coins: 10, label: 'Workout Done'),
  labVerified(xp: 500, coins: 50, label: 'Report Verified');

  final int xp;
  final int coins;
  final String label;
  const RewardType({required this.xp, required this.coins, required this.label});
}

/// League tiers for monthly competitive seasons.
enum League {
  bronze(
    threshold: 0,
    color: Color(0xFFCD7F32),
    gradient: [Color(0xFF8B4513), Color(0xFFD2691E), Color(0xFFFF8C00)],
  ),
  silver(
    threshold: 2000,
    color: Color(0xFF94A3B8),
    gradient: [Color(0xFF475569), Color(0xFF94A3B8), Color(0xFFE2E8F0)],
  ),
  gold(
    threshold: 6000,
    color: Color(0xFFF59E0B),
    gradient: [Color(0xFFB45309), Color(0xFFF59E0B), Color(0xFFFDE047)],
  ),
  platinum(
    threshold: 12000,
    color: Color(0xFF3B82F6),
    gradient: [Color(0xFF1E40AF), Color(0xFF3B82F6), Color(0xFF93C5FD)],
  ),
  diamond(
    threshold: 18000,
    color: Color(0xFF8B5CF6),
    gradient: [Color(0xFF5B21B6), Color(0xFF8B5CF6), Color(0xFFC4B5FD), Color(0xFFF472B6)],
  ),
  legendary(
    threshold: 25000,
    color: Color(0xFFEF4444),
    gradient: [Color(0xFF7F1D1D), Color(0xFFEF4444), Color(0xFFFCD34D), Color(0xFF1E293B)],
  );

  final int threshold;
  final Color color;
  final List<Color> gradient;
  const League({required this.threshold, required this.color, required this.gradient});

  String get displayName => name[0].toUpperCase() + name.substring(1);
}

/// Result returned after attempting to award a reward.
class RewardResult {
  final bool success;
  final int xpEarned;
  final int coinsEarned;
  final int totalXp;
  final int totalCoins;
  final int leagueXp;
  final String? message;

  const RewardResult({
    this.success = false,
    this.xpEarned = 0,
    this.coinsEarned = 0,
    this.totalXp = 0,
    this.totalCoins = 0,
    this.leagueXp = 0,
    this.message,
  });

  factory RewardResult.fromJson(Map<String, dynamic> json) {
    return RewardResult(
      success: json['success'] as bool? ?? false,
      xpEarned: json['xp_earned'] as int? ?? 0,
      coinsEarned: json['coins_earned'] as int? ?? 0,
      totalXp: json['total_xp'] as int? ?? 0,
      totalCoins: json['total_coins'] as int? ?? 0,
      leagueXp: json['league_xp'] as int? ?? 0,
      message: json['message'] as String?,
    );
  }
}

/// Thin service layer over the Supabase `award_reward` RPC.
class GamificationService {
  /// Awards a reward to the current user.
  ///
  /// [referenceId] should be unique per reward event to prevent duplicates.
  /// Example: `task_abc123_2024-04-26` or `steps_2024-04-26`.
  static Future<RewardResult> awardReward(
    RewardType type, {
    String? referenceId,
  }) async {
    final client = SupabaseConfig.client;
    final userId = SupabaseConfig.currentUser?.id;
    if (client == null || userId == null) {
      return const RewardResult(message: 'Not authenticated');
    }

    try {
      final response = await client.rpc('award_reward', params: {
        'p_user_id': userId,
        'p_reward_type': type.name,
        'p_xp_amount': type.xp,
        'p_coins_amount': type.coins,
        'p_reference_id': referenceId,
      });

      if (response is Map<String, dynamic>) {
        return RewardResult.fromJson(response);
      }
      return const RewardResult(message: 'Unexpected response');
    } catch (e) {
      debugPrint('[GAMIFICATION] Award error: $e');
      return RewardResult(message: e.toString());
    }
  }

  /// Fetches current XP and Coins from the profile.
  static Future<({int xp, int coins})?> fetchBalance() async {
    final client = SupabaseConfig.client;
    final userId = SupabaseConfig.currentUser?.id;
    if (client == null || userId == null) return null;

    try {
      final response = await client
          .from('patient_accounts')
          .select('xp, coins')
          .eq('patient_id', userId)
          .maybeSingle();

      if (response != null) {
        return (
          xp: response['xp'] as int? ?? 0,
          coins: response['coins'] as int? ?? 0,
        );
      }
    } catch (e) {
      debugPrint('[GAMIFICATION] Fetch balance error: $e');
    }
    return null;
  }

  /// Calculates user league from monthly XP.
  static League calculateLeague(int leagueXp) {
    final reversedLeagues = League.values.reversed.toList();
    for (final league in reversedLeagues) {
      if (leagueXp >= league.threshold) return league;
    }
    return League.bronze;
  }

  /// XP progress within the current league toward the next one (0.0 → 1.0).
  static double leagueProgress(int leagueXp) {
    final currentLeague = calculateLeague(leagueXp);
    if (currentLeague == League.legendary) return 1.0;

    final nextLeague = League.values[currentLeague.index + 1];
    final range = nextLeague.threshold - currentLeague.threshold;
    if (range <= 0) return 1.0;
    return ((leagueXp - currentLeague.threshold) / range).clamp(0.0, 1.0);
  }

  /// Resets the user's league for a new month.
  static Future<Map<String, dynamic>?> resetLeague(DateTime nextReset) async {
    final client = SupabaseConfig.client;
    final userId = SupabaseConfig.currentUser?.id;
    if (client == null || userId == null) return null;

    try {
      final response = await client.rpc('reset_league', params: {
        'p_user_id': userId,
        'p_next_reset': nextReset.toIso8601String(),
      });
      return response as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[GAMIFICATION] Reset league error: $e');
      return null;
    }
  }

  /// Fetches the top players for a specific league.
  static Future<List<Map<String, dynamic>>> fetchStandings(League league) async {
    final client = SupabaseConfig.client;
    if (client == null) return [];

    try {
      // patient_accounts is patient-self RLS only, so a cross-patient
      // leaderboard read goes through the security-definer
      // patient_leaderboard_top10() RPC instead (exposes only these 4
      // non-sensitive columns, nothing else).
      final response = await client.rpc('patient_leaderboard_top10');
      return List<Map<String, dynamic>>.from(response as List).map((row) {
        return <String, dynamic>{
          'user_id': row['patient_id'],
          'name': row['name'],
          'avatar_url': row['avatar_url'],
          'league_xp': row['league_xp'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[GAMIFICATION] Fetch standings error: $e');
      return [];
    }
  }

}
