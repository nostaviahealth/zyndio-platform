import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_rhythm.dart';
import 'patient_provider.dart';
import 'rhythm_provider.dart';

class DayCompletion {
  final DateTime date;
  final double rate; // 0.0 to 1.0
  final bool hasData;

  DayCompletion({required this.date, this.rate = 0.0, this.hasData = false});
}

class ConsistencyData {
  final int streakDays;
  final double weekConsistency; // 0.0 to 1.0
  final bool isLoaded;
  final List<DayCompletion> weekHistory; // Last 7 days

  ConsistencyData({
    this.streakDays = 0,
    this.weekConsistency = 0.0,
    this.isLoaded = false,
    this.weekHistory = const [],
  });
}

class ConsistencyNotifier extends Notifier<ConsistencyData> {
  static const String _storageKeyPrefix = 'daily_rhythm_v2_';
  String? _profileId;
  
  @override
  ConsistencyData build() {
    final profile = ref.watch(patientProfileProvider).value;
    final newId = profile?.id ?? 'guest';
    
    if (newId != _profileId && newId != 'transient') {
      _profileId = newId;
      // Decouple initialization from build to prevent circular dependency
      Future.microtask(() => _calculateConsistency());
    }
    
    _profileId = newId;
    return ConsistencyData(isLoaded: false);
  }
  
  Future<void> _calculateConsistency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int streak = 0;
      int graceDaysUsed = 0;
      int completedTasks7Days = 0;
      int totalTasks7Days = 0;
      final List<DayCompletion> history = [];
      
      final today = DateTime.now();
      
      // Build 7-day history + calculate streak (up to 30 days)
      for (int i = 0; i < 30; i++) {
        final date = today.subtract(Duration(days: i));
        final key = "$_storageKeyPrefix${_profileId}_${date.year}-${date.month}-${date.day}";
        
        final jsonStr = prefs.getString(key);
        double completionRate = 0.0;
        bool hasData = false;
        
        if (jsonStr != null) {
          try {
            final rhythm = DailyRhythm.fromJson(jsonDecode(jsonStr));
            final completed = rhythm.tasks.where((t) => t.isCompleted).length;
            final total = rhythm.tasks.length;
            hasData = total > 0;
            completionRate = total > 0 ? completed / total : 0.0;
            
            if (i < 7) {
              completedTasks7Days += completed;
              totalTasks7Days += total;
            }
          } catch (_) {}
        }
        
        // Add to 7-day history
        if (i < 7) {
          history.add(DayCompletion(date: date, rate: completionRate, hasData: hasData));
        }
        
        // Streak logic with grace days
        if (i == 0) {
          // Today doesn't break the streak - it's still in progress
          if (hasData && completionRate >= 0.5) {
            streak++;
          }
        } else {
          if (hasData && completionRate >= 0.5) {
            streak++;
          } else if (!hasData) {
            // No data = app wasn't opened. Use a grace day if available.
            if (graceDaysUsed < 1) {
              graceDaysUsed++;
              // Don't increment streak, but don't break it either
            } else {
              break; // Streak broken
            }
          } else {
            // Below 50% completion
            if (graceDaysUsed < 1) {
              graceDaysUsed++;
              // Grace: don't break the streak
            } else {
              break; // Streak broken
            }
          }
        }
      }
      
      double consistency = 0.0;
      if (totalTasks7Days > 0) {
        consistency = completedTasks7Days / totalTasks7Days;
      }
      
      state = ConsistencyData(
        streakDays: streak,
        weekConsistency: consistency,
        isLoaded: true,
        weekHistory: history,
      );
    } catch (_) {}
  }
  
  void refresh() {
    _calculateConsistency();
  }
}

final consistencyProvider = NotifierProvider<ConsistencyNotifier, ConsistencyData>(() {
  return ConsistencyNotifier();
});
