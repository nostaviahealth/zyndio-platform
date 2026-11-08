import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A longevity score supplied by a validated source (Zyndio's formula), with
/// an optional trend versus the previous period.
class LongevityScore {
  const LongevityScore({required this.score, this.trendPercent, this.trendPeriod = 'this quarter'});

  /// 0-100.
  final int score;

  /// Signed percent change versus the previous period, if known.
  final int? trendPercent;
  final String trendPeriod;
}

/// No source exists in the app yet, so this is null and Today shows no ring
/// (TC-025 Z2: the ring needs BOTH featureFlags.longevityScoreEnabled AND a
/// real value). Demo builds override it with a fictional score.
final longevityScoreProvider = Provider<LongevityScore?>((ref) => null);
