import 'package:flutter/foundation.dart';

import '../../data/fixtures.dart';
import '../../widgets/badge.dart';

const _title = 'HbA1c';
const _subtitle = 'Average blood sugar over the past 2–3 months';

/// A trend that renders above the default range, for the `above` fixture
/// state only — screens.md's demo value, never [hba1cTrend] (which stays
/// within range end to end). Visual-only, same as the other screens'
/// non-happy-path screenshot fixtures.
final List<HbA1cPoint> _aboveRangeTrend = [
  HbA1cPoint(date: DateTime(2026, 4, 2), percent: 5.6),
  HbA1cPoint(date: DateTime(2026, 6, 4), percent: 5.6),
  HbA1cPoint(date: DateTime(2026, 8, 6), percent: 5.8),
  HbA1cPoint(date: DateTime(2026, 10, 14), percent: 5.9),
];

/// Maps the screenshot harness's `?state=` query param to a fixture
/// [LabTrendsState]. Unknown/missing values fall back to `default`.
LabTrendsState labTrendsStateForQueryState(String? queryState) => switch (queryState) {
      'loading' => LabTrendsState.loading(),
      'single' => LabTrendsState.single(),
      'error' => LabTrendsState.error(),
      'above' => LabTrendsState.above(),
      _ => LabTrendsState.defaultState(),
    };

/// Immutable view-state for [LabTrendsView]. Each factory matches one of the
/// 5 screenshot states (default, loading, single, error, above).
@immutable
class LabTrendsState {
  const LabTrendsState({
    this.isLoading = false,
    this.isSingle = false,
    this.isCachedError = false,
    this.isAboveRange = false,
    this.points = const [],
    this.rangeCeiling = hba1cDefaultRangeCeiling,
    this.title = _title,
    this.subtitle = _subtitle,
  });

  factory LabTrendsState.loading() => const LabTrendsState(isLoading: true);

  factory LabTrendsState.defaultState({List<HbA1cPoint>? points}) =>
      LabTrendsState(points: points ?? hba1cTrend);

  // T-BIO-02 adjacent: a single reading shows a Baseline badge and an empty
  // chart card instead of a one-point line — there's nothing to trend yet.
  factory LabTrendsState.single({List<HbA1cPoint>? points}) =>
      LabTrendsState(isSingle: true, points: points ?? [hba1cTrend.first]);

  // Cached + last-updated date: offline/refresh-failed still shows the last
  // known trend, never a blank screen.
  factory LabTrendsState.error() => LabTrendsState(isCachedError: true, points: hba1cTrend);

  // Edge: above default range. Uses its own fixture trend (never the
  // canonical in-range [hba1cTrend]) purely to demonstrate the warn styling;
  // the line itself never changes colour for an above-range point.
  factory LabTrendsState.above() => LabTrendsState(isAboveRange: true, points: _aboveRangeTrend);

  final bool isLoading;
  final bool isSingle;
  final bool isCachedError;
  final bool isAboveRange;
  final List<HbA1cPoint> points;
  final double rangeCeiling;
  final String title;
  final String subtitle;

  HbA1cPoint get latest => points.last;

  bool get isAboveRangeValue => latest.percent > rangeCeiling;

  String get badgeLabel {
    if (isSingle) return 'Baseline';
    return isAboveRangeValue ? 'Above default range' : 'Within default range';
  }

  BadgeVariant get badgeVariant {
    if (isSingle) return BadgeVariant.brand;
    return isAboveRangeValue ? BadgeVariant.warn : BadgeVariant.brand;
  }

  String get latestDateLabel => formatDate(latest.date);

  double get pointsSinceBaseline => points.length < 2 ? 0 : latest.percent - points.first.percent;

  String get metaLine {
    if (isSingle) return '$latestDateLabel · your first result';
    final delta = pointsSinceBaseline;
    final sign = delta >= 0 ? '+' : '−';
    final magnitude = delta.abs().toStringAsFixed(1);
    final baselineDate = formatDate(points.first.date, year: false);
    return '$latestDateLabel · $sign$magnitude points since baseline ($baselineDate)';
  }

  String get cachedErrorMessage => "Couldn't refresh. Showing results saved on this phone, last updated $latestDateLabel.";

  static String formatDate(DateTime date, {bool year = true}) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[date.month - 1];
    return year ? '$month ${date.day}, ${date.year}' : '$month ${date.day}';
  }
}
