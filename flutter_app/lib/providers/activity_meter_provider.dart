import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/activity_meter_service.dart';
import 'intelligence_provider.dart';

/// Snapshot of Activity Meter state for the UI.
class ActivityMeterState {
  final int score;
  final ActivityZone zone;
  final double trendPct; // % change vs 7-day average
  final String riskMessage;
  final String praiseMessage;
  final String recommendation;
  final bool hasData;

  const ActivityMeterState({
    this.score = 0,
    this.zone = ActivityZone.critical,
    this.trendPct = 0,
    this.riskMessage = '',
    this.praiseMessage = '',
    this.recommendation = '',
    this.hasData = false,
  });
}

/// Computes the Activity Meter score from wearable, lab, and food data.
final activityMeterProvider = Provider<ActivityMeterState>((ref) {
  final wearable = ref.watch(wearableStateProvider).value;
  final intelligence = ref.watch(intelligenceDataProvider).value;

  // ── Guard: no wearable data ──
  if (wearable == null ||
      (wearable.steps == 0 &&
          wearable.exerciseMinutes == 0 &&
          wearable.strainScore == 0)) {
    return const ActivityMeterState();
  }

  // ── Lab booster ──
  int labBooster = 0;
  if (intelligence != null && intelligence.healthDomains.isNotEmpty) {
    labBooster = ActivityMeterService.calculateLabBooster(
      healthDomains: intelligence.healthDomains
          .map((d) => {'name': d.name, 'score': d.score})
          .toList(),
    );
  }

  // ── Food booster (fetched synchronously from cached data if available) ──
  // Food logs are not cached in a provider yet — we use 0 as default.
  // The food booster is a small enhancement; wearable data is primary.
  int foodBooster = 0;

  // ── Base score ──
  final int baseScore = ActivityMeterService.calculateActivityScore(
    steps: wearable.steps,
    exerciseMinutes: wearable.exerciseMinutes,
    strainScore: wearable.strainScore,
    sleepScore: wearable.sleepScore,
    recoveryScore: wearable.recoveryScore,
    labBooster: labBooster,
    foodBooster: foodBooster,
  );

  // ── Trend: compare to a rough 7-day estimate ──
  // We use strain + steps as a proxy for weekly baseline.
  // True 7-day historical scoring would need a backend table;
  // for now we approximate from available data.
  final double trendPct = 0; // Neutral until we wire historical storage
  final int trendBooster = ActivityMeterService.calculateTrendBooster(
    currentDayScore: baseScore.toDouble(),
    sevenDayAvg: baseScore.toDouble(), // same = neutral for now
  );

  final int finalScore = (baseScore + trendBooster).clamp(0, 100);
  final zone = ActivityMeterService.getZone(finalScore);

  return ActivityMeterState(
    score: finalScore,
    zone: zone,
    trendPct: trendPct,
    riskMessage: ActivityMeterService.getRiskMessage(finalScore),
    praiseMessage: ActivityMeterService.getPraiseMessage(finalScore, trendPct),
    recommendation: ActivityMeterService.getRecommendation(finalScore),
    hasData: true,
  );
});
