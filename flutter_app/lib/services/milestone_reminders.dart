import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/programme_journey.dart';
import 'notification_service.dart';

/// Local reminders to book the Day 90 / 180 / 365 scan and labs (APP-14).
///
/// Each open milestone gets two reminders at 9:00 local time: one when the
/// booking window opens ([kMilestoneWindowDays] before the date) and one
/// on the date itself. The visible text is always the neutral copy
/// [NotificationService] enforces (APP-10), so nothing about the patient's
/// health appears on the lock screen.

/// Notification ids reserved for milestone reminders.
const int kMilestoneReminderIdBase = 7400;

/// Every id this feature may use, so stale ones can be cancelled.
final Set<int> kMilestoneReminderIds = {
  for (final day in kProgrammeMilestoneDays) ...{
    kMilestoneReminderIdBase + day * 2,
    kMilestoneReminderIdBase + day * 2 + 1,
  },
};

bool isMilestoneReminderId(int id) => kMilestoneReminderIds.contains(id);

/// The deep-link payload: tapping the reminder opens Body Composition.
const String kMilestoneReminderPayload = '/progress';

typedef PlannedReminder = ({int id, DateTime at, int milestoneDay});

/// The reminders [journey] needs from [now] on, in time order. Completed and
/// past milestones get none; reminders already in the past are dropped.
List<PlannedReminder> planMilestoneReminders(
    ProgrammeJourney journey, DateTime now) {
  final out = <PlannedReminder>[];
  for (final m in journey.milestones) {
    if (m.status != MilestoneStatus.upcoming &&
        m.status != MilestoneStatus.dueNow) {
      continue;
    }
    final lead =
        m.target.subtract(const Duration(days: kMilestoneWindowDays));
    final candidates = [
      (id: kMilestoneReminderIdBase + m.day * 2, date: lead),
      (id: kMilestoneReminderIdBase + m.day * 2 + 1, date: m.target),
    ];
    for (final c in candidates) {
      final at = DateTime(c.date.year, c.date.month, c.date.day, 9);
      if (at.isAfter(now)) {
        out.add((id: c.id, at: at, milestoneDay: m.day));
      }
    }
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// The two notification operations the reminders need, so tests can fake
/// them without the platform plugin.
abstract class MilestoneReminderScheduler {
  Future<void> cancel(int id);
  Future<void> schedule(int id, DateTime at);
}

class _PlatformScheduler implements MilestoneReminderScheduler {
  _PlatformScheduler(this._service);
  final NotificationService _service;

  @override
  Future<void> cancel(int id) => _service.cancel(id);

  @override
  Future<void> schedule(int id, DateTime at) => _service.scheduleNotification(
        id: id,
        // Never displayed: NotificationService shows fixed neutral copy.
        title: 'Reminder',
        body: 'Reminder',
        scheduledDate: at,
        payload: kMilestoneReminderPayload,
      );
}

final milestoneReminderSchedulerProvider =
    Provider<MilestoneReminderScheduler?>((ref) {
  // Local notifications are not available on the web build.
  if (kIsWeb) return null;
  return _PlatformScheduler(NotificationService());
});

/// Replaces every milestone reminder with the ones [journey] needs now.
/// Failures are swallowed (a missing reminder must never break the app);
/// returns whether every call succeeded, so callers can try again later.
Future<bool> syncMilestoneReminders(
  ProgrammeJourney journey,
  MilestoneReminderScheduler scheduler, {
  DateTime? now,
}) async {
  final plan = planMilestoneReminders(journey, now ?? DateTime.now());
  try {
    for (final id in kMilestoneReminderIds) {
      await scheduler.cancel(id);
    }
    for (final r in plan) {
      await scheduler.schedule(r.id, r.at);
    }
    return true;
  } catch (e) {
    debugPrint('Milestone reminders not scheduled: ${e.runtimeType}');
    return false;
  }
}
