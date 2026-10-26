import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wearable_sync_provider.dart';
import '../providers/rhythm_provider.dart';
import '../providers/patient_provider.dart';
import '../data/meal_repository.dart';

class WatchService {
  static const MethodChannel _syncChannel = MethodChannel('com.zyndio/watch_sync');
  static const MethodChannel _actionChannel = MethodChannel('com.zyndio/watch_actions');
  
  static bool _isInitialized = false;

  /// Initializes the listener for incoming watch actions (e.g., Log Water).
  /// Should be called once at app startup.
  static void initialize(WidgetRef ref) {
    if (_isInitialized) return;
    _isInitialized = true;

    _actionChannel.setMethodCallHandler((call) async {
      if (call.method == 'handleAction') {
        final action = call.arguments['action'] as String?;
        debugPrint('⌚️ Watch Action Received: $action');
        
        if (action == 'log_water') {
          await _handleLogWater(ref);
        } else if (action == 'log_coffee') {
          await _handleLogCoffee(ref);
        }
      }
    });
    
    debugPrint('✅ Watch Action Bridge Initialized');
  }

  static Future<void> _handleLogWater(WidgetRef ref) async {
    final profileId = ref.read(patientProfileProvider).value?.id;
    if (profileId == null) return;

    // 1. Log to Database
    await MealRepository.logFood(profileId, {
      'food_name': 'Water',
      'calories': 0,
      'protein': 0,
      'fat': 0,
      'carbs': 0,
    });

    // 2. Auto-complete relevant task in Daily Rhythm
    await ref.read(dailyRhythmProvider.notifier).autoCompleteRelevantTask('diet');
    
    debugPrint('💧 Water logged via Apple Watch');
  }

  static Future<void> _handleLogCoffee(WidgetRef ref) async {
    final profileId = ref.read(patientProfileProvider).value?.id;
    if (profileId == null) return;

    // 1. Log to Database
    await MealRepository.logFood(profileId, {
      'food_name': 'Coffee',
      'calories': 2,
      'protein': 0,
      'fat': 0,
      'carbs': 0,
    });

    // 2. Auto-complete relevant task in Daily Rhythm
    await ref.read(dailyRhythmProvider.notifier).autoCompleteRelevantTask('diet');

    debugPrint('☕️ Coffee logged via Apple Watch');
  }

  static Future<void> syncStateToWatch(WearableSyncState state) async {
    if (!Platform.isIOS) return;
    if (state.snapshot == null) return;
    
    try {
      final snapshot = state.snapshot!;
      
      final metrics = {
        'longevityScore': snapshot.energyScore,
        'recoveryScore': snapshot.recoveryScore,
        'stressScore': snapshot.stressScore,
        'sleepScore': snapshot.sleepScore,
        'energyScore': snapshot.energyScore,
        'hrv': snapshot.hrv,
        'rhr': snapshot.rhr,
        'steps': snapshot.steps,
        'lastUpdated': DateTime.now().toIso8601String(),
      };
      
      await _syncChannel.invokeMethod('syncMetrics', metrics);
      debugPrint('✅ Watch Sync Successful');
    } catch (e) {
      debugPrint('❌ Watch Sync Failed: $e');
    }
  }
}
