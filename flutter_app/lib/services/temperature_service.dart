import 'package:flutter/services.dart';

/// Service to read Temperature data from Apple HealthKit via native channel.
/// Automatically handles iOS 16+ appleSleepingWristTemperature deviations vs absolute bodyTemperature.
class TemperatureService {
  static const _channel = MethodChannel('com.zyndio/temperature');

  /// Request permission to read Temperature data from HealthKit.
  static Future<bool> requestPermission() async {
    try {
      final permResult = await _channel.invokeMethod<bool>('requestPermission');
      return permResult ?? false;
    } catch (e) {
      print('Temperature permission error: $e');
      return false;
    }
  }

  /// Get Temperature history for the last [days] days.
  /// Returns a list of maps, each with 'value' (double, in Celsius), 'date' (DateTime), 'source'.
  /// The native side handles converting wrist deviation to absolute if needed.
  static Future<List<Map<String, dynamic>>> getTemperatureHistory({int days = 30, DateTime? endTime}) async {
    try {
      // If endTime is in the past, we need to fetch more days to cover the gap from now back to (endTime - days)
      int effectiveDays = days;
      if (endTime != null) {
        final gap = DateTime.now().difference(endTime).inDays;
        if (gap > 0) {
          effectiveDays += gap;
        }
      }

      final historyResult = await _channel.invokeMethod<List<dynamic>>(
        'getTemperatureHistory',
        {'days': effectiveDays},
      );
      if (historyResult == null) return [];
      
      final parsed = historyResult.map((item) {
        final map = item as Map<dynamic, dynamic>;
        return {
          'value': (map['value'] as num).toDouble(),
          'date': DateTime.parse(map['date'] as String),
          'source': map['source'] as String? ?? 'Unknown',
        };
      }).toList();

      // If we fetched extra days, filter back to the requested window relative to endTime
      if (endTime != null) {
        final start = endTime.subtract(Duration(days: days));
        return parsed.where((d) {
          final date = d['date'] as DateTime;
          return date.isAfter(start) && (date.isBefore(endTime) || date.isAtSameMomentAs(endTime));
        }).toList();
      }

      return parsed;
    } catch (e) {
      print('Temperature history error: $e');
      return [];
    }
  }

  /// Helper to get the single latest temperature value inside a date range
  static Future<double?> getLatestTemperature(DateTime start, DateTime end) async {
    final days = DateTime.now().difference(start).inDays + 1;
    final history = await getTemperatureHistory(days: days, endTime: end);
    
    // Filter history to fit within start and end
    final filtered = history.where((d) {
      final date = d['date'] as DateTime;
      return (date.isAfter(start) || date.isAtSameMomentAs(start)) && 
             (date.isBefore(end) || date.isAtSameMomentAs(end));
    }).toList();
    
    if (filtered.isNotEmpty) {
      // Return the most recent one (history is retrieved ascending, so last is newest)
      return filtered.last['value'] as double;
    }
    return null;
  }
}
