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

class CloudService {
  final String _apiKey;
  final String _userId;
  final String _baseUrl;

  CloudService({
    required String apiKey,
    required String userId,
    String? baseUrl,
  })  : _apiKey = apiKey,
        _userId = userId,
        _baseUrl = baseUrl ?? 'https://api.zyndio.example/v1';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
        'x-user-id': _userId,
        'Content-Type': 'application/json',
      };

  Future<String> getConnectUrl(
      BrandProvider provider, String redirectUri) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/connect'),
      headers: _headers,
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
    final response = await http.post(
      Uri.parse('$_baseUrl/disconnect'),
      headers: _headers,
      body: jsonEncode({'provider': provider.name}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to disconnect: ${response.body}');
    }
  }

  Future<List<BrandConnection>> getConnections() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/connections'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['connections'];
      return data.map((e) => BrandConnection.fromMap(e)).toList();
    }
    throw Exception('Failed to get connections: ${response.body}');
  }

  Future<List<SleepSession>> getSleep(DateTime start, DateTime end) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/data/sleep?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => SleepSession.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<HeartRateSample>> getHeartRate(
      DateTime start, DateTime end) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/data/heart_rate?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => HeartRateSample.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<HrvReading>> getHRV(DateTime start, DateTime end) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/data/hrv?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => HrvReading.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<SpO2Reading>> getSpO2(DateTime start, DateTime end) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/data/spo2?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => SpO2Reading.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<ActivitySummary>> getActivity(
      DateTime start, DateTime end) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/data/activity?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => ActivitySummary.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<WorkoutSession>> getWorkouts(DateTime start, DateTime end) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/data/workouts?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => WorkoutSession.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<BodyMeasurement>> getBody(DateTime start, DateTime end) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/data/body?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => BodyMeasurement.fromMap(e)).toList();
    }
    return [];
  }

  Future<List<GlucoseReading>> getGlucose(DateTime start, DateTime end) async {
    final response = await http.get(
      Uri.parse(
          '$_baseUrl/data/glucose?start_date=${start.toIso8601String()}&end_date=${end.toIso8601String()}'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)['data'];
      return data.map((e) => GlucoseReading.fromMap(e)).toList();
    }
    return [];
  }
}
