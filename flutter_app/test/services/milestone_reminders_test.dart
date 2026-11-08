import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/data/programme_journey.dart';
import 'package:zyndio_patient/services/milestone_reminders.dart';

class _FakeScheduler implements MilestoneReminderScheduler {
  final cancelled = <int>[];
  final scheduled = <int, DateTime>{};
  bool fail = false;

  @override
  Future<void> cancel(int id) async {
    if (fail) throw StateError('plugin missing');
    cancelled.add(id);
  }

  @override
  Future<void> schedule(int id, DateTime at) async => scheduled[id] = at;
}

ProgrammeJourney _journey(List<DateTime> scans, DateTime today) =>
    buildProgrammeJourney(
      scanDates: scans,
      hasLabResults: true,
      hasCarePlan: true,
      today: today,
    );

void main() {
  final base = DateTime.utc(2026, 1, 1); // Day 90 = 1 Apr, 180 = 30 Jun.

  test('no baseline: no reminders', () {
    final j = buildProgrammeJourney(
        scanDates: const [],
        hasLabResults: false,
        hasCarePlan: false,
        today: base);
    expect(planMilestoneReminders(j, DateTime(2026, 1, 2)), isEmpty);
  });

  test('two reminders per open milestone at 9:00: window opening and the date',
      () {
    final plan =
        planMilestoneReminders(_journey([base], base), DateTime(2026, 1, 2));
    expect(plan.length, 6);
    final day90 = plan.where((r) => r.milestoneDay == 90).toList();
    expect(day90.map((r) => r.at),
        [DateTime(2026, 3, 2, 9), DateTime(2026, 4, 1, 9)]);
    // Ids are reserved and unique.
    expect(plan.map((r) => r.id).toSet().length, 6);
    expect(plan.every((r) => isMilestoneReminderId(r.id)), isTrue);
    // In time order.
    final times = plan.map((r) => r.at).toList();
    expect(times, [...times]..sort());
  });

  test('completed milestones and past times are dropped', () {
    final j = _journey([base, DateTime.utc(2026, 4, 3)], DateTime.utc(2026, 4, 5));
    final plan = planMilestoneReminders(j, DateTime(2026, 4, 5, 12));
    expect(plan.any((r) => r.milestoneDay == 90), isFalse);
    expect(plan.map((r) => r.milestoneDay).toSet(), {180, 365});
  });

  test('sync cancels every reserved id, then schedules the plan', () async {
    final s = _FakeScheduler();
    final ok = await syncMilestoneReminders(_journey([base], base), s,
        now: DateTime(2026, 1, 2));
    expect(ok, isTrue);
    expect(s.cancelled.toSet(), kMilestoneReminderIds);
    expect(s.scheduled.length, 6);
  });

  test('sync never throws when the platform plugin fails', () async {
    final s = _FakeScheduler()..fail = true;
    final ok = await syncMilestoneReminders(_journey([base], base), s,
        now: DateTime(2026, 1, 2));
    expect(ok, isFalse);
    expect(s.scheduled, isEmpty);
  });

  test('reminder ids do not overlap the daily rhythm ids (1001-5999)', () {
    expect(kMilestoneReminderIds.every((id) => id >= 6000), isTrue);
  });
}
