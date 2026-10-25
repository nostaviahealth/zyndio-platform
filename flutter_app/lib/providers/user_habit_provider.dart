import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_habit_service.dart';

/// Riverpod provider that exposes the user's behavioral profile.
/// 
/// Rebuilds whenever a new habit event is recorded (via `refresh()`).
/// Provides `UserHabitProfile` for AI prompting and notification scheduling.
class UserHabitNotifier extends AsyncNotifier<UserHabitProfile> {
  @override
  Future<UserHabitProfile> build() async {
    return await UserHabitService.generateProfile();
  }

  /// Call this after recording a new habit event to regenerate the profile.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => UserHabitService.generateProfile());
  }

  /// Convenience: record a meal event and refresh the profile.
  Future<void> recordMeal(MealType meal) async {
    await UserHabitService.recordMealEvent(meal, DateTime.now());
    // Don't await full refresh — let it happen async
    refresh();
  }

  /// Convenience: record a workout and refresh.
  Future<void> recordWorkout(int durationMinutes) async {
    await UserHabitService.recordWorkoutEvent(DateTime.now(), durationMinutes);
    refresh();
  }

  /// Convenience: record sleep and refresh.
  Future<void> recordSleep(DateTime bedtime, DateTime wakeTime, double hours) async {
    await UserHabitService.recordSleepEvent(bedtime, wakeTime, hours);
    refresh();
  }

  /// Convenience: record task completion.
  Future<void> recordTaskCompletion(String category, bool completed) async {
    await UserHabitService.recordTaskCompletionEvent(category, DateTime.now(), completed);
    // Don't refresh on every toggle — too frequent. Batch at end of day.
  }

  /// Record app open (for chronotype).
  Future<void> recordAppOpen() async {
    await UserHabitService.recordAppOpenEvent(DateTime.now());
  }
}

final userHabitProvider = AsyncNotifierProvider<UserHabitNotifier, UserHabitProfile>(() {
  return UserHabitNotifier();
});

/// Synchronous convenience accessor — returns null if not yet loaded.
final userHabitProfileProvider = Provider<UserHabitProfile?>((ref) {
  return ref.watch(userHabitProvider).value;
});
