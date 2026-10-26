import '../models/discovered_correlation.dart';
import '../services/user_habit_service.dart';
import '../services/notification_scheduler.dart';
import '../providers/intelligence_provider.dart';

class MorningBrief {
  final String recoveryVerdict;
  final String todayFocus;
  final DiscoveredCorrelation? keyInsight;
  final String numberHighlight;

  MorningBrief({
    required this.recoveryVerdict,
    required this.todayFocus,
    this.keyInsight,
    required this.numberHighlight,
  });

  String toNotificationBody() {
    return '$recoveryVerdict $todayFocus ${numberHighlight}.';
  }
}

class DayRecap {
  final String headline;
  final String bestMoment;
  final String tomorrowHint;

  DayRecap({
    required this.headline,
    required this.bestMoment,
    required this.tomorrowHint,
  });

  String toNotificationBody() {
    return '$headline $bestMoment $tomorrowHint';
  }
}

class ProactiveConversation {
  final String title;
  final String body;

  ProactiveConversation({
    required this.title,
    required this.body,
  });
}

class ProactiveIntelligenceService {
  Future<void> generateAndScheduleInsights({
    required WearableSnapshot snapshot,
    required List<DiscoveredCorrelation> correlations,
    required UserHabitProfile habitProfile,
  }) async {
    final scheduler = NotificationScheduler();
    
    // 1. Generate Morning Brief
    final brief = _generateMorningBrief(snapshot, correlations);
    await scheduler.scheduleMorningBrief(brief, habitProfile);

    // 2. Generate End-of-Day Recap
    final recap = _generateDayRecap(snapshot);
    await scheduler.scheduleEndOfDayRecap(recap, habitProfile);

    // 3. Evaluate Conversation Starters (max 3 per day limit handled in scheduler or here)
    if (correlations.isNotEmpty) {
      final bestNovel = correlations.firstWhere(
        (c) => c.isNovel && c.coefficient.abs() > 0.5, 
        orElse: () => correlations.first
      );
      
      if (bestNovel.isNovel) {
        final convo = ProactiveConversation(
          title: 'I noticed a new pattern',
          body: bestNovel.insight,
        );
        await scheduler.fireConversationStarter(convo);
        
        // In a real implementation we would mark it as not novel in DB here
      }
    }
  }

  MorningBrief _generateMorningBrief(WearableSnapshot snapshot, List<DiscoveredCorrelation> correlations) {
    String verdict = 'Your body recovered well.';
    String focus = 'Push hard today.';
    String highlight = 'HRV: ${snapshot.hrv?.toStringAsFixed(0) ?? '--'}ms';
    
    if (snapshot.recoveryScore < 40) {
      verdict = 'Recovery is compromised.';
      focus = 'Focus on light active recovery.';
    } else if (snapshot.recoveryScore > 80) {
      verdict = 'Prime readiness achieved.';
      focus = 'Perfect day for high strain.';
    }

    DiscoveredCorrelation? bestInsight;
    if (correlations.isNotEmpty) {
      bestInsight = correlations.first;
    }

    return MorningBrief(
      recoveryVerdict: verdict,
      todayFocus: focus,
      keyInsight: bestInsight,
      numberHighlight: highlight,
    );
  }

  DayRecap _generateDayRecap(WearableSnapshot snapshot) {
    String headline = 'Solid day.';
    if (snapshot.strainScore > 75) headline = 'High output day.';
    if (snapshot.steps < 3000) headline = 'Lighter day on movement.';

    String bestMoment = 'Your stress stayed low.';
    if (snapshot.stressHigh > 80) bestMoment = 'You had some high stress peaks.';

    String hint = 'Aim for 8 hours of sleep tonight.';
    if (snapshot.strainScore > 70) hint = 'Prioritize deep rest tonight after that strain.';

    return DayRecap(
      headline: headline,
      bestMoment: bestMoment,
      tomorrowHint: hint,
    );
  }
}
