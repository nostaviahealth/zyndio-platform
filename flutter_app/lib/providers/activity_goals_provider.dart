import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActivityGoals {
  final double moveGoal;
  final int exerciseGoal;
  final int stepsGoal;

  const ActivityGoals({
    this.moveGoal = 500,
    this.exerciseGoal = 30,
    this.stepsGoal = 10000,
  });

  ActivityGoals copyWith({
    double? moveGoal,
    int? exerciseGoal,
    int? stepsGoal,
  }) {
    return ActivityGoals(
      moveGoal: moveGoal ?? this.moveGoal,
      exerciseGoal: exerciseGoal ?? this.exerciseGoal,
      stepsGoal: stepsGoal ?? this.stepsGoal,
    );
  }
}

class ActivityGoalsNotifier extends Notifier<ActivityGoals> {
  static const String _moveKey = 'goal_move_kcal';
  static const String _exerciseKey = 'goal_exercise_min';
  static const String _stepsKey = 'goal_steps';

  @override
  ActivityGoals build() {
    _loadGoals();
    return const ActivityGoals();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final move = prefs.getDouble(_moveKey);
    final exercise = prefs.getInt(_exerciseKey);
    final steps = prefs.getInt(_stepsKey);

    state = ActivityGoals(
      moveGoal: move ?? 500,
      exerciseGoal: exercise ?? 30,
      stepsGoal: steps ?? 10000,
    );
  }

  Future<void> updateGoals({double? move, int? exercise, int? steps}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (move != null) await prefs.setDouble(_moveKey, move);
    if (exercise != null) await prefs.setInt(_exerciseKey, exercise);
    if (steps != null) await prefs.setInt(_stepsKey, steps);

    state = state.copyWith(
      moveGoal: move,
      exerciseGoal: exercise,
      stepsGoal: steps,
    );
  }
}

final activityGoalsProvider = NotifierProvider<ActivityGoalsNotifier, ActivityGoals>(() {
  return ActivityGoalsNotifier();
});
