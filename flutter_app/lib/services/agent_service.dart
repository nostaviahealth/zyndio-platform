import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/meal_repository.dart';
import '../providers/rhythm_provider.dart';
import '../providers/patient_provider.dart';

final agentServiceProvider = Provider<AgentService>((ref) => AgentService(ref));

class AgentService {
  final Ref _ref;

  AgentService(this._ref);

  Future<String> executeTool(String name, Map<String, dynamic> args) async {
    final profile = _ref.read(patientProfileProvider).value;
    final profileId = profile?.id;

    if (profileId == null && name == 'log_food') {
      return "Error: User not logged in. Cannot log food.";
    }

    try {
      switch (name) {
        case 'log_food':
          try {
            await MealRepository.logFood(profileId!, args);
            return "Successfully logged ${args['food_name']} (${args['calories']} kcal).";
          } catch (e) {
            return "Failed to log food. System Error: $e";
          }

        case 'update_rhythm':
          final action = args['action'];
          final title = args['task_title'];
          final time = args['time_of_day'];

          final notifier = _ref.read(dailyRhythmProvider.notifier);

          if (action == 'add') {
            await notifier.addTask(title, time);
            return "Added '$title' to your daily rhythm.";
          } else if (action == 'remove') {
            await notifier.removeTask(title);
            return "Removed '$title' from your daily rhythm.";
          } else if (action == 'complete') {
            await notifier.completeTaskByTitle(title);
            return "Marked '$title' as completed.";
          }
          return "Unknown action '$action' for update_rhythm.";

        case 'read_health_context':
          final rhythmState = _ref.read(dailyRhythmProvider);
          final rhythm = rhythmState.rhythm.value;
          if (rhythm == null) return "No rhythm data available.";
          
          final tasks = rhythm.tasks.map((t) => "${t.timeOfDay ?? ''} ${t.title} [${t.isCompleted ? 'DONE' : 'TODO'}]").join(", ");
          return "Current Date: ${DateTime.now().toIso8601String().substring(0, 10)}\nRhythm Summary: ${rhythm.summary}\nTasks Today: $tasks";



        default:
          return "Error: Tool '$name' not found.";
      }
    } catch (e) {
      return "Error executing tool '$name': $e";
    }
  }
}

// Extension to safely access Detail as timeOfDay since RhythmTask uses detail for it usually
extension TaskTime on dynamic {
   String? get timeOfDay => this.detail; 
}
