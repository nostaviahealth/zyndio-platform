import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NutritionGoals {
  final double calorieGoal;
  final double proteinGoal;
  final double carbGoal;
  final double fatGoal;
  final double fiberGoal;

  const NutritionGoals({
    this.calorieGoal = 2000,
    this.proteinGoal = 150,
    this.carbGoal = 200,
    this.fatGoal = 70,
    this.fiberGoal = 30,
  });

  NutritionGoals copyWith({
    double? calorieGoal,
    double? proteinGoal,
    double? carbGoal,
    double? fatGoal,
    double? fiberGoal,
  }) {
    return NutritionGoals(
      calorieGoal: calorieGoal ?? this.calorieGoal,
      proteinGoal: proteinGoal ?? this.proteinGoal,
      carbGoal: carbGoal ?? this.carbGoal,
      fatGoal: fatGoal ?? this.fatGoal,
      fiberGoal: fiberGoal ?? this.fiberGoal,
    );
  }
}

class NutritionGoalsNotifier extends Notifier<NutritionGoals> {
  static const String _calorieKey = 'goal_nutrition_kcal';
  static const String _proteinKey = 'goal_nutrition_protein';
  static const String _carbKey = 'goal_nutrition_carb';
  static const String _fatKey = 'goal_nutrition_fat';

  @override
  NutritionGoals build() {
    _loadGoals();
    return const NutritionGoals();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final cal = prefs.getDouble(_calorieKey);
    final pro = prefs.getDouble(_proteinKey);
    final carb = prefs.getDouble(_carbKey);
    final fat = prefs.getDouble(_fatKey);
    final fiber = prefs.getDouble('goal_nutrition_fiber');

    state = NutritionGoals(
      calorieGoal: cal ?? 2000.0,
      proteinGoal: pro ?? 150.0,
      carbGoal: carb ?? 200.0,
      fatGoal: fat ?? 70.0,
      fiberGoal: fiber ?? 30.0,
    );
  }

  Future<void> updateGoals({double? calories, double? protein, double? carbs, double? fat, double? fiber}) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (calories != null) await prefs.setDouble(_calorieKey, calories);
    if (protein != null) await prefs.setDouble(_proteinKey, protein);
    if (carbs != null) await prefs.setDouble(_carbKey, carbs);
    if (fat != null) await prefs.setDouble(_fatKey, fat);
    if (fiber != null) await prefs.setDouble('goal_nutrition_fiber', fiber);

    state = state.copyWith(
      calorieGoal: calories,
      proteinGoal: protein,
      carbGoal: carbs,
      fatGoal: fat,
      fiberGoal: fiber,
    );
  }
}

final nutritionGoalsProvider = NotifierProvider<NutritionGoalsNotifier, NutritionGoals>(() {
  return NutritionGoalsNotifier();
});
