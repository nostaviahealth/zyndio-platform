// APP-07: on-device daily aggregation for wearable_daily. One value per
// metric per local day per source; sources are never added together; one
// source is selected per metric and day; sleep is one value per night filed
// under the wake date; HRV SDNN and RMSSD stay separate; repeat runs give the
// same rows (idempotent upload keys). Fictional data only.
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/services/wearable_daily/wearable_daily_aggregator.dart';
import 'package:zyndio_patient/services/wearable_daily/wearable_metric.dart';

const watchApp = 'com.example.fictional.watchapp';
const phoneApp = 'com.example.fictional.phoneapp';
const ringApp = 'com.example.fictional.ringapp';

WearableSample s(
  WearableMetric metric,
  double value,
  DateTime start, [
  DateTime? end,
  String app = watchApp,
  WearableDeviceClass device = WearableDeviceClass.watch,
  bool session = false,
]) =>
    WearableSample(
      metric: metric,
      value: value,
      start: start,
      end: end ?? start,
      sourceApp: app,
      sourceDevice: device,
      isSleepSession: session,
    );

WearableSample sleep(DateTime start, DateTime end,
        {String app = watchApp,
        WearableDeviceClass device = WearableDeviceClass.watch,
        bool session = false}) =>
    s(WearableMetric.sleepMinutes, 0, start, end, app, device, session);

List<WearableDailyRow> rowsFor(List<WearableDailyRow> rows, WearableMetric m,
        [DateTime? date]) =>
    rows
        .where((r) => r.metric == m && (date == null || r.metricDate == date))
        .toList();

WearableDailyRow selectedFor(
        List<WearableDailyRow> rows, WearableMetric m, DateTime date) =>
    rowsFor(rows, m, date).singleWhere((r) => r.selected);

void main() {
  final oct1 = DateTime(2026, 10, 1);
  final oct2 = DateTime(2026, 10, 2);

  group('sources are never added together', () {
    test(
        'watch and phone steps on the same day give two rows, one selected, no sum',
        () {
      final rows = aggregateWearableDaily([
        s(WearableMetric.steps, 5000, DateTime(2026, 10, 1, 9),
            DateTime(2026, 10, 1, 10)),
        s(WearableMetric.steps, 3000, DateTime(2026, 10, 1, 17),
            DateTime(2026, 10, 1, 18)),
        s(WearableMetric.steps, 6500, DateTime(2026, 10, 1, 9),
            DateTime(2026, 10, 1, 18), phoneApp, WearableDeviceClass.phone),
      ]);
      final steps = rowsFor(rows, WearableMetric.steps, oct1);
      expect(steps, hasLength(2));
      expect(steps.where((r) => r.selected), hasLength(1));
      final chosen = selectedFor(rows, WearableMetric.steps, oct1);
      expect(chosen.sourceApp, watchApp,
          reason: 'default policy prefers the watch for activity');
      expect(chosen.value, 8000);
      expect(steps.map((r) => r.value), isNot(contains(14500)));
      expect(steps.map((r) => r.value), isNot(contains(13000)));
    });

    test('a configured preferred app beats the device-class order', () {
      final rows = aggregateWearableDaily([
        s(WearableMetric.steps, 8000, DateTime(2026, 10, 1, 9),
            DateTime(2026, 10, 1, 10)),
        s(WearableMetric.steps, 6500, DateTime(2026, 10, 1, 9),
            DateTime(2026, 10, 1, 10), phoneApp, WearableDeviceClass.phone),
      ], policy: const WearableSourcePolicy(preferredApps: [phoneApp]));
      expect(selectedFor(rows, WearableMetric.steps, oct1).sourceApp, phoneApp);
    });

    test(
        'same device class: higher coverage wins, then source name (deterministic)',
        () {
      final rows = aggregateWearableDaily([
        s(WearableMetric.activeEnergyKcal, 300, DateTime(2026, 10, 1, 8),
            DateTime(2026, 10, 1, 9), ringApp, WearableDeviceClass.other),
        s(WearableMetric.activeEnergyKcal, 250, DateTime(2026, 10, 1, 8),
            DateTime(2026, 10, 1, 20), phoneApp, WearableDeviceClass.other),
      ]);
      expect(selectedFor(rows, WearableMetric.activeEnergyKcal, oct1).sourceApp,
          phoneApp);

      final tie = aggregateWearableDaily([
        s(WearableMetric.restingHr, 60, DateTime(2026, 10, 1, 7), null, ringApp,
            WearableDeviceClass.other),
        s(WearableMetric.restingHr, 62, DateTime(2026, 10, 1, 7), null,
            phoneApp, WearableDeviceClass.other),
      ]);
      expect(
          selectedFor(tie, WearableMetric.restingHr, oct1).sourceApp, phoneApp,
          reason: 'alphabetical tie-break');
    });

    test('weight prefers a scale over the watch', () {
      final rows = aggregateWearableDaily([
        s(WearableMetric.weightKg, 82.4, DateTime(2026, 10, 1, 7)),
        s(WearableMetric.weightKg, 82.1, DateTime(2026, 10, 1, 7, 5), null,
            'com.example.fictional.scaleapp', WearableDeviceClass.scale),
      ]);
      expect(selectedFor(rows, WearableMetric.weightKg, oct1).value, 82.1);
    });
  });

  group('one value per metric per day', () {
    test('steps sum within a source; a sample across midnight is split by time',
        () {
      final rows = aggregateWearableDaily([
        s(WearableMetric.steps, 1000, DateTime(2026, 10, 1, 23, 30),
            DateTime(2026, 10, 2, 0, 30)),
        s(WearableMetric.steps, 400, DateTime(2026, 10, 2, 8),
            DateTime(2026, 10, 2, 8, 10)),
      ]);
      expect(selectedFor(rows, WearableMetric.steps, oct1).value, 500);
      expect(selectedFor(rows, WearableMetric.steps, oct2).value, 900);
    });

    test('coverage is the share of the day\'s clock hours that hold samples',
        () {
      final rows = aggregateWearableDaily([
        s(WearableMetric.steps, 100, DateTime(2026, 10, 1, 8, 10),
            DateTime(2026, 10, 1, 8, 20)),
        s(WearableMetric.steps, 100, DateTime(2026, 10, 1, 8, 40),
            DateTime(2026, 10, 1, 8, 50)),
        s(WearableMetric.steps, 100, DateTime(2026, 10, 1, 12),
            DateTime(2026, 10, 1, 14)),
      ]);
      // hours 8, 12, 13 -> 3 / 24
      expect(selectedFor(rows, WearableMetric.steps, oct1).coverage, 0.125);
    });

    test(
        'resting HR and blood pressure are the day\'s mean, weight the last reading',
        () {
      final rows = aggregateWearableDaily([
        s(WearableMetric.restingHr, 60, DateTime(2026, 10, 1, 6)),
        s(WearableMetric.restingHr, 64, DateTime(2026, 10, 1, 22)),
        s(WearableMetric.bpSystolic, 128, DateTime(2026, 10, 1, 7)),
        s(WearableMetric.bpSystolic, 121, DateTime(2026, 10, 1, 19)),
        s(WearableMetric.weightKg, 83.0, DateTime(2026, 10, 1, 7)),
        s(WearableMetric.weightKg, 82.6, DateTime(2026, 10, 1, 21)),
      ]);
      expect(selectedFor(rows, WearableMetric.restingHr, oct1).value, 62);
      expect(selectedFor(rows, WearableMetric.bpSystolic, oct1).value, 125);
      expect(selectedFor(rows, WearableMetric.weightKg, oct1).value, 82.6);
    });

    test('implausible readings are dropped (the server would refuse the batch)',
        () {
      final rows = aggregateWearableDaily([
        s(WearableMetric.restingHr, 400, DateTime(2026, 10, 1, 6)),
        s(WearableMetric.restingHr, 58, DateTime(2026, 10, 1, 7)),
        s(WearableMetric.spo2, 0.97, DateTime(2026, 10, 1, 3)),
        s(WearableMetric.weightKg, 5000, DateTime(2026, 10, 1, 7)),
      ]);
      expect(selectedFor(rows, WearableMetric.restingHr, oct1).value, 58);
      expect(rowsFor(rows, WearableMetric.spo2), isEmpty);
      expect(rowsFor(rows, WearableMetric.weightKg), isEmpty);
      for (final r in rows) {
        expect(r.metric.isPlausible(r.value), isTrue, reason: '$r');
      }
    });

    test('HRV SDNN (iOS) and RMSSD (Android) stay separate metrics', () {
      final rows = aggregateWearableDaily([
        s(WearableMetric.hrvSdnn, 40, DateTime(2026, 10, 1, 3)),
        s(WearableMetric.hrvSdnn, 50, DateTime(2026, 10, 1, 4)),
        s(WearableMetric.hrvRmssd, 31, DateTime(2026, 10, 1, 3), null, ringApp,
            WearableDeviceClass.ring),
      ]);
      expect(selectedFor(rows, WearableMetric.hrvSdnn, oct1).value, 45);
      expect(selectedFor(rows, WearableMetric.hrvRmssd, oct1).value, 31);
      expect(rows.map((r) => r.metric.wireName).toSet(),
          {'hrv_sdnn', 'hrv_rmssd'});
    });
  });

  group('sleep: one value per night, on the wake date', () {
    test('a night across midnight is filed under the wake date', () {
      final rows = aggregateWearableDaily(
          [sleep(DateTime(2026, 10, 1, 23), DateTime(2026, 10, 2, 7))]);
      expect(rowsFor(rows, WearableMetric.sleepMinutes, oct1), isEmpty);
      expect(selectedFor(rows, WearableMetric.sleepMinutes, oct2).value, 480);
    });

    test(
        'overlapping stage records never count twice; awake gaps are not sleep',
        () {
      final rows = aggregateWearableDaily([
        sleep(DateTime(2026, 10, 1, 23), DateTime(2026, 10, 2, 3)),
        sleep(DateTime(2026, 10, 2, 1),
            DateTime(2026, 10, 2, 2)), // deep, inside the above
        sleep(DateTime(2026, 10, 2, 4),
            DateTime(2026, 10, 2, 7)), // after 1h awake
      ]);
      expect(selectedFor(rows, WearableMetric.sleepMinutes, oct2).value, 420);
    });

    test('a nap is not added to the night', () {
      final rows = aggregateWearableDaily([
        sleep(DateTime(2026, 10, 1, 23), DateTime(2026, 10, 2, 7)),
        sleep(DateTime(2026, 10, 2, 14), DateTime(2026, 10, 2, 15)),
      ]);
      expect(rowsFor(rows, WearableMetric.sleepMinutes, oct2), hasLength(1));
      expect(selectedFor(rows, WearableMetric.sleepMinutes, oct2).value, 480);
    });

    test('a stage-less session counts only where the source has no stages', () {
      final rows = aggregateWearableDaily([
        // night 1: session only (Health Connect without stages)
        sleep(DateTime(2026, 9, 30, 22, 30), DateTime(2026, 10, 1, 6, 30),
            session: true),
        // night 2: session plus stages - the stages win
        sleep(DateTime(2026, 10, 1, 22), DateTime(2026, 10, 2, 7),
            session: true),
        sleep(DateTime(2026, 10, 1, 22, 30), DateTime(2026, 10, 2, 6)),
      ]);
      expect(selectedFor(rows, WearableMetric.sleepMinutes, oct1).value, 480);
      expect(selectedFor(rows, WearableMetric.sleepMinutes, oct2).value, 450);
    });

    test('two sources of sleep are never added together', () {
      final rows = aggregateWearableDaily([
        sleep(DateTime(2026, 10, 1, 23), DateTime(2026, 10, 2, 7)),
        sleep(DateTime(2026, 10, 1, 23, 15), DateTime(2026, 10, 2, 6, 45),
            app: ringApp, device: WearableDeviceClass.ring),
      ]);
      final nights = rowsFor(rows, WearableMetric.sleepMinutes, oct2);
      expect(nights.map((r) => r.value).toSet(), {480, 450});
      expect(nights.where((r) => r.selected), hasLength(1));
    });
  });

  group('idempotent upload rows', () {
    final samples = [
      s(WearableMetric.steps, 5000, DateTime(2026, 10, 1, 9),
          DateTime(2026, 10, 1, 10)),
      s(WearableMetric.steps, 6500, DateTime(2026, 10, 1, 9),
          DateTime(2026, 10, 1, 18), phoneApp, WearableDeviceClass.phone),
      sleep(DateTime(2026, 10, 1, 23), DateTime(2026, 10, 2, 7)),
    ];

    test('keys are unique per date + metric + source and stable across runs',
        () {
      final a = aggregateWearableDaily(samples);
      final b = aggregateWearableDaily(samples.reversed);
      expect(a.map((r) => r.key).toSet(), hasLength(a.length));
      expect(a.map((r) => '${r.key}=${r.value}/${r.selected}'),
          b.map((r) => '${r.key}=${r.value}/${r.selected}'));
      expect(a.first.key, '2026-10-01|steps|$watchApp');
    });

    test(
        'the same sample read twice (overlapping windows) is not counted twice',
        () {
      final rows = aggregateWearableDaily([...samples, ...samples]);
      expect(selectedFor(rows, WearableMetric.steps, oct1).value, 5000);
      expect(selectedFor(rows, WearableMetric.sleepMinutes, oct2).value, 480);
    });

    test('fromDate / toDate keep only the window\'s days', () {
      final rows =
          aggregateWearableDaily(samples, fromDate: oct2, toDate: oct2);
      expect(rows.map((r) => r.metric), [WearableMetric.sleepMinutes]);
    });

    test('upsert body uses the wearable_daily columns and canonical units', () {
      final row = selectedFor(
          aggregateWearableDaily(samples), WearableMetric.steps, oct1);
      expect(row.toUpsertJson(patientId: 'p-1', orgId: 'o-1'), {
        'org_id': 'o-1',
        'patient_id': 'p-1',
        'metric_date': '2026-10-01',
        'metric': 'steps',
        'value': 5000.0,
        'unit': 'count',
        'source_app': watchApp,
        'source_device': 'watch',
        'coverage': 0.042,
        'selected': true,
      });
    });
  });
}
