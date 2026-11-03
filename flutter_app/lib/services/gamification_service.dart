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

  /// True only for the signed-in patient's own leaderboard row. The server
  /// sets `is_me`; the leaderboard never carries patient ids (TC-026).
  static bool isLeaderboardSelf(Map<String, dynamic> row) => row['is_me'] == true;

  /// Max characters rendered for a leaderboard display name, so a long or
  /// malformed value can't blow out the row/podium layout (TC-030 item 9).
  static const int leaderboardNameMaxLength = 18;

  /// Leaderboard name rule (TC-030 item 9, Henry's ruling on Clara PR #29 r3).
  /// The server's patient_leaderboard_top10() applies the IDENTICAL rule
  /// (migration 20261103110000), so a name reads the same on both sides:
  ///   1. No name, or any value containing '@' (an email or a handle), is never
  ///      used to build a name: nothing usable is returned (-> fallback,
  ///      'Anonymous'). Not even an initial.
  ///   2. "Last, First" (comma form) is read as "First Last".
  ///   3. Tokens are split on any run of characters that is NOT a letter
  ///      (\p{L}), mark (\p{M}), number (\p{N}) or apostrophe (' or ’), so
  ///      whitespace, punctuation, '+', emoji and invisible format characters
  ///      (soft hyphen, LRM/RLM, RLO, ZWSP/ZWNJ/ZWJ, U+180E, U+2062, BOM...)
  ///      are all separators.
  ///   4. Each token drops everything before its first letter (so a leading
  ///      combining mark, digit or apostrophe never leads); a token with no
  ///      letter at all is dropped.
  /// Returns `[]` when nothing usable is left.
  static List<String> _leaderboardNameParts(String? raw) {
    if (raw == null || raw.contains('@')) return const [];

    var working = raw;
    final commaIndex = working.indexOf(',');
    if (commaIndex >= 0) {
      working = '${working.substring(commaIndex + 1)} ${working.substring(0, commaIndex)}';
    }

    return working
        .split(_nameSeparator)
        .map((t) => t.replaceFirst(_leadingNonLetter, ''))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Any run that is not a letter, mark, number or apostrophe separates tokens.
  static final RegExp _nameSeparator = RegExp(r"[^\p{L}\p{M}\p{N}'’]+", unicode: true);

  /// Everything before a token's first letter.
  static final RegExp _leadingNonLetter = RegExp(r'^[^\p{L}]+', unicode: true);

  /// A token's first letter plus any combining marks on it (the first letter
  /// grapheme of the token, matched by code point so an astral letter is never
  /// split into a lone UTF-16 surrogate / U+FFFD).
  static final RegExp _firstLetterCluster = RegExp(r'^\p{L}\p{M}*', unicode: true);

  /// First letter grapheme of a (letter-led) token, upper-cased.
  static String _initial(String token) =>
      (_firstLetterCluster.stringMatch(token) ?? '').toUpperCase();

  /// Token with its first letter grapheme upper-cased, the rest untouched (so
  /// "McArdle" / already-capitalised names are preserved).
  static String _capitalize(String token) {
    final head = _firstLetterCluster.stringMatch(token) ?? '';
    return head.toUpperCase() + token.substring(head.length);
  }

  /// Formats a raw name to the leaderboard's "First L." shape (TC-030 item 9),
  /// with the same rule as the server (see [_leaderboardNameParts]): first name
  /// capitalised plus the last token's initial and a dot; a single token is the
  /// first name alone; an email/handle or a name with no letters gives
  /// [fallback]. Capped at [leaderboardNameMaxLength] code points, as the
  /// server's left(..., 18) is.
  static String formatLeaderboardName(String? raw, {String fallback = 'Anonymous'}) {
    final parts = _leaderboardNameParts(raw);
    if (parts.isEmpty) return fallback;

    final first = _capitalize(parts.first);
    final formatted = parts.length == 1 ? first : '$first ${_initial(parts.last)}.';

    final runes = formatted.runes;
    return runes.length > leaderboardNameMaxLength
        ? String.fromCharCodes(runes.take(leaderboardNameMaxLength))
        : formatted;
  }

  /// Initials for a leaderboard avatar when no photo is shown (TC-030 item 9):
  /// first + last initial (e.g. "Jordan Rivera" -> "JR"), one initial for a
  /// one-token name, or [fallback] for an email/handle or a name with no letters.
  static String leaderboardInitials(String? raw, {String fallback = '?'}) {
    final parts = _leaderboardNameParts(raw);
    if (parts.isEmpty) return fallback;
    if (parts.length == 1) return _initial(parts.first);
    return _initial(parts.first) + _initial(parts.last);
  }

  /// Maps one patient_leaderboard_top10() row to the shape the leagues UI
  /// reads: name, avatar_url, league_xp, is_me. No user/patient id.
  ///
  /// Henry (TC-030 item 9): no profile photos of OTHER patients on the
  /// leaderboard - only the caller's own row keeps its avatar; every other
  /// row drops `avatar_url` so it renders as an initials/placeholder avatar.
  static Map<String, dynamic> standingFromRow(Map<String, dynamic> row) {
    final isMe = row['is_me'] == true;
    return <String, dynamic>{
      'name': row['name'],
      'avatar_url': isMe ? row['avatar_url'] : null,
      'league_xp': row['league_xp'],
      'is_me': isMe,
    };
  }

  /// Fetches the top players for a specific league.
  static Future<List<Map<String, dynamic>>> fetchStandings(League league) async {
    final client = SupabaseConfig.client;
    if (client == null) return [];

    try {
      // patient_accounts is patient-self RLS only, so a cross-patient
      // leaderboard read goes through the security-definer
      // patient_leaderboard_top10() RPC instead. Signed-in only, scoped
      // server-side to the caller's own clinic, `name` is already first
      // name + last initial (e.g. "Jordan R."), and it returns `is_me` for
      // the own-row highlight instead of any patient id - see
      // 20261102110000_tc026_leaderboard_clinic_scope.sql and
      // 20261102130000_tc026_leaderboard_is_me.sql.
      final response = await client.rpc('patient_leaderboard_top10');
      return List<Map<String, dynamic>>.from(response as List)
          .map(standingFromRow)
          .toList();
    } catch (e) {
      debugPrint('[GAMIFICATION] Fetch standings error: $e');
      return [];
    }
  }

}
