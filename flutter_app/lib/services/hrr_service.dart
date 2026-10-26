import 'package:flutter/services.dart';

/// Service to read Heart Rate Recovery data from Apple HealthKit via native channel.
/// HRR measures how quickly heart rate drops after peak exercise.
class HrrService {
  static const _channel = MethodChannel('com.zyndio/hrr');

  /// Request permission to read HRR data from HealthKit.
  static Future<bool> requestPermission() async {
    try {
      final permResult = await _channel.invokeMethod<bool>('requestPermission');
      return permResult ?? false;
    } catch (e) {
      print('HRR permission error: $e');
      return false;
    }
  }

  /// Get the most recent HRR value.
  /// Returns a map with 'value' (double, in bpm drop), 'date', 'source', 'method'.
  /// Returns null if no data available.
  static Future<Map<String, dynamic>?> getHrr() async {
    try {
      final fetchResult = await _channel.invokeMethod<Map<dynamic, dynamic>>('getHrr');
      if (fetchResult == null) return null;
      
      final dateStr = fetchResult['date'] as String?;
      return {
        'value': (fetchResult['value'] as num?)?.toDouble() ?? 0.0,
        'date': dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
        'source': fetchResult['source'] as String? ?? 'Unknown',
        'method': fetchResult['method'] as String? ?? 'unknown',
        if (fetchResult['peakHR'] != null) 'peakHR': (fetchResult['peakHR'] as num).toDouble(),
        if (fetchResult['recoveryHR'] != null) 'recoveryHR': (fetchResult['recoveryHR'] as num).toDouble(),
      };
    } catch (e) {
      print('HRR fetch error: $e');
      return null;
    }
  }

  /// Classify HRR value into a range description.
  /// Good recovery: > 20 bpm drop in 1 min
  /// Normal: 12-20 bpm
  /// Below normal: < 12 bpm
  static String classifyHrr(double hrrBpm) {
    if (hrrBpm >= 20) return 'Good recovery';
    if (hrrBpm >= 12) return 'Normal';
    return 'Below normal';
  }

  /// Get historical HRR values for the last [days] days.
  static Future<List<Map<String, dynamic>>> getHrrHistory({int days = 30}) async {
    try {
      final List<dynamic>? historyResult = await _channel.invokeMethod<List<dynamic>>(
        'getHrrHistory',
        {'days': days},
      );
      if (historyResult == null) return [];
      
      return historyResult.map((item) {
        final map = item as Map<dynamic, dynamic>;
        final dateStr = map['date'] as String?;
        return {
          'value': (map['value'] as num?)?.toDouble() ?? 0.0,
          'date': dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
          'peakHR': (map['peakHR'] as num?)?.toDouble(),
          'recoveryHR': (map['recoveryHR'] as num?)?.toDouble(),
        };
      }).toList();
    } catch (e) {
      print('HRR history fetch error: $e');
      return [];
    }
  }
}
