import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';
import 'intelligence_provider.dart';
import 'lab_reports_provider.dart';
import '../data/health_repository.dart';
import '../services/correlation_engine.dart';

enum InsightType { standard, summary, graph, mission, status, energyForecast }

class InsightCardData {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final DateTime timestamp;
  final String? suggestedQuestion;
  final String? ctaLabel;
  final String? ctaAction;
  final InsightType type;
  final List<double>? graphData; // For sparklines/graphs

  InsightCardData({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.timestamp,
    this.suggestedQuestion,
    this.ctaLabel,
    this.ctaAction,
    this.type = InsightType.standard,
    this.graphData,
  });
}

/// A provider that generates a dynamic feed of actionable insights.
/// Combining real-time wearable data, lab markers, and correlation engine outputs.
final dynamicInsightsProvider = FutureProvider.autoDispose<List<InsightCardData>>((ref) async {
  final wearable = ref.watch(wearableStateProvider).value;
  final labReports = ref.watch(labReportsProvider).value;
  
  List<InsightCardData> feed = [];
  final now = DateTime.now();

  // 0.5 ENERGY FORECAST (Graph Example)
  if (wearable != null) {
    // Generate a simulated energy forecast based on current time and strain
    final List<double> forecast = List.generate(12, (i) {
      double base = 80.0 - (i * 2); // Natural decay
      if (i < 4) base += 10; // Morning boost
      return base.clamp(20, 100);
    });

    feed.add(InsightCardData(
      id: 'energy_forecast',
      title: 'Energy Readiness Forecast',
      description: 'Your predicted metabolic energy levels for the next 12 hours based on current strain.',
      icon: LucideIcons.trendingUp,
      color: BrandColors.blue500,
      type: InsightType.energyForecast,
      graphData: forecast,
      timestamp: now.subtract(const Duration(minutes: 1)),
      suggestedQuestion: 'What nutrients can I take during my afternoon energy dip to maintain peak focus?',
    ));
  }

  // 1. Wearable Real-time Insights (High priority, recent timestamp)
  if (wearable != null) {
    if ((wearable.hrv ?? 100) < 35) {
      feed.add(InsightCardData(
        id: 'hrv_low',
        title: 'Parasympathetic Drop',
        description: 'Your HRV has dropped to ${wearable.hrv?.toStringAsFixed(0)}ms. Your nervous system is highly stressed.',
        icon: LucideIcons.activity,
        color: BrandColors.red500,
        timestamp: now.subtract(const Duration(minutes: 5)),
        suggestedQuestion: 'My HRV dropped significantly today. What specific breathing or nutrition protocols can restore vagal tone quickly?',
      ));
    } else if ((wearable.hrv ?? 0) > 60) {
      feed.add(InsightCardData(
        id: 'hrv_optimal',
        title: 'Prime Recovery State',
        description: 'Your HRV is peaking today (${wearable.hrv?.toStringAsFixed(0)}ms). Your body is primed for high-strain activity and deep adaptation.',
        icon: LucideIcons.zap,
        color: BrandColors.emerald500,
        timestamp: now.subtract(const Duration(minutes: 15)),
        suggestedQuestion: 'My HRV is very high today. What type of intense training should I focus on to maximize adaptation?',
      ));
    }

    if (wearable.sleepScore > 0 && wearable.sleepScore < 50) {
      feed.add(InsightCardData(
        id: 'sleep_poor',
        title: 'Metabolic Window: Sleep Debt',
        description: 'Poor sleep (${wearable.sleepScore}/100) deeply impairs insulin sensitivity today. Avoid high glycemic carbohydrates to prevent extreme glucose spikes.',
        icon: LucideIcons.moon,
        color: BrandColors.orange500,
        timestamp: now.subtract(const Duration(hours: 2)),
        suggestedQuestion: 'Considering my poor sleep, what exactly should I eat today to maintain stable blood sugar and energy?',
      ));
    }
  }

  // 2. Lab Rules (Medium priority)
  if (labReports != null && labReports.isNotEmpty) {
    final markers = labReports.first.markers;
    for (final marker in markers) {
      if (marker.status.toLowerCase() == 'high') {
         feed.add(InsightCardData(
          id: 'lab_${marker.name}',
          title: 'Active Biomarker: ${marker.name}',
          description: 'Your ${marker.name} is elevated (${marker.value}). Adjust your nutrition this week to help lower this.',
          icon: LucideIcons.droplet,
          color: BrandColors.blue500,
          timestamp: now.subtract(const Duration(hours: 12)),
          suggestedQuestion: 'My ${marker.name} is high. Build me a 3-day meal plan specifically designed to improve this biomarker.',
          ctaLabel: 'View Report',
          ctaAction: '/health_data',
        ));
      }
    }
  }

  // 3. Correlation Engine (Deep patterns)
  try {
    List<Map<String, dynamic>>? markersMaps;
    if (labReports != null && labReports.isNotEmpty) {
      markersMaps = labReports.first.markers.map((m) => {
        'name': m.name,
        'value': m.value,
        'range': m.range,
        'status': m.status,
      }).toList();
    }

    final repo = HealthRepository();
    final patterns = await CorrelationEngine.analyze(repo: repo, labMarkers: markersMaps);

    int idx = 0;
    for (final pattern in patterns) {
      // Extract a quick title from the first few words
      final words = pattern.split(' ');
      final title = words.take(3).join(' ').replaceAll(':', '');
      
      feed.add(InsightCardData(
        id: 'pattern_$idx',
        title: title,
        description: pattern,
        icon: LucideIcons.network,
        color: const Color(0xFF8B5CF6), // Purple
        timestamp: now.subtract(Duration(hours: 24 + idx)),
        suggestedQuestion: 'Can you explain this correlation pattern in more detail and give me an action plan?',
      ));
      idx++;
    }
  } catch (e) {
    print('Failed to load correlations for feed: $e');
  }

  // Sort by timestamp descending
  feed.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return feed;
});
