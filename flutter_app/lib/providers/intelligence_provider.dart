import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase_config.dart';
import '../data/health_repository.dart';
import '../models/intelligence_data.dart';
import '../services/correlation_engine.dart';
import 'lab_reports_provider.dart';
import 'patient_provider.dart';
import 'wearable_sync_provider.dart';

/// Watches only the profile ID (not the full profile object) to minimize
/// unnecessary stream re-subscriptions from profile refreshes.
final _profileIdProvider = Provider<String?>((ref) {
  return ref.watch(patientProfileProvider).value?.id;
});

/// Fetches the latest intelligence data for the current patient
/// Uses StreamProvider for real-time updates from Supabase.
/// Only re-subscribes when the profile ID actually changes.
final intelligenceDataProvider = StreamProvider<IntelligenceData?>((ref) {
  final profileId = ref.watch(_profileIdProvider);
  if (profileId == null) return Stream.value(null);

  final client = SupabaseConfig.client;
  if (client == null) return Stream.value(null);

  // Keep alive to avoid teardown/re-subscribe cycles on transient rebuilds
  ref.keepAlive();

  print('DEBUG: intelligenceDataProvider - Subscribe for profile: $profileId');

  return client
      .from('intelligence_data')
      .stream(primaryKey: ['id'])
      .eq('profile_id', profileId)
      .order('generated_at', ascending: false)
      .limit(1) 
      .map((data) {
        if (data.isEmpty) {
          print('DEBUG: Stream received empty list');
          return null;
        }
        try {
          final item = data.first;
          print('DEBUG: Stream using record: ${item['id']}');
          return IntelligenceData.fromJson(item);
        } catch (e) {
          print('DEBUG: Error parsing intelligence data: $e');
          return null;
        }
      })
      .handleError((error, stackTrace) {
        print('DEBUG: intelligenceDataProvider stream error: $error');
      });
});

// ──────────────────────────────────────────────────────────────────────────────
// Wearable State — lightweight snapshot of today's key metrics + scores
// ──────────────────────────────────────────────────────────────────────────────

class WearableSnapshot {
  final int strainScore;
  final int recoveryScore;
  final int stressScore;
  final int stressHigh;
  final int stressLow;
  final int stressAvg;
  final int sleepScore;
  final int energyScore;
  final double sleepHours;
  final double sleepEfficiency;
  final double? hrv;
  final int? rhr;
  final double? hrvBaseline;
  final int? rhrBaseline;
  final int steps;
  final int exerciseMinutes;
  final double? respiratoryRate;
  final double? bloodOxygen;
  final double? skinTemperature;
  final double? vo2Max;
  final double activeEnergy;
  final int? heartRateAvg;

  const WearableSnapshot({
    this.strainScore = 0,
    this.recoveryScore = 0,
    this.stressScore = 0,
    this.stressHigh = 0,
    this.stressLow = 0,
    this.stressAvg = 0,
    this.sleepScore = 0,
    this.energyScore = 0,
    this.sleepHours = 0,
    this.sleepEfficiency = 0,
    this.hrv,
    this.rhr,
    this.hrvBaseline,
    this.rhrBaseline,
    this.steps = 0,
    this.exerciseMinutes = 0,
    this.respiratoryRate,
    this.bloodOxygen,
    this.skinTemperature,
    this.vo2Max,
    this.activeEnergy = 0,
    this.heartRateAvg,
  });

  WearableSnapshot copyWith({
    int? strainScore,
    int? recoveryScore,
    int? stressScore,
    int? stressHigh,
    int? stressLow,
    int? stressAvg,
    int? sleepScore,
    int? energyScore,
    double? sleepHours,
    double? sleepEfficiency,
    double? hrv,
    int? rhr,
    double? hrvBaseline,
    int? rhrBaseline,
    int? steps,
    int? exerciseMinutes,
    double? respiratoryRate,
    double? bloodOxygen,
    double? skinTemperature,
    double? vo2Max,
    double? activeEnergy,
    int? heartRateAvg,
  }) {
    return WearableSnapshot(
      strainScore: strainScore ?? this.strainScore,
      recoveryScore: recoveryScore ?? this.recoveryScore,
      stressScore: stressScore ?? this.stressScore,
      stressHigh: stressHigh ?? this.stressHigh,
      stressLow: stressLow ?? this.stressLow,
      stressAvg: stressAvg ?? this.stressAvg,
      sleepScore: sleepScore ?? this.sleepScore,
      energyScore: energyScore ?? this.energyScore,
      sleepHours: sleepHours ?? this.sleepHours,
      sleepEfficiency: sleepEfficiency ?? this.sleepEfficiency,
      hrv: hrv ?? this.hrv,
      rhr: rhr ?? this.rhr,
      hrvBaseline: hrvBaseline ?? this.hrvBaseline,
      rhrBaseline: rhrBaseline ?? this.rhrBaseline,
      steps: steps ?? this.steps,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      bloodOxygen: bloodOxygen ?? this.bloodOxygen,
      skinTemperature: skinTemperature ?? this.skinTemperature,
      vo2Max: vo2Max ?? this.vo2Max,
      activeEnergy: activeEnergy ?? this.activeEnergy,
      heartRateAvg: heartRateAvg ?? this.heartRateAvg,
    );
  }
}

/// Fetches today's wearable metrics and computes derived scores.
/// Now acts as a proxy to the unified [wearableSyncProvider] to keep legacy components working.
final wearableStateProvider = FutureProvider.autoDispose<WearableSnapshot>((ref) async {
  final syncState = ref.watch(wearableSyncProvider).value;
  return syncState?.snapshot ?? const WearableSnapshot();
});

// ──────────────────────────────────────────────────────────────────────────────
// AI Insights — blends lab intelligence + wearable data
// ──────────────────────────────────────────────────────────────────────────────

/// Generates a list of dynamic text insights based on patient + wearable data.
final aiInsightsProvider = Provider<List<String>>((ref) {
  final profile = ref.watch(patientProfileProvider).value;
  final intelligence = ref.watch(intelligenceDataProvider).value;
  final wearable = ref.watch(wearableStateProvider).value;
  
  final insights = <String>[];

  // ── Lab-based Insights ──

  // 1. Cellular Health Insight (from Intelligence Data)
  if (intelligence != null) {
    final cellularDomain = intelligence.healthDomains.firstWhere(
      (d) => d.name.toLowerCase().contains('cellular'),
      orElse: () => const HealthDomain(name: 'Cellular', score: 0, status: 'Unknown'),
    );

    if (cellularDomain.status != null && cellularDomain.status != 'Unknown') {
       insights.add(
        'Your cellular health is rated "${cellularDomain.status}". Consider adding more antioxidant-rich foods to support cellular repair and reduce oxidative stress.'
      );
    }
  }

  // 2. Pace of Aging Insight
  if (profile != null) {
    if (profile.paceOfAging > 1.05) {
      insights.add(
        'Your Pace of Aging is ${((profile.paceOfAging - 1) * 100).toStringAsFixed(0)}% faster than normal. Prioritize sleep and stress management to slow this down.'
      );
    } else if (profile.paceOfAging < 0.95) {
      insights.add(
        'Great job! You are aging ${((1 - profile.paceOfAging) * 100).toStringAsFixed(0)}% slower than the average population. Keep up your current protocol.'
      );
    }
  }

  // 3. Biological Age Insight
  if (profile != null && profile.age != null && profile.bioAge != null) {
    final diff = profile.bioAge! - profile.age!;
    if (diff > 2) {
      insights.add(
        'Your biological age is $diff years higher than your chronological age. Focus on localized inflammation reduction.'
      );
    } else if (diff < -2) {
      insights.add(
        'You are biologically ${diff.abs()} years younger than your calendar age. Your lifestyle choices are paying off!'
      );
    }
  }

  // ── Wearable Cross-Domain Insights ──

  if (wearable != null) {
    // 4. Recovery + Strain Readiness
    if (wearable.recoveryScore >= 75 && wearable.strainScore < 30) {
      insights.add(
        'Recovery is ${wearable.recoveryScore}% and strain is low. Today is an optimal window for a high-intensity training session.'
      );
    } else if (wearable.recoveryScore < 40) {
      insights.add(
        'Recovery is only ${wearable.recoveryScore}%. Your body is still repairing. Consider active recovery or rest today.'
      );
    }

    // 5. Sleep Quality Cross-Insight
    if (wearable.sleepHours > 0 && wearable.sleepHours < 6) {
      insights.add(
        'You logged only ${wearable.sleepHours.toStringAsFixed(1)}h of sleep. Sleep debt compounds — aim for 7-9 hours tonight to protect metabolic and cognitive function.'
      );
    } else if (wearable.sleepScore >= 85) {
      insights.add(
        'Sleep score is ${wearable.sleepScore}%. Excellent recovery night — your body is primed for peak performance today.'
      );
    }

    // 6. HRV Baseline Deviation
    if (wearable.hrv != null && wearable.hrvBaseline != null && wearable.hrvBaseline! > 0) {
      final deviation = ((wearable.hrv! - wearable.hrvBaseline!) / wearable.hrvBaseline! * 100).round();
      if (deviation >= 15) {
        insights.add(
          'HRV is $deviation% above your personal baseline — a strong sign of parasympathetic recovery. Your nervous system is well-regulated.'
        );
      } else if (deviation <= -20) {
        insights.add(
          'HRV is ${deviation.abs()}% below your baseline. This often signals accumulated stress or onset of illness. Monitor closely and prioritize rest.'
        );
      }
    }

    // 7. Stress Warning
    if (wearable.stressScore >= 60) {
      insights.add(
        'Stress score is elevated at ${wearable.stressScore}/100. Consider breathwork or a short walk to activate parasympathetic recovery.'
      );
    }

    // 8. RHR Trend (compare to baseline)
    if (wearable.rhr != null && wearable.rhrBaseline != null && wearable.rhrBaseline! > 0) {
      final rhrDiff = wearable.rhr! - wearable.rhrBaseline!;
      if (rhrDiff >= 5) {
        insights.add(
          'Resting heart rate is $rhrDiff bpm above your baseline. A sustained elevation may indicate dehydration, stress, or early infection.'
        );
      }
    }
  }

  // Default welcome insight if nothing else triggers
  if (insights.isEmpty) {
    insights.add('Welcome to Zyndio. Complete your daily protocol to generate new health insights.');
    insights.add('AI is analyzing your latest biomarkers. Check back soon for detailed recommendations.');
  }

  return insights;
});

// ──────────────────────────────────────────────────────────────────────────────
// Correlation Insights — async pattern detection between wearables and labs
// ──────────────────────────────────────────────────────────────────────────────

/// Runs the CorrelationEngine to detect patterns between wearable trends and
/// lab biomarker results. Returns a list of natural-language pattern insights.
final correlationInsightsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final intelligence = ref.watch(intelligenceDataProvider).value;
  final labReports = ref.watch(labReportsProvider).value;

  // Build lab markers list from latest report
  List<Map<String, dynamic>>? labMarkers;
  if (labReports != null && labReports.isNotEmpty) {
    labMarkers = labReports.first.markers.map((m) => {
      'name': m.name,
      'value': m.value,
      'range': m.range,
      'status': m.status,
    }).toList();
  }

  return CorrelationEngine.analyze(
    repo: HealthRepository(),
    intelligence: intelligence,
    labMarkers: labMarkers,
  );
});
