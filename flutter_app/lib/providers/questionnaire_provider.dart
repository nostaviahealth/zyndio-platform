import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/longevity_questionnaire.dart';
import 'patient_provider.dart';

class QuestionnaireNotifier extends Notifier<LongevityQuestionnaire> {
  @override
  LongevityQuestionnaire build() {
    // Watch the patient profile. When it loads/updates, we get the data.
    final patientProfileAsync = ref.watch(patientProfileProvider);
    
    return patientProfileAsync.when(
      data: (profile) {
        if (profile?.questionnaireData != null) {
          try {
            return LongevityQuestionnaire.fromJson(profile!.questionnaireData!);
          } catch (e) {
            print("Error parsing Supabase questionnaire data: $e");
          }
        }
        return LongevityQuestionnaire();
      },
      loading: () => LongevityQuestionnaire(), // Return empty while loading
      error: (err, stack) {
        print("Error fetching profile for questionnaire: $err");
        return LongevityQuestionnaire();
      },
    );
  }

  Future<void> save(LongevityQuestionnaire data) async {
    // 1. Update Supabase via the patient provider
    await ref.read(patientProfileProvider.notifier).updateQuestionnaire(data.toJson());
    
    // Note: We don't need to manually update 'state' here because 
    // patientProfileProvider.notifier.updateQuestionnaire updates the profile state,
    // which triggers this provider's build() to run again and update our state.
  }
  
  Future<void> clear() async {
    await ref.read(patientProfileProvider.notifier).updateQuestionnaire({});
  }
}

final questionnaireProvider = NotifierProvider<QuestionnaireNotifier, LongevityQuestionnaire>(() {
  return QuestionnaireNotifier();
});
