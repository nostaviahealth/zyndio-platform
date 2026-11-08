import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_rhythm.dart';
import '../models/notification_model.dart';
import '../data/notification_repository.dart';
import '../providers/alert_provider.dart';
import 'milestone_reminders.dart';
import 'notification_service.dart';
import 'user_habit_service.dart';
import 'package:flutter/material.dart';
import 'proactive_intelligence_service.dart';

/// Intelligent Notification Scheduler
/// 
/// Features:
/// 1. AI-generated personalized anchor texts
/// 2. Interactive actions (Done / Snooze) on task reminders
/// 3. Predictive timing based on user's actual wake-up pattern
/// 4. Post-event workout nudges (triggered externally)
/// 5. DEEP SYNC: All AI intelligence is persisted to the in-app Inbox & Activity history.
class NotificationScheduler {
  static final NotificationScheduler _instance = NotificationScheduler._internal();
  factory NotificationScheduler() => _instance;
  NotificationScheduler._internal();

  final NotificationService _notificationService = NotificationService();
  final NotificationRepository _notificationRepository = NotificationRepository();
  
  /// Registered notifier to trigger in-app banners and activity history
  AlertNotifier? _alertNotifier;

  /// Register the alert notifier from the app UI level
  void registerAlertNotifier(AlertNotifier notifier) {
    _alertNotifier = notifier;
    debugPrint('🔔 AlertNotifier registered with NotificationScheduler');
  }

  // ═══════════════════════════════════════════════════════
  // STATIC FALLBACK COPY
  // ═══════════════════════════════════════════════════════
  static const _fallbackMorning = 'Good morning — I\'ve been looking at your numbers. Let\'s check your readiness. ⚡️';
  static const _fallbackLunch = 'Hey, your metabolic window is open right now. Perfect time to fuel up smart. 🥗';
  static const _fallbackEvening = 'Winding down? I\'ve prepped your recovery checklist for tonight. 🌙';

  // ═══════════════════════════════════════════════════════
  // PREDICTIVE TIMING
  // ═══════════════════════════════════════════════════════
  static const String _wakeUpKey = 'user_wakeup_history';
  static const int _defaultMorningHour = 8;
  static const int _defaultMorningMinute = 0;

  Future<void> recordWakeUpTime() async {
    final now = DateTime.now();
    if (now.hour < 4 || now.hour >= 11) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_wakeUpKey) ?? [];
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      final todayKey = '${now.year}-${now.month}-${now.day}';
      final lastEntry = history.isNotEmpty ? history.last : '';
      if (lastEntry.startsWith(todayKey)) return;

      history.add('$todayKey|$timeStr');
      if (history.length > 7) history.removeAt(0);
      await prefs.setStringList(_wakeUpKey, history);
      debugPrint('📊 Wake-up recorded: $timeStr');
    } catch (e) {
      debugPrint('Error recording wake-up time: $e');
    }
  }

  Future<DateTime> _getPredictedMorningTime(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_wakeUpKey) ?? [];
      if (history.isEmpty) {
        debugPrint('🧠 Prediction: No history yet, using default 08:00');
        return DateTime(now.year, now.month, now.day, _defaultMorningHour, _defaultMorningMinute);
      }
      int totalMinutes = 0;
      int count = 0;
      for (final entry in history) {
        final parts = entry.split('|');
        if (parts.length != 2) continue;
        final timeParts = parts[1].split(':');
        if (timeParts.length != 2) continue;
        totalMinutes += int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);
        count++;
      }
      if (count == 0) return DateTime(now.year, now.month, now.day, _defaultMorningHour, _defaultMorningMinute);
      final avgMinutes = totalMinutes ~/ count;
      final avgHour = avgMinutes ~/ 60;
      final avgMinute = avgMinutes % 60;
      final wakeTime = DateTime(now.year, now.month, now.day, avgHour, avgMinute).add(const Duration(minutes: 15));
      debugPrint('🧠 Prediction: Based on $count mornings, wake-up is ~${avgHour.toString().padLeft(2, '0')}:${avgMinute.toString().padLeft(2, '0')}. Scheduling at ${wakeTime.hour}:${wakeTime.minute.toString().padLeft(2, '0')}');
      return wakeTime;
    } catch (e) {
      return DateTime(now.year, now.month, now.day, _defaultMorningHour, _defaultMorningMinute);
    }
  }

  // ═══════════════════════════════════════════════════════
  // CORE SCHEDULING ENGINE
  // ═══════════════════════════════════════════════════════

  Future<void> _cancelAllExceptMilestoneReminders() async {
    try {
      final pending = await _notificationService.pendingNotificationRequests();
      for (final p in pending) {
        if (!isMilestoneReminderId(p.id)) {
          await _notificationService.cancel(p.id);
        }
      }
    } catch (_) {
      await _notificationService.cancelAllScheduled();
    }
  }

  Future<void> scheduleForRhythm(DailyRhythm rhythm) async {
    // Clear the day's rhythm reminders but keep the programme's scan-and-labs
    // milestone reminders (APP-14), which are planned weeks ahead.
    await _cancelAllExceptMilestoneReminders();
    final now = DateTime.now();
    
    // ── ADAPTIVE EVOLUTION ENGINE: Fetch Habit Profile ──
    final profile = await UserHabitService.generateProfile();

    // 1. Schedule Daily Anchors with PREDICTIVE timing
    await _scheduleMorningAnchor(now, rhythm.morningText, profile.predictedWakeUp, profile.wakeConfidence);
    _scheduleLunchAnchor(now, rhythm.lunchText, profile.predictedLunch, profile.lunchConfidence);
    _scheduleEveningAnchor(now, rhythm.eveningText, profile.predictedBedtime, profile.bedtimeConfidence);

    debugPrint('🔔 Scheduled Anchors: Morning=${rhythm.morningText != null ? "AI" : "Fallback"}, Lunch=${rhythm.lunchText != null ? "AI" : "Fallback"}, Evening=${rhythm.eveningText != null ? "AI" : "Fallback"}');

    // 2. Schedule Interactive Task Reminders
    _scheduleRhythmTasks(rhythm, now);

    // 3. DEEP SYNC: Save AI-personalized texts to the in-app Inbox
    _syncAiTextsToInbox(rhythm);

    final source = rhythm.morningText != null ? 'AI-personalized' : 'static fallback';
    debugPrint('✅ Notifications scheduled ($source) for rhythm: ${rhythm.date}');
  }

  /// Saves the AI-generated texts to the Supabase database so they appear in the bell icon inbox.
  Future<void> _syncAiTextsToInbox(DailyRhythm rhythm) async {
    if (rhythm.morningText != null) {
      await _notificationRepository.createNotification(NotificationItem(
        id: 'morning_${rhythm.id}',
        title: 'Morning Readiness',
        body: rhythm.morningText!,
        timestamp: DateTime.now(),
        type: NotificationType.protocol,
        actionRoute: '/',
      ));
    }
    if (rhythm.lunchText != null) {
      await _notificationRepository.createNotification(NotificationItem(
        id: 'lunch_${rhythm.id}',
        title: 'Metabolic Window',
        body: rhythm.lunchText!,
        timestamp: DateTime.now(),
        type: NotificationType.protocol,
        actionRoute: '/lens',
      ));
    }
    if (rhythm.eveningText != null) {
      await _notificationRepository.createNotification(NotificationItem(
        id: 'evening_${rhythm.id}',
        title: 'Recovery Prep',
        body: rhythm.eveningText!,
        timestamp: DateTime.now(),
        type: NotificationType.protocol,
        actionRoute: '/',
      ));
    }
  }

  Future<void> _scheduleMorningAnchor(DateTime now, String? aiText, TimeOfDay? predictedWakeUp, double confidence) async {
    DateTime scheduledTime = await _getPredictedMorningTime(now);
    
    if (predictedWakeUp != null && confidence >= 0.3) {
      // 15 mins after predicted wake-up
      scheduledTime = DateTime(now.year, now.month, now.day, predictedWakeUp.hour, predictedWakeUp.minute)
          .add(const Duration(minutes: 15));
    }
    
    if (scheduledTime.isBefore(now)) scheduledTime = scheduledTime.add(const Duration(days: 1));

    _notificationService.scheduleNotification(
      id: 1001,
      title: 'Zyndio',
      body: aiText ?? _fallbackMorning,
      scheduledDate: scheduledTime,
      payload: '/',
      categoryIdentifier: 'DAILY_ANCHOR',
    );
  }

  void _scheduleLunchAnchor(DateTime now, String? aiText, TimeOfDay? predictedLunch, double confidence) {
    DateTime scheduledTime = DateTime(now.year, now.month, now.day, 13, 30);
    
    if (predictedLunch != null && confidence >= 0.3) {
      // 15 mins before predicted lunch (Pre-emptive nudge)
      scheduledTime = DateTime(now.year, now.month, now.day, predictedLunch.hour, predictedLunch.minute)
          .subtract(const Duration(minutes: 15));
    }
    
    if (scheduledTime.isBefore(now)) scheduledTime = scheduledTime.add(const Duration(days: 1));

    _notificationService.scheduleNotification(
      id: 1002,
      title: 'Zyndio',
      body: aiText ?? _fallbackLunch,
      scheduledDate: scheduledTime,
      payload: '/lens',
      categoryIdentifier: 'DAILY_ANCHOR',
    );
  }

  void _scheduleEveningAnchor(DateTime now, String? aiText, TimeOfDay? predictedBedtime, double confidence) {
    DateTime scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);
    
    if (predictedBedtime != null && confidence >= 0.3) {
      // 45 mins before predicted bedtime (Ramp-down nudge)
      scheduledTime = DateTime(now.year, now.month, now.day, predictedBedtime.hour, predictedBedtime.minute)
          .subtract(const Duration(minutes: 45));
    }
    
    if (scheduledTime.isBefore(now)) scheduledTime = scheduledTime.add(const Duration(days: 1));

    _notificationService.scheduleNotification(
      id: 1003,
      title: 'Zyndio',
      body: aiText ?? _fallbackEvening,
      scheduledDate: scheduledTime,
      payload: '/',
      categoryIdentifier: 'DAILY_ANCHOR',
    );
  }

  void _scheduleRhythmTasks(DailyRhythm rhythm, DateTime now) {
    int idCounter = 2000;
    for (var task in rhythm.tasks) {
      if (task.isCompleted) continue;
      DateTime? taskTime = _parseTimeString(task.time, now);
      if (taskTime != null) {
        DateTime scheduledTime = taskTime.subtract(const Duration(minutes: 15));
        if (scheduledTime.isAfter(now)) {
          _notificationService.scheduleNotification(
            id: idCounter,
            title: 'Upcoming Protocol',
            body: '${task.title}. You got this! 💪',
            scheduledDate: scheduledTime,
            payload: 'task:${task.id}',
            categoryIdentifier: 'TASK_REMINDER',
          );
          idCounter++;
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // POST-EVENT WORKOUT NUDGE
  // ═══════════════════════════════════════════════════════

  Future<void> firePostWorkoutNudge({int? exerciseMinutes, int? calories, int? avgHr, String? workoutType, String? userName}) async {
    final name = userName ?? 'Hey';
    final duration = exerciseMinutes != null ? '${exerciseMinutes}min' : '';
    final type = workoutType ?? 'Workout';
    
    String body = '$name, $duration $type locked in!';
    if (calories != null && calories > 0) body += ' Burned ${calories}kcal.';
    if (avgHr != null && avgHr > 0) body += ' Avg HR: ${avgHr}bpm.';
    body += ' Time for protein + magnesium. 💪';
    
    // 1. Push notification (Lock screen)
    await _notificationService.showLocalNotification(
      id: 3001,
      title: '$type Summary 🏃‍♂️',
      body: body,
      payload: '/wearables',
    );

    // 2. Activity Alert (In-app banner + Activity History)
    _alertNotifier?.showInsight(
      '$type Complete!',
      body,
      actionRoute: '/wearables',
    );

    debugPrint('🏋️ Post-workout summary fired: $type $duration ${calories}kcal');
  }

  // ═══════════════════════════════════════════════════════
  // SNOOZE HANDLER
  // ═══════════════════════════════════════════════════════

  Future<void> handleSnooze(int notificationId, String title, String body) async {
    final snoozeTime = DateTime.now().add(const Duration(minutes: 15));
    await _notificationService.scheduleNotification(
      id: notificationId + 5000,
      title: title,
      body: '⏰ Snoozed reminder: $body',
      scheduledDate: snoozeTime,
      payload: '/',
      categoryIdentifier: 'TASK_REMINDER',
    );

    // DEEP SYNC: Log the snooze action to the Activity History
    _alertNotifier?.showSystemAlert(
      'Notification Snoozed',
      'Reminder for "$body" moved to ${snoozeTime.hour}:${snoozeTime.minute.toString().padLeft(2, '0')}.',
    );

    debugPrint('⏰ Notification $notificationId snoozed and logged to Activity');
  }

  // ═══════════════════════════════════════════════════════
  // PROACTIVE ALERTS — Data-Driven Nudges
  // ═══════════════════════════════════════════════════════

  /// Fires a sedentary alert if user has been inactive too long.
  /// Called from wearable sync when step delta is flat.
  Future<void> fireSedentaryNudge({String? userName, int? minutesIdle}) async {
    final name = userName ?? 'Hey';
    final mins = minutesIdle ?? 90;
    final body = '$name, you\'ve been still for ${mins}min — even a 2-minute stretch helps. (Source: BJSM, 2021) 🧘';

    await _notificationService.showLocalNotification(
      id: 4001,
      title: 'Movement Check-in',
      body: body,
      payload: '/',
    );

    _alertNotifier?.showInsight(
      'Movement Check-in',
      body,
      actionRoute: '/',
    );

    debugPrint('🪑 Sedentary nudge fired after ${mins}min idle');
  }

  /// Fires a hydration reminder based on time of day and activity.
  Future<void> fireHydrationNudge({String? userName, int? currentSteps}) async {
    final name = userName ?? 'Hey';
    final stepsNote = currentSteps != null && currentSteps > 5000
        ? 'You\'ve hit $currentSteps steps — your body needs extra water today.'
        : 'Staying ahead on hydration keeps your focus sharp.';
    final body = '$name, quick reminder to drink some water. $stepsNote (Source: PMID 23512476) 💧';

    await _notificationService.showLocalNotification(
      id: 4002,
      title: 'Hydration Reminder',
      body: body,
      payload: '/',
    );

    _alertNotifier?.showInsight(
      'Hydration Reminder',
      body,
      actionRoute: '/',
    );

    debugPrint('💧 Hydration nudge fired');
  }

  /// Fires a late-night screen alert if user is active past bedtime.
  Future<void> fireLateNightNudge({String? userName}) async {
    final name = userName ?? 'Hey';
    final hour = DateTime.now().hour;
    if (hour < 23) return; // Only fire after 11 PM

    final body = '$name, it\'s past 11 PM — blue light is suppressing your melatonin right now. (Source: PMID 31105191) 😴';

    await _notificationService.showLocalNotification(
      id: 4003,
      title: 'Sleep Window Open',
      body: body,
      payload: '/',
    );

    _alertNotifier?.showInsight(
      'Sleep Window Open',
      body,
      actionRoute: '/',
    );

    debugPrint('🌙 Late-night nudge fired at $hour:00');
  }

  /// Fires a stress intervention when real-time stress is critically high.
  Future<void> fireStressIntervention({String? userName, int? stressScore}) async {
    final name = userName ?? 'Hey';
    final score = stressScore ?? 80;
    if (score < 70) return; // Only fire for genuinely high stress

    final body = '$name, I\'m seeing elevated stress ($score/100). Try 4-7-8 breathing — inhale 4s, hold 7s, exhale 8s. (Source: JCDR, 2017) 🧠';

    await _notificationService.showLocalNotification(
      id: 4004,
      title: 'Stress Check-in',
      body: body,
      payload: '/',
      categoryIdentifier: 'DAILY_ANCHOR',
    );

    _alertNotifier?.showWarning(
      'Stress Check-in',
      body,
      actionRoute: '/',
    );

    debugPrint('🧠 Stress intervention fired at score $score');
  }

  // ═══════════════════════════════════════════════════════
  // PROACTIVE INTELLIGENCE (Pillar 2)
  // ═══════════════════════════════════════════════════════

  Future<void> scheduleMorningBrief(MorningBrief brief, UserHabitProfile profile) async {
    final now = DateTime.now();
    DateTime scheduledTime = await _getPredictedMorningTime(now);
    
    if (profile.predictedWakeUp != null && profile.wakeConfidence >= 0.3) {
      // 15 mins after predicted wake-up
      scheduledTime = DateTime(now.year, now.month, now.day, profile.predictedWakeUp!.hour, profile.predictedWakeUp!.minute)
          .add(const Duration(minutes: 15));
    }
    
    if (scheduledTime.isBefore(now)) scheduledTime = scheduledTime.add(const Duration(days: 1));

    await _notificationService.scheduleNotification(
      id: 5001,
      title: 'Morning Brief ☀️',
      body: brief.toNotificationBody(),
      scheduledDate: scheduledTime,
      payload: '/',
      categoryIdentifier: 'DAILY_ANCHOR',
    );
  }

  Future<void> scheduleEndOfDayRecap(DayRecap recap, UserHabitProfile profile) async {
    final now = DateTime.now();
    DateTime scheduledTime = DateTime(now.year, now.month, now.day, 21, 30);
    
    if (profile.predictedBedtime != null && profile.bedtimeConfidence >= 0.3) {
      // 30 mins before predicted bedtime
      scheduledTime = DateTime(now.year, now.month, now.day, profile.predictedBedtime!.hour, profile.predictedBedtime!.minute)
          .subtract(const Duration(minutes: 30));
    }
    
    if (scheduledTime.isBefore(now)) scheduledTime = scheduledTime.add(const Duration(days: 1));

    await _notificationService.scheduleNotification(
      id: 5002,
      title: 'Daily Recap 🌙',
      body: recap.toNotificationBody(),
      scheduledDate: scheduledTime,
      payload: '/',
      categoryIdentifier: 'DAILY_ANCHOR',
    );
  }

  Future<void> fireConversationStarter(ProactiveConversation convo) async {
    // Check if we've fired too many today (SharedPreferences check)
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final countKey = 'proactive_pushes_$today';
    int pushesToday = prefs.getInt(countKey) ?? 0;
    
    // Up to 3 proactive pushes per day
    if (pushesToday >= 3) return;
    
    await _notificationService.showLocalNotification(
      id: 5003 + pushesToday,
      title: convo.title,
      body: convo.body,
      payload: '/',
    );
    
    _alertNotifier?.showInsight(
      convo.title,
      convo.body,
      actionRoute: '/chat', // Discuss pattern
    );
    
    await prefs.setInt(countKey, pushesToday + 1);
  }

  // ═══════════════════════════════════════════════════════
  // TIME PARSING
  // ═══════════════════════════════════════════════════════

  DateTime? _parseTimeString(String? timeStr, DateTime now) {
    if (timeStr == null) return null;
    try {
      timeStr = timeStr.trim().toLowerCase();
      if (timeStr.isEmpty || timeStr == 'anytime' || timeStr == 'with meal') return null;
      final timeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)');
      final match = timeRegex.firstMatch(timeStr);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        int minute = int.parse(match.group(2)!);
        String period = match.group(3)!;
        if (hour > 12) return null;
        if (period == 'pm' && hour < 12) hour += 12;
        if (period == 'am' && hour == 12) hour = 0;
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
      if (timeStr.contains('morning')) return DateTime(now.year, now.month, now.day, 9, 0);
      if (timeStr.contains('afternoon')) return DateTime(now.year, now.month, now.day, 14, 0);
      if (timeStr.contains('evening') || timeStr.contains('night')) return DateTime(now.year, now.month, now.day, 20, 0);
      return null;
    } catch (e) {
      return null;
    }
  }
}
