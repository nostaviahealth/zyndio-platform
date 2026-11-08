import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/data/programme_journey.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

void main() {
  group('setup before the baseline scan', () {
    test('nothing yet: three steps, none done, labs first, no milestones', () {
      final j = buildProgrammeJourney(
        scanDates: const [],
        hasLabResults: false,
        hasCarePlan: false,
        today: d(2026, 11, 9),
      );
      expect(j.setup.map((s) => s.step), ProgrammeSetupStep.values);
      expect(j.setupDone, 0);
      expect(j.nextSetupStep!.step, ProgrammeSetupStep.baselineLabs);
      expect(j.hasBaseline, isFalse);
      expect(j.programmeDay, isNull);
      expect(j.milestones, isEmpty);
      expect(j.nextMilestone, isNull);
      expect(j.bookingOpen, isFalse);
    });

    test('labs done: the scan is next', () {
      final j = buildProgrammeJourney(
        scanDates: const [],
        hasLabResults: true,
        hasCarePlan: false,
        today: d(2026, 11, 9),
      );
      expect(j.setupDone, 1);
      expect(j.nextSetupStep!.step, ProgrammeSetupStep.baselineScan);
    });
  });

  group('milestones after the baseline', () {
    test('dates are baseline + 90 / 180 / 365 and the earliest scan is baseline', () {
      final j = buildProgrammeJourney(
        scanDates: [d(2026, 10, 1)],
        hasLabResults: true,
        hasCarePlan: true,
        today: d(2026, 10, 11),
      );
      expect(j.baselineDate, d(2026, 10, 1));
      expect(j.programmeDay, 10);
      expect(j.milestones.map((m) => m.day), [90, 180, 365]);
      expect(j.milestones.map((m) => m.target),
          [d(2026, 12, 30), d(2027, 3, 30), d(2027, 10, 1)]);
      expect(j.milestones.every((m) => m.status == MilestoneStatus.upcoming),
          isTrue);
      expect(j.nextMilestone!.day, 90);
      expect(j.daysUntil(j.nextMilestone!), 80);
      expect(j.bookingOpen, isFalse);
      expect(j.setupComplete, isTrue);
    });

    test('booking opens when the window opens, 30 days before the date', () {
      final base = d(2026, 1, 1);
      final target = base.add(const Duration(days: 90));
      ProgrammeJourney at(DateTime today) => buildProgrammeJourney(
            scanDates: [base],
            hasLabResults: true,
            hasCarePlan: true,
            today: today,
          );
      expect(at(target.subtract(const Duration(days: 31))).bookingOpen, isFalse);
      expect(at(target.subtract(const Duration(days: 30))).bookingOpen, isTrue);
    });

    test('a follow-up within 30 days completes the nearest milestone', () {
      final j = buildProgrammeJourney(
        // Demo story: baseline, Day 92 and Day 177 scans.
        scanDates: [d(2026, 10, 2), d(2026, 4, 8), d(2026, 7, 9)],
        hasLabResults: true,
        hasCarePlan: true,
        today: d(2026, 11, 9),
      );
      expect(j.baselineDate, d(2026, 4, 8));
      expect(j.programmeDay, 215);
      expect(j.milestones[0].status, MilestoneStatus.completed);
      expect(j.milestones[0].scanDate, d(2026, 7, 9));
      expect(j.milestones[1].status, MilestoneStatus.completed);
      expect(j.milestones[1].scanDate, d(2026, 10, 2));
      expect(j.milestones[2].status, MilestoneStatus.upcoming);
      expect(j.nextMilestone!.day, 365);
      expect(j.completedMilestones, 2);
    });

    test('a scan outside every window completes nothing', () {
      final j = buildProgrammeJourney(
        scanDates: [d(2026, 1, 1), d(2026, 2, 10)], // Day 40
        hasLabResults: true,
        hasCarePlan: true,
        today: d(2026, 2, 11),
      );
      expect(j.completedMilestones, 0);
    });

    test('window open and passed: due now, then not recorded', () {
      final base = d(2026, 1, 1);
      final target = base.add(const Duration(days: 90));
      ProgrammeJourney at(int offset) => buildProgrammeJourney(
            scanDates: [base],
            hasLabResults: true,
            hasCarePlan: true,
            today: target.add(Duration(days: offset)),
          );
      expect(at(-31).milestones.first.status, MilestoneStatus.upcoming);
      expect(at(-30).milestones.first.status, MilestoneStatus.dueNow);
      expect(at(30).milestones.first.status, MilestoneStatus.dueNow);
      expect(at(31).milestones.first.status, MilestoneStatus.notRecorded);
      // The next one to act on moves on to Day 180.
      expect(at(31).nextMilestone!.day, 180);
      expect(at(5).bookingOpen, isTrue);
    });

    test('after Day 365 there is no next milestone', () {
      final j = buildProgrammeJourney(
        scanDates: [d(2025, 1, 1), d(2026, 1, 2)],
        hasLabResults: true,
        hasCarePlan: true,
        today: d(2026, 3, 1),
      );
      expect(j.milestones.last.status, MilestoneStatus.completed);
      expect(j.nextMilestone, isNull);
      expect(j.bookingOpen, isFalse);
    });

    test('two scans in one window: the closer one counts', () {
      final j = buildProgrammeJourney(
        scanDates: [d(2026, 1, 1), d(2026, 3, 20), d(2026, 4, 2)],
        hasLabResults: true,
        hasCarePlan: true,
        today: d(2026, 4, 10),
      );
      // Day 90 is 1 Apr 2026.
      expect(j.milestones.first.scanDate, d(2026, 4, 2));
    });

    test('a stored timestamp is read as its calendar date', () {
      expect(parseCalendarDate('2026-04-08'), d(2026, 4, 8));
      expect(parseCalendarDate('2026-04-08T23:30:00'), d(2026, 4, 8));
      expect(parseCalendarDate('not a date'), isNull);
    });
  });
}
