import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/alert_provider.dart';

/// A centralized service for triggering complete, real-world alerts.
/// All copy is written in "the Intelligence" voice — warm, direct, personal.
class AlertTriggerService {
  
  // ─── 1. PROTOCOL ALERTS (Compliance-Driven) ───

  static void notifyUpcomingTask(WidgetRef ref, String taskName, int minutesAlert) {
    ref.read(alertProvider.notifier).showProtocolAlert(
      'Heads Up',
      '$taskName is coming up in $minutesAlert minutes. Let\'s stay on track.',
      actionRoute: '/protocol',
    );
  }

  static void notifyProtocolComplete(WidgetRef ref, String phaseName) {
    ref.read(alertProvider.notifier).showProtocolAlert(
      'Nice Work',
      '$phaseName is done and logged. One step closer.',
      actionRoute: '/protocol',
    );
  }

  static void notifyComplianceNudge(WidgetRef ref, int pendingTasks) {
    ref.read(alertProvider.notifier).showProtocolAlert(
      'Midday Check-in',
      'You\'ve got $pendingTasks tasks still open today. Let\'s knock a few out.',
      actionRoute: '/protocol',
    );
  }

  // ─── 2. INTELLIGENCE INSIGHTS (Data-Driven) ───

  static void notifyMetabolicInsight(WidgetRef ref) {
    ref.read(alertProvider.notifier).showInsight(
      'Metabolic Heads Up',
      'I\'m seeing some glucose variability creeping up. A 10-minute post-meal walk would smooth that out.',
      actionRoute: '/',
    );
  }

  static void notifyRecoverySignal(WidgetRef ref, double percentAboveBaseline) {
    ref.read(alertProvider.notifier).showInsight(
      'Peak Readiness',
      'Your HRV is ${percentAboveBaseline.toStringAsFixed(0)}% above your baseline right now. This is the window for a big session.',
      actionRoute: '/wearables',
    );
  }

  static void notifyLongevityShift(WidgetRef ref, double yearsImproved) {
    ref.read(alertProvider.notifier).showInsight(
      'Bio-Age Update',
      'Your biological age just dropped by ${yearsImproved.toStringAsFixed(1)} years. Your protocol is working.',
      actionRoute: '/',
    );
  }

  // ─── 3. ACHIEVEMENT & MILESTONES (Motivation-Driven) ───

  static void notifyConsistencyStreak(WidgetRef ref, int days) {
    ref.read(alertProvider.notifier).showAchievement(
      'Streak 🔥',
      '$days days straight of perfect compliance. That\'s how you build lasting change.',
    );
  }

  static void notifyMetricGoal(WidgetRef ref, String metricName, String value) {
    ref.read(alertProvider.notifier).showAchievement(
      'Goal Hit',
      'You reached your $metricName target ($value). Consistency is paying off.',
    );
  }

  static void notifyLevelUp(WidgetRef ref, String trackName) {
    ref.read(alertProvider.notifier).showAchievement(
      'New Track Unlocked',
      "You've earned access to the $trackName track. Let's level up.",
    );
  }

  // ─── 4. HEALTH WARNINGS (Critical Priority) ───

  static void notifyAcuteStress(WidgetRef ref) {
    ref.read(alertProvider.notifier).showWarning(
      'Stress Check-in',
      'Your nervous system is running hot. Try 4-7-8 breathing — inhale 4s, hold 7s, exhale 8s. It genuinely works.',
      actionRoute: '/meditate',
    );
  }

  static void notifyPoorRecovery(WidgetRef ref, int recoveryScore) {
    ref.read(alertProvider.notifier).showWarning(
      'Recovery Alert',
      'Recovery is at $recoveryScore% — that\'s in the red. A deload day today would be the smart move.',
      actionRoute: '/wearables',
    );
  }

  static void notifyWearableSyncError(WidgetRef ref, int hoursSinceSync) {
    ref.read(alertProvider.notifier).showWarning(
      'Sync Issue',
      "I haven't received data from your wearable in $hoursSinceSync hours. I need that connection to stay accurate.",
      actionRoute: '/connect-wearable',
    );
  }

  // ─── 5. SYSTEM STATUS (Operational) ───

  static void notifyDataUpload(WidgetRef ref, int markersAnalyzed) {
    ref.read(alertProvider.notifier).showSystemAlert(
      'Report Processed',
      'I\'ve analyzed $markersAnalyzed biomarkers from your latest report. Check your meditation tab for insights.',
    );
  }

  static void notifyIdentitySecured(WidgetRef ref) {
    ref.read(alertProvider.notifier).showSystemAlert(
      'Security Confirmed',
      'Your clinical profile is encrypted and secured. Your data stays yours.',
    );
  }
}
