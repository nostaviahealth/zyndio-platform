import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service to read VO2 Max data from Apple HealthKit via native method channel.
/// Apple stores VO2 Max as "Cardio Fitness" (HKQuantityTypeIdentifierVO2Max).
class Vo2MaxService {
  static const _channel = MethodChannel('com.zyndio/vo2max');

  /// Request permission to read VO2 Max data from HealthKit.
  static Future<bool> requestPermission() async {
    try {
      final permResult = await _channel.invokeMethod<bool>('requestPermission');
      return permResult ?? false;
    } catch (e) {
      print('VO2 Max permission error: $e');
      return false;
    }
  }

  /// Get the most recent VO2 Max value.
  /// Returns a map with 'value' (double), 'date' (ISO8601 string), 'source' (string).
  /// Returns null if no data is available.
  static Future<Map<String, dynamic>?> getVo2Max() async {
    try {
      final fetchResult = await _channel.invokeMethod<Map<dynamic, dynamic>>('getVo2Max');
      if (fetchResult == null) return null;
      return {
        'value': (fetchResult['value'] as num).toDouble(),
        'date': DateTime.parse(fetchResult['date'] as String),
        'source': fetchResult['source'] as String? ?? 'Unknown',
      };
    } catch (e) {
      print('VO2 Max fetch error: $e');
      return null;
    }
  }

  /// Get VO2 Max history for the last [days] days.
  /// Returns a list of maps, each with 'value' (double), 'date' (DateTime).
  static Future<List<Map<String, dynamic>>> getVo2MaxHistory({int days = 30}) async {
    try {
      final historyResult = await _channel.invokeMethod<List<dynamic>>(
        'getVo2MaxHistory',
        {'days': days},
      );
      if (historyResult == null) return [];
      return historyResult.map((item) {
        final map = item as Map<dynamic, dynamic>;
        return {
          'value': (map['value'] as num).toDouble(),
          'date': DateTime.parse(map['date'] as String),
          'source': map['source'] as String? ?? 'Unknown',
        };
      }).toList();
    } catch (e) {
      print('VO2 Max history error: $e');
      return [];
    }
  }

  /// Get the fitness level classification based on VO2 Max value.
  /// Based on ACSM (American College of Sports Medicine) guidelines.
  /// If age and isMale are not provided, it uses a conservative general adult population model.
  static ({String level, double percentile, Color color}) classifyFitness(double vo2Max, {int? age, bool? isMale}) {
    // Default to Male if not specified (conservative for general population)
    final male = isMale ?? true;
    final a = age ?? 30;

    // ACSM Cardio Fitness Classification (VO2 Max)
    // Tiers: Superior (95th), Excellent (80th), Good (60th), Fair (40th), Poor (20th), Very Poor (below)
    
    if (male) {
      if (a < 30) {
        if (vo2Max >= 53.5) return (level: 'Superior', percentile: 95, color: const Color(0xFF10B981));
        if (vo2Max >= 48.9) return (level: 'Excellent', percentile: 80, color: const Color(0xFF3B82F6));
        if (vo2Max >= 43.9) return (level: 'Good', percentile: 60, color: const Color(0xFF22C55E));
        if (vo2Max >= 38.4) return (level: 'Average', percentile: 40, color: const Color(0xFFF59E0B));
        if (vo2Max >= 33.0) return (level: 'Fair', percentile: 20, color: const Color(0xFFF97316));
        return (level: 'Poor', percentile: 10, color: const Color(0xFFEF4444));
      } else if (a < 40) {
        if (vo2Max >= 51.5) return (level: 'Superior', percentile: 95, color: const Color(0xFF10B981));
        if (vo2Max >= 45.9) return (level: 'Excellent', percentile: 80, color: const Color(0xFF3B82F6));
        if (vo2Max >= 41.0) return (level: 'Good', percentile: 60, color: const Color(0xFF22C55E));
        if (vo2Max >= 35.5) return (level: 'Average', percentile: 40, color: const Color(0xFFF59E0B));
        if (vo2Max >= 31.5) return (level: 'Fair', percentile: 20, color: const Color(0xFFF97316));
        return (level: 'Poor', percentile: 10, color: const Color(0xFFEF4444));
      } else if (a < 50) {
        if (vo2Max >= 48.5) return (level: 'Superior', percentile: 95, color: const Color(0xFF10B981));
        if (vo2Max >= 43.9) return (level: 'Excellent', percentile: 80, color: const Color(0xFF3B82F6));
        if (vo2Max >= 39.0) return (level: 'Good', percentile: 60, color: const Color(0xFF22C55E));
        if (vo2Max >= 33.6) return (level: 'Average', percentile: 40, color: const Color(0xFFF59E0B));
        if (vo2Max >= 30.2) return (level: 'Fair', percentile: 20, color: const Color(0xFFF97316));
        return (level: 'Poor', percentile: 10, color: const Color(0xFFEF4444));
      } else {
        if (vo2Max >= 45.5) return (level: 'Superior', percentile: 95, color: const Color(0xFF10B981));
        if (vo2Max >= 41.0) return (level: 'Excellent', percentile: 80, color: const Color(0xFF3B82F6));
        if (vo2Max >= 35.8) return (level: 'Good', percentile: 60, color: const Color(0xFF22C55E));
        if (vo2Max >= 31.0) return (level: 'Average', percentile: 40, color: const Color(0xFFF59E0B));
        if (vo2Max >= 26.1) return (level: 'Fair', percentile: 20, color: const Color(0xFFF97316));
        return (level: 'Poor', percentile: 10, color: const Color(0xFFEF4444));
      }
    } else {
      // Female
      if (a < 30) {
        if (vo2Max >= 41.0) return (level: 'Superior', percentile: 95, color: const Color(0xFF10B981));
        if (vo2Max >= 37.0) return (level: 'Excellent', percentile: 80, color: const Color(0xFF3B82F6));
        if (vo2Max >= 33.0) return (level: 'Good', percentile: 60, color: const Color(0xFF22C55E));
        if (vo2Max >= 29.0) return (level: 'Average', percentile: 40, color: const Color(0xFFF59E0B));
        if (vo2Max >= 23.6) return (level: 'Fair', percentile: 20, color: const Color(0xFFF97316));
        return (level: 'Poor', percentile: 10, color: const Color(0xFFEF4444));
      } else if (a < 40) {
        if (vo2Max >= 40.0) return (level: 'Superior', percentile: 95, color: const Color(0xFF10B981));
        if (vo2Max >= 35.7) return (level: 'Excellent', percentile: 80, color: const Color(0xFF3B82F6));
        if (vo2Max >= 31.5) return (level: 'Good', percentile: 60, color: const Color(0xFF22C55E));
        if (vo2Max >= 27.0) return (level: 'Average', percentile: 40, color: const Color(0xFFF59E0B));
        if (vo2Max >= 22.8) return (level: 'Fair', percentile: 20, color: const Color(0xFFF97316));
        return (level: 'Poor', percentile: 10, color: const Color(0xFFEF4444));
      } else if (a < 50) {
        if (vo2Max >= 37.0) return (level: 'Superior', percentile: 95, color: const Color(0xFF10B981));
        if (vo2Max >= 32.9) return (level: 'Excellent', percentile: 80, color: const Color(0xFF3B82F6));
        if (vo2Max >= 29.0) return (level: 'Good', percentile: 60, color: const Color(0xFF22C55E));
        if (vo2Max >= 24.5) return (level: 'Average', percentile: 40, color: const Color(0xFFF59E0B));
        if (vo2Max >= 21.0) return (level: 'Fair', percentile: 20, color: const Color(0xFFF97316));
        return (level: 'Poor', percentile: 10, color: const Color(0xFFEF4444));
      } else {
        if (vo2Max >= 35.8) return (level: 'Superior', percentile: 95, color: const Color(0xFF10B981));
        if (vo2Max >= 31.5) return (level: 'Excellent', percentile: 80, color: const Color(0xFF3B82F6));
        if (vo2Max >= 27.0) return (level: 'Good', percentile: 60, color: const Color(0xFF22C55E));
        if (vo2Max >= 22.8) return (level: 'Average', percentile: 40, color: const Color(0xFFF59E0B));
        if (vo2Max >= 19.1) return (level: 'Fair', percentile: 20, color: const Color(0xFFF97316));
        return (level: 'Poor', percentile: 10, color: const Color(0xFFEF4444));
      }
    }
  }
}
