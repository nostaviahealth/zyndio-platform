import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import 'notification_scheduler.dart';
import 'proactive_intelligence_service.dart';

class MealWatchdogSession {
  final String mealLogId;
  final DateTime mealTime;
  final String foodName;
  final int foodScore;
  final String predictedEnergyCurve;
  
  final int baselineHR;
  final double? baselineHRV;
  
  MealWatchdogSession({
    required this.mealLogId,
    required this.mealTime,
    required this.foodName,
    required this.foodScore,
    required this.predictedEnergyCurve,
    required this.baselineHR,
    this.baselineHRV,
  });

  Map<String, dynamic> toJson() => {
    'mealLogId': mealLogId,
    'mealTime': mealTime.toIso8601String(),
    'foodName': foodName,
    'foodScore': foodScore,
    'predictedEnergyCurve': predictedEnergyCurve,
    'baselineHR': baselineHR,
    'baselineHRV': baselineHRV,
  };

  factory MealWatchdogSession.fromJson(Map<String, dynamic> json) => MealWatchdogSession(
    mealLogId: json['mealLogId'],
    mealTime: DateTime.parse(json['mealTime']),
    foodName: json['foodName'],
    foodScore: json['foodScore'],
    predictedEnergyCurve: json['predictedEnergyCurve'],
    baselineHR: json['baselineHR'],
    baselineHRV: json['baselineHRV'],
  );
}

class MealWatchdogService {
  static const String _prefsKey = 'pending_meal_watchdog';

  /// Call immediately after food scan completes.
  static Future<void> startWatching({
    required String mealLogId,
    required String foodName,
    required int foodScore,
    required String predictedEnergyCurve,
    required int baselineHR,
    double? baselineHRV,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final session = MealWatchdogSession(
      mealLogId: mealLogId,
      mealTime: DateTime.now(),
      foodName: foodName,
      foodScore: foodScore,
      predictedEnergyCurve: predictedEnergyCurve,
      baselineHR: baselineHR,
      baselineHRV: baselineHRV,
    );

    await prefs.setString(_prefsKey, jsonEncode(session.toJson()));
    debugPrint('⌚️ MealWatchdog started for $foodName. Will check in 90+ minutes.');
  }

  /// Called during Wearable Sync to check if we have a pending validation.
  static Future<void> checkPendingSessions({
    required int currentHR,
    required double? currentHRV,
    required NotificationScheduler scheduler,
    String? firstName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStr = prefs.getString(_prefsKey);
    
    if (sessionStr == null) return;
    
    try {
      final session = MealWatchdogSession.fromJson(jsonDecode(sessionStr));
      final now = DateTime.now();
      final minutesSinceMeal = now.difference(session.mealTime).inMinutes;

      // Ensure at least 90 minutes have passed, but not more than 4 hours (240 min)
      if (minutesSinceMeal < 90) return;
      
      if (minutesSinceMeal > 240) {
        // Too late, discard session
        await prefs.remove(_prefsKey);
        return;
      }

      // ── VALIDATION LOGIC ──
      final hrDelta = currentHR - session.baselineHR;
      String validationVerdict = 'inconclusive';
      String insightText = '';

      final isSpikePredicted = session.predictedEnergyCurve.toLowerCase().contains('spike');
      final isCrashPredicted = session.predictedEnergyCurve.toLowerCase().contains('crash');
      
      if (isSpikePredicted || isCrashPredicted) {
        if (hrDelta >= 8) {
          validationVerdict = 'confirmed';
          insightText = 'That ${session.foodName} spiked your HR by $hrDelta bpm — exactly as the AI predicted for a high-GI meal.';
        } else {
          validationVerdict = 'refuted';
          insightText = 'Interesting. Your body handled the ${session.foodName} better than expected. HR stayed stable despite the high-GI prediction.';
        }
      } else {
        // Stable energy predicted
        if (hrDelta <= 5 && hrDelta >= -5) {
          validationVerdict = 'confirmed';
          insightText = 'The ${session.foodName} provided stable energy as predicted. Your heart rate baseline barely shifted.';
        } else if (hrDelta >= 10) {
          validationVerdict = 'refuted';
          insightText = 'The ${session.foodName} caused an unexpected HR spike of $hrDelta bpm. You may be sensitive to an ingredient in it.';
        } else {
          validationVerdict = 'inconclusive';
        }
      }

      // If conclusive, push notification and save
      if (validationVerdict != 'inconclusive' && insightText.isNotEmpty) {
        // Fire Notification
        final convo = ProactiveConversation(
          title: 'Metabolic Validation',
          body: insightText,
        );
        await scheduler.fireConversationStarter(convo);

        // Persist to Supabase
        await _saveValidationResult(
          mealLogId: session.mealLogId,
          verdict: validationVerdict,
          insight: insightText,
          hrDelta: hrDelta,
          hrvDelta: currentHRV != null && session.baselineHRV != null ? currentHRV - session.baselineHRV! : null,
        );
      }

      // Clear the session
      await prefs.remove(_prefsKey);
      debugPrint('⌚️ MealWatchdog completed validation: $validationVerdict');

    } catch (e) {
      debugPrint('Error in MealWatchdog: $e');
      await prefs.remove(_prefsKey);
    }
  }

  static Future<void> _saveValidationResult({
    required String mealLogId,
    required String verdict,
    required String insight,
    required int hrDelta,
    double? hrvDelta,
  }) async {
    final client = SupabaseConfig.client;
    final userId = SupabaseConfig.currentUser?.id;
    if (client == null || userId == null || mealLogId.isEmpty) return;

    try {
      final payload = {
        'validation_verdict': verdict,
        'validation_insight': insight,
        'validation_hr_delta': hrDelta,
        if (hrvDelta != null) 'validation_hrv_delta': hrvDelta,
        'validation_checked_at': DateTime.now().toIso8601String(),
      };

      await client.from('food_logs').update(payload).eq('image_path', mealLogId);
    } catch (e) {
      debugPrint('MealWatchdog save error: $e');
    }
  }
}
