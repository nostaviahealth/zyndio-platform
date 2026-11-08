/// APP-07: the daily wearable metrics the app uploads to `wearable_daily`.
///
/// [wireName], [unit] and the plausibility limits mirror the table's CHECK
/// constraints (supabase/migrations/20261105120000_app07_wearable_daily.sql).
/// A row the server would refuse fails its whole upload batch, so the app
/// drops implausible values before sending.
enum WearableAggregation {
  /// Added up over the day (within one source only).
  sum,

  /// Mean of the day's readings.
  mean,

  /// The day's last reading.
  last,

  /// One value per night, filed under the wake date.
  sleep,
}

enum WearableMetric {
  steps('steps', 'count', WearableAggregation.sum, 0, 200000, 0),
  exerciseMinutes(
      'exercise_minutes', 'min', WearableAggregation.sum, 0, 1440, 0),
  activeEnergyKcal(
      'active_energy_kcal', 'kcal', WearableAggregation.sum, 0, 20000, 0),
  restingHr('resting_hr', 'bpm', WearableAggregation.mean, 20, 250, 1),
  // Apple Health reports SDNN, Health Connect reports RMSSD. They are
  // different measures and are never merged.
  hrvSdnn('hrv_sdnn', 'ms', WearableAggregation.mean, 1, 500, 1),
  hrvRmssd('hrv_rmssd', 'ms', WearableAggregation.mean, 1, 500, 1),
  sleepMinutes('sleep_minutes', 'min', WearableAggregation.sleep, 0, 1440, 0),
  weightKg('weight_kg', 'kg', WearableAggregation.last, 20, 500, 2),
  bmi('bmi', 'kg/m2', WearableAggregation.last, 8, 150, 1),
  bpSystolic('bp_systolic', 'mmHg', WearableAggregation.mean, 50, 300, 0),
  bpDiastolic('bp_diastolic', 'mmHg', WearableAggregation.mean, 20, 200, 0),
  vo2max('vo2max', 'mL/kg/min', WearableAggregation.last, 5, 100, 1),
  spo2('spo2', '%', WearableAggregation.mean, 50, 100, 1);

  const WearableMetric(
    this.wireName,
    this.unit,
    this.aggregation,
    this.min,
    this.max,
    this.decimals,
  );

  final String wireName;
  final String unit;
  final WearableAggregation aggregation;
  final double min;
  final double max;

  /// Decimal places the daily value is rounded to.
  final int decimals;

  bool isPlausible(double value) =>
      value.isFinite && value >= min && value <= max;
}
