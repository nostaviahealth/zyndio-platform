import 'package:flutter/services.dart';
import 'providers.dart';
import 'cloud_service.dart';
import 'health_service.dart';
import 'models/connection.dart';
import 'models/sleep_session.dart';
import 'models/heart_rate_sample.dart';
import 'models/hrv_reading.dart';
import 'models/spo2_reading.dart';
import 'models/activity_summary.dart';
import 'models/workout_session.dart';
import 'models/body_measurement.dart';
import 'models/glucose_reading.dart';

class Zyndio {
  static Zyndio? _instance;
  late final CloudService _cloudService;
  late final HealthService _healthService;
  static const _channel = MethodChannel('platform_wearables');

  Zyndio._({
    required String apiKey,
    required String userId,
    String? baseUrl,
  }) {
    _cloudService =
        CloudService(apiKey: apiKey, userId: userId, baseUrl: baseUrl);
    _healthService = HealthService();
  }

  static Future<void> init({
    required String apiKey,
    required String userId,
    String? baseUrl,
  }) async {
    _instance = Zyndio._(apiKey: apiKey, userId: userId, baseUrl: baseUrl);
  }

  static Zyndio get _i {
    if (_instance == null) {
      throw Exception(
          'Zyndio has not been initialized. Call Zyndio.init() first.');
    }
    return _instance!;
  }

  static Future<void> connect(BrandProvider provider,
      {String? redirectUri}) async {
    if (provider.type == ProviderType.onDevice) {
      await _i._healthService.requestPermissions();
    } else {
      if (redirectUri == null)
        throw Exception('redirectUri is required for cloud providers');
      final authUrl =
          await _i._cloudService.getConnectUrl(provider, redirectUri);
      await _channel.invokeMethod('startOAuthFlow', {
        'authUrl': authUrl,
        'callbackScheme': Uri.parse(redirectUri).scheme,
      });
    }
  }

  static Future<void> disconnect(BrandProvider provider) async {
    if (provider.type == ProviderType.cloud) {
      await _i._cloudService.disconnect(provider);
    }
  }

  static Future<List<BrandConnection>> getConnections() async {
    return await _i._cloudService.getConnections();
  }

  static Future<List<SleepSession>> getSleep(
      {required DateTime startDate,
      required DateTime endDate,
      bool includeAllSources = false}) async {
    final localData =
        await _i._healthService.getSleepSessions(startDate, endDate);
    final cloudData = await _i._cloudService.getSleep(startDate, endDate);
    return [...localData, ...cloudData]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  static Future<List<HeartRateSample>> getHeartRate(
      {required DateTime startDate, required DateTime endDate}) async {
    final localData = await _i._healthService.getHeartRate(startDate, endDate);
    final cloudData = await _i._cloudService.getHeartRate(startDate, endDate);
    return [...localData, ...cloudData]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Future<List<HrvReading>> getHRV(
      {required DateTime startDate, required DateTime endDate}) async {
    final localData = await _i._healthService.getHRV(startDate, endDate);
    final cloudData = await _i._cloudService.getHRV(startDate, endDate);
    return [...localData, ...cloudData]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Future<List<SpO2Reading>> getSpO2(
      {required DateTime startDate, required DateTime endDate}) async {
    final localData = await _i._healthService.getSpO2(startDate, endDate);
    final cloudData = await _i._cloudService.getSpO2(startDate, endDate);
    return [...localData, ...cloudData]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Future<List<ActivitySummary>> getActivity(
      {required DateTime startDate, required DateTime endDate}) async {
    final localData = await _i._healthService.getActivity(startDate, endDate);
    final cloudData = await _i._cloudService.getActivity(startDate, endDate);
    return [...localData, ...cloudData]
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  static Future<List<WorkoutSession>> getWorkouts(
      {required DateTime startDate, required DateTime endDate}) async {
    final localData = await _i._healthService.getWorkouts(startDate, endDate);
    final cloudData = await _i._cloudService.getWorkouts(startDate, endDate);
    return [...localData, ...cloudData]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  static Future<List<BodyMeasurement>> getBodyMeasurements(
      {required DateTime startDate, required DateTime endDate}) async {
    final localData =
        await _i._healthService.getBodyMeasurements(startDate, endDate);
    final cloudData = await _i._cloudService.getBody(startDate, endDate);
    return [...localData, ...cloudData]
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  }

  static Future<List<GlucoseReading>> getGlucose(
      {required DateTime startDate, required DateTime endDate}) async {
    final localData = await _i._healthService.getGlucose(startDate, endDate);
    final cloudData = await _i._cloudService.getGlucose(startDate, endDate);
    return [...localData, ...cloudData]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}
