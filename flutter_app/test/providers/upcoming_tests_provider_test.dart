import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/data/programme_journey.dart';
import 'package:zyndio_patient/providers/my_plan_provider.dart';
import 'package:zyndio_patient/providers/programme_journey_provider.dart';

List<UpcomingTest> _read(ProgrammeJourney? j) {
  final c = ProviderContainer(
      overrides: [programmeJourneyProvider.overrideWithValue(j)]);
  addTearDown(c.dispose);
  return c.read(upcomingTestsProvider);
}

ProgrammeJourney _j(List<DateTime> scans, DateTime today) =>
    buildProgrammeJourney(
      scanDates: scans,
      hasLabResults: true,
      hasCarePlan: true,
      today: today,
    );

void main() {
  test('nothing while the records load', () {
    expect(_read(null), isEmpty);
  });

  test('before the baseline: the baseline DEXASCAN, no invented date', () {
    final t = _read(_j(const [], DateTime.utc(2026, 11, 9)));
    expect(t.single.title, 'Baseline DEXASCAN');
    expect(t.single.due, isNull);
  });

  test('after the baseline: the next milestone with its date', () {
    final t = _read(_j([DateTime.utc(2026, 10, 1)], DateTime.utc(2026, 11, 9)));
    expect(t.single.title, 'Day 90 DEXASCAN and lab panel');
    expect(t.single.due, DateTime.utc(2026, 12, 30));
  });

  test('first programme year complete: nothing left to schedule', () {
    final t = _read(_j([DateTime.utc(2025, 1, 1), DateTime.utc(2026, 1, 2)],
        DateTime.utc(2026, 3, 1)));
    expect(t, isEmpty);
  });
}
