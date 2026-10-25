import 'package:flutter/services.dart';
import 'models/sleep_session.dart';
import 'models/heart_rate_sample.dart';
import 'models/hrv_reading.dart';
import 'models/spo2_reading.dart';
import 'models/activity_summary.dart';
import 'models/workout_session.dart';
import 'models/body_measurement.dart';
import 'models/glucose_reading.dart';

class HealthService {
  static const _channel = MethodChannel('platform_wearables');

  Future<bool> requestPermissions() async {
    final result =
        await _channel.invokeMethod<bool>('requestHealthPermissions');
    return result ?? false;
  }

  Future<List<SleepSession>> getSleepSessions(
      DateTime start, DateTime end) async {
    final result = await _channel
        .invokeListMethod<Map<dynamic, dynamic>>('getSleepSessions', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return result
            ?.map((m) => SleepSession.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }

  Future<List<HeartRateSample>> getHeartRate(
      DateTime start, DateTime end) async {
    final result =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>('getHeartRate', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return result
            ?.map((m) => HeartRateSample.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }

  Future<List<HrvReading>> getHRV(DateTime start, DateTime end) async {
    final result =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>('getHRV', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return result
            ?.map((m) => HrvReading.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }

  Future<List<SpO2Reading>> getSpO2(DateTime start, DateTime end) async {
    final result =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>('getSpO2', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return result
            ?.map((m) => SpO2Reading.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }

  Future<List<ActivitySummary>> getActivity(
      DateTime start, DateTime end) async {
    final result =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>('getActivity', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return result
            ?.map((m) => ActivitySummary.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }

  Future<List<WorkoutSession>> getWorkouts(DateTime start, DateTime end) async {
    final result =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>('getWorkouts', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return result
            ?.map((m) => WorkoutSession.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }

  Future<List<BodyMeasurement>> getBodyMeasurements(
      DateTime start, DateTime end) async {
    final result = await _channel
        .invokeListMethod<Map<dynamic, dynamic>>('getBodyMeasurements', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return result
            ?.map((m) => BodyMeasurement.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }

  Future<List<GlucoseReading>> getGlucose(DateTime start, DateTime end) async {
    final result =
        await _channel.invokeListMethod<Map<dynamic, dynamic>>('getGlucose', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return result
            ?.map((m) => GlucoseReading.fromMap(Map<String, dynamic>.from(m)))
            .toList() ??
        [];
  }
}
