import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'intelligence_provider.dart';
import 'lab_reports_provider.dart';


/// Holds a proactive insight message and an optional suggested chat question
class ProactiveInsight {
  final String title;
  final String body;
  final String? suggestedQuestion;

  const ProactiveInsight({
    required this.title,
    required this.body,
    this.suggestedQuestion,
  });
}

/// Watches wearable and lab data and surfaces a proactive insight when anomalies are detected.
/// Rule ordering: wearable rules (real-time) → lab rules (historical).
final proactiveInsightProvider = Provider<ProactiveInsight?>(
  (ref) {
    final wearable = ref.watch(wearableStateProvider).value;
    final labReports = ref.watch(labReportsProvider).value;

    // ── Wearable Rules ──────────────────────────────────────────────
    if (wearable != null) {
      // Critical HRV drop
      if ((wearable.hrv ?? 100) < 30) {
        return ProactiveInsight(
          title: 'HRV Alert',
          body: 'Your HRV is critically low at ${wearable.hrv?.toStringAsFixed(0) ?? "—"} ms. This signals high physiological stress.',
          suggestedQuestion: 'My HRV is very low today. What is causing this and how do I recover?',
        );
      }

      // Very poor sleep
      if (wearable.sleepScore > 0 && wearable.sleepScore < 40) {
        return ProactiveInsight(
          title: 'Poor Sleep Detected',
          body: 'You scored ${wearable.sleepScore}/100 for sleep last night. Recovery will be compromised today.',
          suggestedQuestion: 'I slept very poorly last night. How does this affect my body and what should I do today?',
        );
      }

      // Low recovery
      if (wearable.recoveryScore > 0 && wearable.recoveryScore < 35) {
        return ProactiveInsight(
          title: 'Low Recovery',
          body: 'Your recovery score is ${wearable.recoveryScore}/100. Avoid intense training and focus on rest.',
          suggestedQuestion: 'My recovery is very low. What should I eat and how should I train today?',
        );
      }

      // High resting heart rate
      if ((wearable.rhr ?? 0) > 85) {
        return ProactiveInsight(
          title: 'Elevated Resting HR',
          body: 'Resting heart rate of ${wearable.rhr} bpm is elevated. This often precedes illness or overtraining.',
          suggestedQuestion: 'My resting heart rate is elevated at ${wearable.rhr} bpm. What could be causing this?',
        );
      }

      // High stress
      if (wearable.stressScore > 75) {
        return ProactiveInsight(
          title: 'High Stress Levels',
          body: 'Your stress score is ${wearable.stressScore}/100 — quite high. Here\'s what the data suggests.',
          suggestedQuestion: 'My wearable shows a very high stress level. What physiological interventions can reduce this quickly?',
        );
      }
    }

    // ── Lab Rules ───────────────────────────────────────────────────
    if (labReports != null && labReports.isNotEmpty) {
      final markers = labReports.first.markers;

      for (final marker in markers) {
        if (marker.status.toLowerCase() == 'high' || marker.status.toLowerCase() == 'low') {
          final isHigh = marker.status.toLowerCase() == 'high';
          return ProactiveInsight(
            title: '${marker.name} Out of Range',
            body: 'Your ${marker.name} (${marker.value}) is ${isHigh ? 'above' : 'below'} the reference range (${marker.range}).',
            suggestedQuestion: 'My ${marker.name} is ${isHigh ? 'high' : 'low'} at ${marker.value}. What does this mean and how can I bring it back to normal?',
          );
        }
      }
    }

    return null; // No anomaly detected
  },
);
