import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../data/health_repository.dart';
import '../models/intelligence_data.dart';
import '../models/discovered_correlation.dart';
import 'shared_health_cache.dart';

/// A learning engine that detects correlations between wearable trends,
/// lab biomarkers, and nutrition data, producing natural-language pattern insights.
class CorrelationEngine {
  /// The original curated patterns used by DynamicInsightsProvider
  static Future<List<String>> analyze({
    required HealthRepository repo,
    IntelligenceData? intelligence,
    List<Map<String, dynamic>>? labMarkers,
    List<Map<String, dynamic>>? foodLogs,
    SharedHealthCache? cache,
  }) async {
    return _runCuratedPatterns(
      repo: repo,
      intelligence: intelligence,
      labMarkers: labMarkers,
      foodLogs: foodLogs,
      cache: cache,
    );
  }

  /// Autonomously scans all available time-series data to find new Pearson correlations
  static Future<List<DiscoveredCorrelation>> discoverCorrelations({
    required HealthRepository repo,
    SharedHealthCache? cache,
  }) async {
    final correlations = <DiscoveredCorrelation>[];
    
    try {
      final data = cache ?? await SharedHealthCache.fetch(repo);
      
      // Fetch food logs to correlate nutrition with recovery
      List<Map<String, dynamic>> foodLogs = [];
      final client = SupabaseConfig.client;
      final userId = SupabaseConfig.currentUser?.id;
      
      if (client != null && userId != null) {
        try {
          final fourteenDaysAgo = DateTime.now().subtract(const Duration(days: 14));
          final response = await client
              .from('food_logs')
              .select()
              .eq('patient_id', userId)
              .gte('logged_at', fourteenDaysAgo.toIso8601String());
          foodLogs = (response as List).cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('CorrelationEngine: Food log fetch failed: $e');
        }
      }

      // Prepare daily datasets
      final dailySleep = _aggregateByDay(data.sleepHistory, 'hours');
      final dailyHrv = _aggregateByDay(data.hrvHistory, 'value');
      final dailyRhr = _aggregateByDay(data.rhrHistory, 'value');
      /* final dailyStrain = _aggregateByDay(
        data.strainHistory.map((s) => {'date': DateTime.now(), 'value': s}).toList(), // Mocking dates for strain if they don't have them
        'value' 
      ); */
      
      // Extract daily average food scores
      final dailyFoodScore = <String, double>{};
      for (final log in foodLogs) {
        try {
          final dateStr = (log['logged_at'] as String).substring(0, 10);
          final analysis = log['analysis_json'] as Map<String, dynamic>? ?? {};
          final score = _toInt(analysis['score']).toDouble();
          if (score > 0) {
            dailyFoodScore[dateStr] = (dailyFoodScore[dateStr] ?? 0) == 0 ? score : (dailyFoodScore[dateStr]! + score) / 2;
          }
        } catch (_) {}
      }

      // Extract daily late meals (dinner after 8 PM)
      final dailyLateMeals = <String, double>{};
      for (final log in foodLogs) {
        try {
          final date = DateTime.parse(log['logged_at'] as String).toLocal();
          final dateStr = date.toIso8601String().substring(0, 10);
          if (date.hour >= 20) {
            dailyLateMeals[dateStr] = 1.0;
          } else {
            dailyLateMeals[dateStr] = dailyLateMeals[dateStr] ?? 0.0;
          }
        } catch (_) {}
      }

      // Signal Pairs to test
      _testPair(correlations, 'Sleep Hours', dailySleep, 'Next Day HRV', _shiftData(dailyHrv, -1), 
                insightTemplate: 'When you sleep longer, your HRV is typically higher the next day.');
      
      _testPair(correlations, 'Sleep Hours', dailySleep, 'Next Day RHR', _shiftData(dailyRhr, -1),
                inverse: true, insightTemplate: 'When you sleep longer, your RHR drops the next day.');
      
      _testPair(correlations, 'Food Quality Score', dailyFoodScore, 'Next Day Recovery (HRV)', _shiftData(dailyHrv, -1),
                insightTemplate: 'High-scoring meals strongly precede better autonomic recovery the following day.');
                
      _testPair(correlations, 'Late Meals (After 8 PM)', dailyLateMeals, 'Next Day HRV', _shiftData(dailyHrv, -1),
                inverse: true, insightTemplate: 'Eating after 8 PM correlates with reduced recovery (lower HRV) the next morning.');
      
      // Meditation ↔ Recovery
      final dailyMeditation = _aggregateByDay(data.meditationHistory, 'minutes');
      _testPair(correlations, 'Meditation Minutes', dailyMeditation, 'Next Day HRV', _shiftData(dailyHrv, -1),
                insightTemplate: 'Consistent meditation sessions correlate with higher next-day HRV, indicating better autonomic recovery.');
      
      _testPair(correlations, 'Meditation Minutes', dailyMeditation, 'Next Day RHR', _shiftData(dailyRhr, -1),
                inverse: true, insightTemplate: 'Your mindfulness practice is linked to a lower resting heart rate the following day.');

      // Persist to Supabase if we found any
      if (correlations.isNotEmpty && client != null && userId != null) {
        for (final c in correlations) {
          try {
            await client.from('user_correlations').upsert(
              c.toJson(userId: userId),
              onConflict: 'user_id, signal_a, signal_b',
            );
          } catch (e) {
            debugPrint('Failed to persist correlation: $e');
          }
        }
      }

    } catch (e) {
      debugPrint('CorrelationEngine discovery error: $e');
    }

    // Sort by strength
    correlations.sort((a, b) => b.coefficient.abs().compareTo(a.coefficient.abs()));
    return correlations;
  }

  static void _testPair(
    List<DiscoveredCorrelation> results,
    String signalA,
    Map<String, double> dataA,
    String signalB,
    Map<String, double> dataB,
    {required String insightTemplate, bool inverse = false}
  ) {
    final aligned = _alignTimeSeries(dataA, dataB);
    if (aligned.length < 5) return; // Need at least 5 paired data points
    
    final x = aligned.map((pair) => pair[0]).toList();
    final y = aligned.map((pair) => pair[1]).toList();
    
    final r = _pearsonCorrelation(x, y);
    
    // Check if it matches expected direction and is strong enough (|r| > 0.45)
    if (r.abs() > 0.45) {
      if ((inverse && r < 0) || (!inverse && r > 0)) {
        String strength = r.abs() > 0.7 ? 'strong' : 'moderate';
        
        results.add(DiscoveredCorrelation(
          id: '${signalA.replaceAll(' ', '_')}_${signalB.replaceAll(' ', '_')}',
          signalA: signalA,
          signalB: signalB,
          coefficient: r,
          sampleSize: aligned.length,
          direction: r > 0 ? 'positive' : 'negative',
          insight: insightTemplate,
          strength: strength,
          discoveredAt: DateTime.now(),
        ));
      }
    }
  }

  // ── MATH HELPERS ──

  static double _pearsonCorrelation(List<double> x, List<double> y) {
    if (x.isEmpty || y.isEmpty || x.length != y.length) return 0.0;
    
    final n = x.length;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;
    
    double num = 0.0;
    double denX = 0.0;
    double denY = 0.0;
    
    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      final dy = y[i] - meanY;
      num += dx * dy;
      denX += dx * dx;
      denY += dy * dy;
    }
    
    if (denX == 0 || denY == 0) return 0.0;
    return num / math.sqrt(denX * denY);
  }

  static Map<String, double> _aggregateByDay(List<Map<String, dynamic>> rawData, String valueKey) {
    final daily = <String, double>{};
    for (final entry in rawData) {
      try {
        final date = entry['date'] as DateTime;
        final dateStr = date.toIso8601String().substring(0, 10);
        final val = (entry[valueKey] as num).toDouble();
        if (val > 0) daily[dateStr] = val;
      } catch (_) {}
    }
    return daily;
  }

  /// Shifts dates by offsetDays (e.g., -1 means shifting today's value to yesterday, so yesterday's A aligns with today's B)
  static Map<String, double> _shiftData(Map<String, double> data, int offsetDays) {
    final shifted = <String, double>{};
    for (final entry in data.entries) {
      try {
        final d = DateTime.parse(entry.key);
        final sd = d.add(Duration(days: offsetDays));
        shifted[sd.toIso8601String().substring(0, 10)] = entry.value;
      } catch (_) {}
    }
    return shifted;
  }

  static List<List<double>> _alignTimeSeries(Map<String, double> seriesA, Map<String, double> seriesB) {
    final aligned = <List<double>>[];
    for (final date in seriesA.keys) {
      if (seriesB.containsKey(date)) {
        aligned.add([seriesA[date]!, seriesB[date]!]);
      }
    }
    return aligned;
  }

  // ── LEGACY CURATED PATTERNS (Used by Dynamic Insights Feed) ──

  static Future<List<String>> _runCuratedPatterns({
    required HealthRepository repo,
    IntelligenceData? intelligence,
    List<Map<String, dynamic>>? labMarkers,
    List<Map<String, dynamic>>? foodLogs,
    SharedHealthCache? cache,
  }) async {
    final insights = <String>[];

    try {
      final data = cache ?? await SharedHealthCache.fetch(repo);

      final sleepHistory = data.sleepHistory;
      final hrvHistory = data.hrvHistory;
      final rhrHistory = data.rhrHistory;
      final energyHistory = data.energyHistory;
      final strainHistory = data.strainHistory;

      List<Map<String, dynamic>>? recentFoodLogs = foodLogs;
      if (recentFoodLogs == null) {
        try {
          final client = SupabaseConfig.client;
          final userId = SupabaseConfig.currentUser?.id;
          if (client != null && userId != null) {
            final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
            final response = await client
                .from('food_logs')
                .select()
                .eq('patient_id', userId)
                .gte('logged_at', sevenDaysAgo.toIso8601String())
                .order('logged_at', ascending: false);
            recentFoodLogs = (response as List).cast<Map<String, dynamic>>();
          }
        } catch (e) {
          debugPrint('CorrelationEngine: Food log fetch failed: $e');
        }
      }

      // Pattern 1: Sleep ↔ Metabolic Markers
      if (sleepHistory.isNotEmpty && labMarkers != null) {
        final avgSleep = sleepHistory.fold<double>(
          0, (sum, e) => sum + ((e['hours'] ?? e['value']) as num).toDouble(),
        ) / sleepHistory.length;

        final glucoseMarker = _findMarker(labMarkers, ['glucose', 'fasting glucose', 'blood sugar', 'hba1c']);
        if (glucoseMarker != null) {
          final status = glucoseMarker['status'] as String? ?? '';
          if (avgSleep < 6.5 && (status.toLowerCase() == 'high' || status.toLowerCase() == 'critical')) {
            insights.add(
              'Pattern detected: Your average sleep (${avgSleep.toStringAsFixed(1)}h) over 14 days is below optimal, '
              'and your ${glucoseMarker['name']} is flagged as $status. Research shows sleep deprivation '
              'impairs glucose metabolism. Prioritizing 7-8 hours of sleep may help normalize blood sugar.'
            );
          }
        }
      }

      // Pattern 2: HRV Trend ↔ Inflammation
      if (hrvHistory.isNotEmpty && labMarkers != null) {
        final hrvValues = hrvHistory.map((e) => (e['value'] as num).toDouble()).toList();
        final isHrvDeclining = _isTrendDeclining(hrvValues);

        final crpMarker = _findMarker(labMarkers, ['crp', 'c-reactive', 'hs-crp']);
        if (crpMarker != null) {
          final status = crpMarker['status'] as String? ?? '';
          if (isHrvDeclining && status.toLowerCase() != 'normal') {
            insights.add(
              'Pattern detected: HRV has been declining over the past 2 weeks while your ${crpMarker['name']} '
              'is elevated. Declining HRV combined with inflammation markers suggests your body is under '
              'systemic stress. Consider anti-inflammatory interventions and recovery optimization.'
            );
          }
        }
      }

      // Pattern 3: Activity ↔ Lipids
      if (energyHistory.isNotEmpty && labMarkers != null) {
        final avgEnergy = energyHistory.fold<double>(
          0, (sum, e) => sum + (e['value'] as num).toDouble(),
        ) / energyHistory.length;

        final trigMarker = _findMarker(labMarkers, ['triglycerides', 'trig']);
        final hdlMarker = _findMarker(labMarkers, ['hdl', 'hdl-c']);

        if (trigMarker != null && avgEnergy > 300) {
          final status = trigMarker['status'] as String? ?? '';
          if (status.toLowerCase() == 'normal' || status.toLowerCase() == 'optimal') {
            insights.add(
              'Positive correlation: Your active energy averages ${avgEnergy.round()} kcal/day, and your '
              '${trigMarker['name']} is in the $status range. Regular physical activity is a key driver '
              'of healthy lipid metabolism — keep it up.'
            );
          }
        }

        if (hdlMarker != null && avgEnergy < 150) {
          final status = hdlMarker['status'] as String? ?? '';
          if (status.toLowerCase() == 'low' || status.toLowerCase() == 'critical') {
            insights.add(
              'Pattern detected: Your daily active energy is low (${avgEnergy.round()} kcal avg), and ${hdlMarker['name']} '
              'is below optimal. Aerobic exercise is one of the most effective ways to raise HDL cholesterol.'
            );
          }
        }
      }

      // Pattern 4: RHR Trend ↔ Cardiovascular Health
      if (rhrHistory.isNotEmpty) {
        final rhrValues = rhrHistory.map((e) => (e['value'] as num).toDouble()).toList();
        final isRhrRising = _isTrendRising(rhrValues);

        if (isRhrRising && rhrValues.last > 75) {
          insights.add(
            'Your resting heart rate has been trending upward over 14 days and is currently above 75 bpm. '
            'A sustained RHR increase may indicate poor cardiovascular recovery, dehydration, or accumulated stress. '
            'Monitor closely and ensure adequate hydration and rest.'
          );
        }
      }

      // Pattern 5: Strain Consistency ↔ Recovery Readiness
      if (strainHistory.isNotEmpty) {
        final nonZeroStrain = strainHistory.where((s) => s > 0).toList();
        if (nonZeroStrain.length >= 5) {
          final avgStrain = nonZeroStrain.reduce((a, b) => a + b) / nonZeroStrain.length;
          if (avgStrain > 60) {
            insights.add(
              'Your strain has averaged ${avgStrain.round()}% over the past week — this is on the higher end. '
              'Sustained high strain without recovery days increases injury risk and suppresses immune function. '
              'Consider scheduling a deload or active recovery day.'
            );
          }
        }
      }

      // Pattern 6: Food Quality ↔ Recovery/Stress
      if (recentFoodLogs != null && recentFoodLogs.isNotEmpty) {
        int totalScore = 0;
        int scoredMeals = 0;

        for (final log in recentFoodLogs) {
          final analysis = log['analysis_json'] as Map<String, dynamic>? ?? {};
          final score = _toInt(analysis['score']);
          if (score > 0) {
            totalScore += score;
            scoredMeals++;
          }
        }

        if (scoredMeals >= 3) {
          final avgScore = totalScore / scoredMeals;

          if (avgScore < 50 && hrvHistory.isNotEmpty) {
            final hrvValues = hrvHistory.map((e) => (e['value'] as num).toDouble()).toList();
            final isHrvDeclining = _isTrendDeclining(hrvValues);

            if (isHrvDeclining) {
              insights.add(
                'Diet-recovery pattern detected: Your recent meals have an average Zyndio Score of '
                '${avgScore.round()}/100 (below optimal) and your HRV has been declining. Poor diet quality '
                'increases systemic inflammation and impairs autonomic recovery. Consider prioritizing '
                'whole foods, anti-inflammatory ingredients, and reducing processed food intake.'
              );
            }
          }

          if (avgScore >= 70 && hrvHistory.isNotEmpty) {
            final hrvValues = hrvHistory.map((e) => (e['value'] as num).toDouble()).toList();
            if (!_isTrendDeclining(hrvValues)) {
              insights.add(
                'Positive diet-performance correlation: Your meals average a Zyndio Score of '
                '${avgScore.round()}/100 and your HRV is stable or improving. Your food choices are '
                'supporting strong autonomic recovery — keep it up.'
              );
            }
          }
        }
      }

      // Pattern 7: Meditation ↔ RHR/Stress
      if (data.meditationHistory.isNotEmpty && rhrHistory.isNotEmpty) {
        final totalMins = data.meditationHistory.fold<int>(0, (sum, m) => sum + (m['minutes'] as int? ?? 0));
        final avgMins = totalMins / 14; // over 14 days
        
        final rhrValues = rhrHistory.map((e) => (e['value'] as num).toDouble()).toList();
        final isRhrRising = _isTrendRising(rhrValues);

        if (avgMins < 5 && isRhrRising) {
          insights.add(
            'Trend observed: Your meditation consistency has dropped recently (avg ${avgMins.toStringAsFixed(1)} min/day), '
            'while your resting heart rate is trending upward. Mindfulness practice is a proven tool for lowering '
            'cardiovascular stress — returning to your 10-minute "Neural Atmosphere" sessions might help stabilize your RHR.'
          );
        }
      }
    } catch (e) {
      debugPrint('CorrelationEngine error: $e');
    }


    return insights;
  }

  static Map<String, dynamic>? _findMarker(List<Map<String, dynamic>> markers, List<String> names) {
    for (final marker in markers) {
      final markerName = (marker['name'] as String? ?? '').toLowerCase();
      for (final name in names) {
        if (markerName.contains(name)) return marker;
      }
    }
    return null;
  }

  static bool _isTrendDeclining(List<double> values) {
    if (values.length < 4) return false;
    final half = values.length ~/ 2;
    final firstHalf = values.sublist(0, half);
    final secondHalf = values.sublist(half);
    final avgFirst = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final avgSecond = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    return avgSecond < avgFirst * 0.9;
  }

  static bool _isTrendRising(List<double> values) {
    if (values.length < 4) return false;
    final half = values.length ~/ 2;
    final firstHalf = values.sublist(0, half);
    final secondHalf = values.sublist(half);
    final avgFirst = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
    final avgSecond = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
    return avgSecond > avgFirst * 1.1;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }
}
