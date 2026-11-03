import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
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

  /// Leaderboard name rule (TC-030 item 9; Henry's REJECT rule, Clara PR #29
  /// r4). The server's patient_leaderboard_top10() applies the IDENTICAL rule
  /// (migration 20261103123000_tc030_leaderboard_name_nfkc), so a name reads
  /// the same on both sides:
  ///   a. NFKC-normalise first (package:unorm_dart; the server uses
  ///      normalize(name, NFKC)).
  ///   b. No name, or any '@' after NFKC (an email or a handle), gives nothing.
  ///   c. Any Default_Ignorable_Code_Point ([_defaultIgnorableRanges]) gives
  ///      nothing.
  ///   d./e. Only letters (\p{L}), combining marks (\p{M}), ASCII space, ASCII
  ///      '-' and the apostrophes ' and ’ are allowed; any digit, '.', ',', '_',
  ///      '+', emoji, symbol, NBSP or other whitespace gives nothing. (c) and
  ///      (e) are checked on the raw value AND its NFKC form, so a
  ///      compatibility character (NBSP, em space, ⓐ, ™, ²) is rejected rather
  ///      than rewritten by NFKC into an allowed one.
  ///   f. An apostrophe must sit between two letters/marks; a leading,
  ///      trailing or doubled one gives nothing.
  ///   g. Spaces and hyphens split the name (trim, collapse runs, drop empty
  ///      pieces); each piece starts at its first letter (a leading combining
  ///      mark is dropped) and a piece with no letter is dropped.
  /// Returns `[]` (-> 'Anonymous') when the name is rejected or nothing is left.
  static List<String> _leaderboardNameParts(String? raw) {
    if (raw == null) return const [];
    final n = unorm.nfkc(raw);
    if (n.contains('@')) return const [];
    if (_hasDefaultIgnorable(raw) || _hasDefaultIgnorable(n)) return const [];
    if (_disallowedChar.hasMatch(raw) || _disallowedChar.hasMatch(n)) return const [];
    if (_strayApostrophe.hasMatch(n)) return const [];

    return n
        .split(_pieceSeparator)
        .map((t) => t.replaceFirst(_leadingNonLetter, ''))
        .where((t) => t.isNotEmpty)
        .toList();
  }

  /// Unicode 17.0.0 DerivedCoreProperties Default_Ignorable_Code_Point, merged
  /// into ranges (identical in 15.1 and 16.0) - the same 17 ranges as the
  /// server's di_r (generator: work/.claude-runs/tc030h3r5/di_ranges.py).
  static const List<(int, int)> _defaultIgnorableRanges = [
    (0x00AD, 0x00AD),
    (0x034F, 0x034F),
    (0x061C, 0x061C),
    (0x115F, 0x1160),
    (0x17B4, 0x17B5),
    (0x180B, 0x180F),
    (0x200B, 0x200F),
    (0x202A, 0x202E),
    (0x2060, 0x206F),
    (0x3164, 0x3164),
    (0xFE00, 0xFE0F),
    (0xFEFF, 0xFEFF),
    (0xFFA0, 0xFFA0),
    (0xFFF0, 0xFFF8),
    (0x1BCA0, 0x1BCA3),
    (0x1D173, 0x1D17A),
    (0xE0000, 0xE0FFF),
  ];

  static bool _hasDefaultIgnorable(String s) {
    for (final cp in s.runes) {
      for (final (lo, hi) in _defaultIgnorableRanges) {
        if (cp >= lo && cp <= hi) return true;
      }
    }
    return false;
  }

  /// Anything that is not a letter, mark, ASCII space, apostrophe or hyphen.
  static final RegExp _disallowedChar = RegExp(r"[^\p{L}\p{M} '’\-]", unicode: true);

  /// An apostrophe not preceded, or not followed, by a letter/mark.
  static final RegExp _strayApostrophe =
      RegExp(r"(?:^|[^\p{L}\p{M}])['’]|['’](?:[^\p{L}\p{M}]|$)", unicode: true);

  /// Runs of ASCII space / hyphen split the name into pieces.
  static final RegExp _pieceSeparator = RegExp(r'[ \-]+');

  /// Everything before a piece's first letter.
  static final RegExp _leadingNonLetter = RegExp(r'^[^\p{L}]+', unicode: true);

  /// A piece's first letter plus any combining marks on it (its first letter
  /// grapheme, matched by code point so an astral letter is never split into a
  /// lone UTF-16 surrogate / U+FFFD).
  static final RegExp _firstLetterCluster = RegExp(r'^\p{L}\p{M}*', unicode: true);

  /// First letter grapheme of a (letter-led) piece, upper-cased.
  static String _initial(String token) =>
      (_firstLetterCluster.stringMatch(token) ?? '').toUpperCase();

  /// Piece with its first letter grapheme upper-cased, the rest untouched (so
  /// "McArdle" / already-capitalised names are preserved).
  static String _capitalize(String token) {
    final head = _firstLetterCluster.stringMatch(token) ?? '';
    return head.toUpperCase() + token.substring(head.length);
  }

  /// Formats a RAW stored name to the leaderboard's "First L." shape (TC-030
  /// item 9, rule h), exactly as the server does (see [_leaderboardNameParts]):
  /// first piece with its first letter capitalised, plus ' ' and the last
  /// piece's first letter and '.'; one piece is the first name alone; a
  /// rejected name gives [fallback]. Capped at [leaderboardNameMaxLength] code
  /// points, as the server's left(..., 18) is.
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

  /// Initials for a leaderboard avatar from a RAW stored name: first + last
  /// initial ("Jordan Rivera" -> "JR"), one initial for a one-piece name, or
  /// [fallback] for a rejected name.
  static String leaderboardInitials(String? raw, {String fallback = '?'}) {
    final parts = _leaderboardNameParts(raw);
    if (parts.isEmpty) return fallback;
    if (parts.length == 1) return _initial(parts.first);
    return _initial(parts.first) + _initial(parts.last);
  }

  /// The trailing ". " of an already-formatted "First L." (the only '.' the
  /// rule ever produces).
  static final RegExp _formattedInitialDot = RegExp(r'^(.* [\p{L}\p{M}]+)\.$', unicode: true);

  /// The server returns names already formatted ("Jordan R."); '.' is not an
  /// allowed character in a raw name, so the app drops that one trailing
  /// initial dot before re-applying the same rule defensively.
  static String? _unformat(String? serverName) {
    if (serverName == null) return null;
    final m = _formattedInitialDot.firstMatch(serverName);
    return m == null ? serverName : m.group(1);
  }

  /// Display name for a patient_leaderboard_top10() row's `name` (already
  /// formatted by the server). Re-applies the shared rule defensively, and is
  /// idempotent on every value the server (or [formatLeaderboardName]) returns.
  static String leaderboardDisplayName(String? serverName, {String fallback = 'Anonymous'}) =>
      formatLeaderboardName(_unformat(serverName), fallback: fallback);

  /// Initials for a patient_leaderboard_top10() row's `name` ("Jordan R." ->
  /// "JR"), or [fallback] for an anonymous row (including the literal
  /// 'Anonymous' the server returns for a rejected name).
  static String leaderboardDisplayInitials(String? serverName, {String fallback = '?'}) =>
      isLeaderboardAnonymous(serverName)
          ? fallback
          : leaderboardInitials(_unformat(serverName), fallback: fallback);

  /// True when a leaderboard row renders as 'Anonymous' (TC-030 item 20: the
  /// avatar shows the Lucide `user` glyph instead of initials).
  static bool isLeaderboardAnonymous(String? serverName) =>
      leaderboardDisplayName(serverName) == anonymousLeaderboardName;

  /// The name shown for a rejected / missing name.
  static const String anonymousLeaderboardName = 'Anonymous';

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
