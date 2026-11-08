import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_plan.dart';

class MealRepository {
  static Future<MealPlan?> fetchApprovedPlan(String? profileId) async {
    if (profileId == null) return null;

    try {
      final response = await Supabase.instance.client
          .from('meal_plans')
          .select()
          .eq('profile_id', profileId)
          .eq('approved', true) // Only approved plans
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle(); // Returns null if no approved plan found

      if (response != null) {
        return MealPlan.fromJson(response);
      }
    } catch (e) {
      print('Error fetching meal plan: $e');
    }
    return null;
  }

  /// Save an AI-generated meal plan to Supabase.
  /// Sets approved=true and published=true so it appears immediately.
  static Future<void> saveGeneratedPlan(String profileId, MealPlan plan) async {
    final monday = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    final weekStart = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';

    await Supabase.instance.client.from('meal_plans').insert({
      'profile_id': profileId,
      'week_start_date': weekStart,
      'weekly_plan': plan.weeklyPlan.map((d) => d.toJson()).toList(),
      'approved': true,
      'version': 1,
      'notes': 'AI-generated meal plan',
    });
  }

  static Future<void> logFood(String profileId, Map<String, dynamic> foodData) async {
    // food_logs: patient_id + analysis_json (org_id is set by the database)
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception("User not authenticated.");

    final analysisPayload = {
      'foods': [
        {'name': foodData['food_name']}
      ],
      'macros': {
        'calories': foodData['calories'],
        'protein': foodData['protein'],
        'fat': foodData['fat'],
        'carbs': foodData['carbs'],
      }
    };

    await Supabase.instance.client.from('food_logs').insert({
      'patient_id': user.id,
      'logged_at': DateTime.now().toUtc().toIso8601String(),
      'analysis_json': analysisPayload,
    });
  }
}

