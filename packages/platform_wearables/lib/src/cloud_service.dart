import 'dart:convert';
import 'package:http/http.dart' as http;
import 'providers.dart';
import 'models/connection.dart';
import 'models/sleep_session.dart';
import 'models/heart_rate_sample.dart';
import 'models/hrv_reading.dart';
import 'models/spo2_reading.dart';
import 'models/activity_summary.dart';
import 'models/workout_session.dart';
import 'models/body_measurement.dart';
import 'models/glucose_reading.dart';

/// Returns the signed-in patient's Supabase access token, or null when there is
/// no session.
typedef AccessTokenProvider = Future<String?> Function();

/// Calls the wearables cloud endpoints as the signed-in patient.
///
/// Every request carries the patient's own Supabase session JWT, so the server
/// identifies the caller from a verified token. This replaces a static
/// `WEARABLES_API_KEY` compiled into the app plus an `x-user-id` header the
/// client chose freely - anyone who pulled the key out of the binary could
/// have claimed to be any patient. [apiKey] is now only the public gateway key
/// (the Supabase anon key), never a secret.
class CloudService {
  final String _apiKey;
  final AccessTokenProvider _accessToken;
  final String _baseUrl;
  final http.Client _http;

  CloudService({
    required String apiKey,
    required AccessTokenProvider accessToken,
    String? baseUrl,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _accessToken = accessToken,
        _baseUrl = baseUrl ?? 'https://api.zyndio.example/v1',
        _http = httpClient ?? http.Client();

  /// Throws [StateError] before any network call when nobody is signed in.
  Future<Map<String, String>> _headers() async {
    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Wearables cloud: not signed in');
    }
    return {
      'Authorization': 'Bearer $token',
      'apikey': _apiKey,
      'Content-Type': 'application/json',
    };
  }

  Future<String> getConnectUrl(
      BrandProvider provider, String redirectUri) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/connect'),
      headers: await _headers(),
      body: jsonEncode({
        'provider': provider.name,
        'redirect_uri': redirectUri,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['auth_url'];
    }
    throw Exception('Failed to get connect URL: ${response.body}');
  }

  Future<void> disconnect(BrandProvider provider) async {
    final response = await _http.post(
      Uri.parse('$_baseUrl/disconnect'),
      headers: await _headers(),
      body: jsonEncode({'provider': provider.name}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to disconnect: ${response.body}');
    }
  }

  Future<List<BrandConnection>> getConnections() async {
    final response = await _http.get(
      Uri.parse('$_baseUrl/connections'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['connections'];
      return data.map((e) => BrandConnection.fromMap(e)).toList();
    }
    throw Exception('Failed to get connections: ${response.body}');
  }

  Future<List<SleepSession>> getSleep(DateTime start, DateTime end) async {
    final response = await _http.get(
      Uri.parse(
          '$_baseUrl/data/sleep?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => SleepSession.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<HeartRateSample>> getHeartRate(
      DateTime start, DateTime end) async {
    final response = await _http.get(
      Uri.parse(
          '$_baseUrl/data/heart_rate?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => HeartRateSample.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<HrvReading>> getHRV(DateTime start, DateTime end) async {
    final response = await _http.get(
      Uri.parse(
          '$_baseUrl/data/hrv?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => HrvReading.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<SpO2Reading>> getSpO2(DateTime start, DateTime end) async {
    final response = await _http.get(
      Uri.parse(
          '$_baseUrl/data/spo2?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => SpO2Reading.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<ActivitySummary>> getActivity(
      DateTime start, DateTime end) async {
    final response = await _http.get(
      Uri.parse(
          '$_baseUrl/data/activity?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => ActivitySummary.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<WorkoutSession>> getWorkouts(DateTime start, DateTime end) async {
    final response = await _http.get(
      Uri.parse(
          '$_baseUrl/data/workouts?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => WorkoutSession.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<BodyMeasurement>> getBody(DateTime start, DateTime end) async {
    final response = await _http.get(
      Uri.parse(
          '$_baseUrl/data/body?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => BodyMeasurement.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<GlucoseReading>> getGlucose(DateTime start, DateTime end) async {
    final response = await _http.get(
      Uri.parse(
          '$_baseUrl/data/glucose?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => GlucoseReading.fromMap(e)).toList();
    }
    return [];
  }
}
