import 'package:health/health.dart';

import 'wearable_daily_aggregator.dart';
import 'wearable_metric.dart';

/// APP-07: maps `package:health` data points (Apple Health / Health Connect)
/// onto [WearableSample]s for [aggregateWearableDaily].
///
/// Only the recording app's id (bundle id / package name) and a coarse device
/// class leave this file; the source's display name (often "NAME's Apple
/// Watch") is used only to guess the class and is never uploaded.

/// The health-plugin types read for upload on each platform.
const wearableUploadTypesIOS = <HealthDataType>[
  HealthDataType.STEPS,
  HealthDataType.EXERCISE_TIME,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_REM,
  HealthDataType.WEIGHT,
  HealthDataType.BODY_MASS_INDEX,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  HealthDataType.BLOOD_OXYGEN,
];

/// Android: exercise minutes come from workouts (Health Connect has no
/// exercise-time record); BMI is computed by the plugin from weight + height.
const wearableUploadTypesAndroid = <HealthDataType>[
  HealthDataType.STEPS,
  HealthDataType.WORKOUT,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.RESTING_HEART_RATE,
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
  HealthDataType.SLEEP_SESSION,
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_REM,
  HealthDataType.WEIGHT,
  HealthDataType.HEIGHT,
  HealthDataType.BODY_MASS_INDEX,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
  HealthDataType.BLOOD_OXYGEN,
];

const _sleepStageTypes = {
  HealthDataType.SLEEP_ASLEEP,
  HealthDataType.SLEEP_DEEP,
  HealthDataType.SLEEP_LIGHT,
  HealthDataType.SLEEP_REM,
};

const _numericTypes = <HealthDataType, WearableMetric>{
  HealthDataType.STEPS: WearableMetric.steps,
  HealthDataType.EXERCISE_TIME: WearableMetric.exerciseMinutes,
  HealthDataType.ACTIVE_ENERGY_BURNED: WearableMetric.activeEnergyKcal,
  HealthDataType.RESTING_HEART_RATE: WearableMetric.restingHr,
  HealthDataType.HEART_RATE_VARIABILITY_SDNN: WearableMetric.hrvSdnn,
  HealthDataType.HEART_RATE_VARIABILITY_RMSSD: WearableMetric.hrvRmssd,
  HealthDataType.WEIGHT: WearableMetric.weightKg,
  HealthDataType.BODY_MASS_INDEX: WearableMetric.bmi,
  HealthDataType.BLOOD_PRESSURE_SYSTOLIC: WearableMetric.bpSystolic,
  HealthDataType.BLOOD_PRESSURE_DIASTOLIC: WearableMetric.bpDiastolic,
  HealthDataType.BLOOD_OXYGEN: WearableMetric.spo2,
};

/// Returns null for types/values that are not uploaded (e.g. HEIGHT, which
/// is read only so the plugin can compute Android BMI).
WearableSample? wearableSampleFromHealthPoint(HealthDataPoint p) {
  final sourceApp = p.sourceId.trim();
  if (sourceApp.isEmpty) return null;
  final app = sourceApp.length > 200 ? sourceApp.substring(0, 200) : sourceApp;
  final device = wearableDeviceClassFor(
    sourceId: p.sourceId,
    sourceName: p.sourceName,
    deviceModel: p.deviceModel,
  );

  if (_sleepStageTypes.contains(p.type) ||
      p.type == HealthDataType.SLEEP_SESSION) {
    return WearableSample(
      metric: WearableMetric.sleepMinutes,
      value: p.dateTo.difference(p.dateFrom).inSeconds / 60,
      start: p.dateFrom,
      end: p.dateTo,
      sourceApp: app,
      sourceDevice: device,
      isSleepSession: p.type == HealthDataType.SLEEP_SESSION,
    );
  }

  if (p.type == HealthDataType.WORKOUT) {
    return WearableSample(
      metric: WearableMetric.exerciseMinutes,
      value: p.dateTo.difference(p.dateFrom).inSeconds / 60,
      start: p.dateFrom,
      end: p.dateTo,
      sourceApp: app,
      sourceDevice: device,
    );
  }

  final metric = _numericTypes[p.type];
  final v = p.value;
  if (metric == null || v is! NumericHealthValue) return null;
  var value = v.numericValue.toDouble();
  // Apple Health reports oxygen saturation as a fraction (0.97).
  if (metric == WearableMetric.spo2 && value > 0 && value <= 1.0) value *= 100;
  return WearableSample(
    metric: metric,
    value: value,
    start: p.dateFrom,
    end: p.dateTo,
    sourceApp: app,
    sourceDevice: device,
  );
}

/// Coarse device class from what the platform tells us about the source.
WearableDeviceClass wearableDeviceClassFor({
  required String sourceId,
  String? sourceName,
  String? deviceModel,
}) {
  final model = (deviceModel ?? '').toLowerCase();
  if (model.contains('watch')) return WearableDeviceClass.watch;
  if (model.contains('iphone') || model.contains('phone')) {
    return WearableDeviceClass.phone;
  }

  final id = sourceId.toLowerCase();
  final name = (sourceName ?? '').toLowerCase();
  bool any(List<String> words) =>
      words.any((w) => id.contains(w) || name.contains(w));
  if (any(['oura', 'ultrahuman', 'ringconn'])) return WearableDeviceClass.ring;
  if (any(['withings', 'renpho', 'eufylife', 'scale', 'qardio', 'omron'])) {
    return WearableDeviceClass.scale;
  }
  if (any([
    'watch',
    'fitbit',
    'garmin',
    'whoop',
    'polar',
    'coros',
    'suunto',
    'wearos',
    'wearable'
  ])) {
    return WearableDeviceClass.watch;
  }
  if (any(['iphone'])) return WearableDeviceClass.phone;
  return WearableDeviceClass.other;
}
