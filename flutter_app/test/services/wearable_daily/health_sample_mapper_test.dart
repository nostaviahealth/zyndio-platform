// APP-07: package:health data points -> WearableSample. Only the recording
// app's id and a coarse device class are kept - never the source's display
// name. Fictional data only.
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:zyndio_patient/services/wearable_daily/health_sample_mapper.dart';
import 'package:zyndio_patient/services/wearable_daily/wearable_daily_aggregator.dart';
import 'package:zyndio_patient/services/wearable_daily/wearable_metric.dart';

HealthDataPoint point(
  HealthDataType type,
  HealthValue value, {
  DateTime? from,
  DateTime? to,
  String sourceId = 'com.apple.health.FICTIONAL-0001',
  String sourceName = "Fictional Person's Apple Watch",
  String? deviceModel = 'Watch',
}) =>
    HealthDataPoint(
      uuid: 'fictional-uuid',
      value: value,
      type: type,
      unit: HealthDataUnit.NO_UNIT,
      dateFrom: from ?? DateTime(2026, 10, 1, 8),
      dateTo: to ?? DateTime(2026, 10, 1, 8, 5),
      sourcePlatform: HealthPlatformType.appleHealth,
      sourceDeviceId: 'fictional-device',
      sourceId: sourceId,
      sourceName: sourceName,
      deviceModel: deviceModel,
    );

NumericHealthValue n(num v) => NumericHealthValue(numericValue: v);

void main() {
  test('HRV SDNN and RMSSD map to separate metrics', () {
    expect(
        wearableSampleFromHealthPoint(
                point(HealthDataType.HEART_RATE_VARIABILITY_SDNN, n(44)))!
            .metric,
        WearableMetric.hrvSdnn);
    expect(
        wearableSampleFromHealthPoint(
                point(HealthDataType.HEART_RATE_VARIABILITY_RMSSD, n(33)))!
            .metric,
        WearableMetric.hrvRmssd);
  });

  test('Apple Health SpO2 fractions become percent', () {
    expect(
        wearableSampleFromHealthPoint(
                point(HealthDataType.BLOOD_OXYGEN, n(0.97)))!
            .value,
        closeTo(97, 1e-9));
    expect(
        wearableSampleFromHealthPoint(
                point(HealthDataType.BLOOD_OXYGEN, n(96)))!
            .value,
        96);
  });

  test('sleep stages and sessions become sleep intervals', () {
    final stage = wearableSampleFromHealthPoint(point(
        HealthDataType.SLEEP_DEEP, n(0),
        from: DateTime(2026, 10, 1, 23), to: DateTime(2026, 10, 2, 1)))!;
    expect(stage.metric, WearableMetric.sleepMinutes);
    expect(stage.isSleepSession, isFalse);
    expect(stage.end.difference(stage.start), const Duration(hours: 2));
    final session = wearableSampleFromHealthPoint(point(
        HealthDataType.SLEEP_SESSION, n(0),
        from: DateTime(2026, 10, 1, 23), to: DateTime(2026, 10, 2, 7)))!;
    expect(session.isSleepSession, isTrue);
  });

  test('a Health Connect workout counts as exercise minutes', () {
    final w = wearableSampleFromHealthPoint(point(
      HealthDataType.WORKOUT,
      WorkoutHealthValue(
          workoutActivityType: HealthWorkoutActivityType.WALKING),
      from: DateTime(2026, 10, 1, 7),
      to: DateTime(2026, 10, 1, 7, 45),
      sourceId: 'com.example.fictional.android',
      deviceModel: null,
    ))!;
    expect(w.metric, WearableMetric.exerciseMinutes);
    expect(w.value, 45);
  });

  test('types that are not uploaded map to nothing', () {
    expect(wearableSampleFromHealthPoint(point(HealthDataType.HEIGHT, n(1.8))),
        isNull);
    expect(
        wearableSampleFromHealthPoint(point(HealthDataType.HEART_RATE, n(70))),
        isNull);
    expect(
        wearableSampleFromHealthPoint(
            point(HealthDataType.STEPS, n(10), sourceId: '  ')),
        isNull);
  });

  test('the source display name never leaves the mapper', () {
    final sample =
        wearableSampleFromHealthPoint(point(HealthDataType.STEPS, n(120)))!;
    expect(sample.sourceApp, 'com.apple.health.FICTIONAL-0001');
    expect(sample.sourceDevice, WearableDeviceClass.watch);
    final row = aggregateWearableDaily([sample]).single;
    final body = row.toUpsertJson(patientId: 'p', orgId: 'o').toString();
    expect(body, isNot(contains('Fictional Person')));
    expect(body, isNot(contains('Apple Watch')));
  });

  test('device classes', () {
    expect(wearableDeviceClassFor(sourceId: 'x', deviceModel: 'iPhone'),
        WearableDeviceClass.phone);
    expect(wearableDeviceClassFor(sourceId: 'com.ouraring.oura'),
        WearableDeviceClass.ring);
    expect(wearableDeviceClassFor(sourceId: 'com.withings.wiscale2'),
        WearableDeviceClass.scale);
    expect(wearableDeviceClassFor(sourceId: 'com.fitbit.FitbitMobile'),
        WearableDeviceClass.watch);
    expect(wearableDeviceClassFor(sourceId: 'com.sec.android.app.shealth'),
        WearableDeviceClass.other);
  });
}
