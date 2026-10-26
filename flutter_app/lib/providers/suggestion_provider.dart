import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/smart_suggestion.dart';
import 'patient_provider.dart';
import 'lab_reports_provider.dart';
import 'intelligence_provider.dart';
import 'protocol_provider.dart';

final suggestionProvider = Provider<List<SmartSuggestion>>((ref) {
  final now = DateTime.now();
  final hour = now.hour;
  final suggestions = <SmartSuggestion>[];

  // 1. Time-Based Context
  if (hour >= 5 && hour < 11) {
    // Morning
    suggestions.add(const SmartSuggestion(
      id: 'morning_routine',
      label: 'Morning Routine',
      prompt: 'Help me optimize my morning routine for energy and focus.',
      icon: LucideIcons.sun,
      type: SuggestionType.morning,
    ));
    suggestions.add(const SmartSuggestion(
      id: 'sleep_review',
      label: 'Sleep Review',
      prompt: 'Analyze my sleep quality from last night and suggest improvements.',
      icon: LucideIcons.moon,
      type: SuggestionType.morning,
    ));
  } else if (hour >= 11 && hour < 17) {
    // Afternoon
    suggestions.add(const SmartSuggestion(
      id: 'energy_dip',
      label: 'Afternoon Energy',
      prompt: 'Why do I feel an energy dip in the afternoon? How can I fix it?',
      icon: LucideIcons.batteryMedium,
      type: SuggestionType.afternoon,
    ));
    suggestions.add(const SmartSuggestion(
      id: 'lunch_ideas',
      label: 'Healthy Lunch',
      prompt: 'Suggest a metabolic-friendly lunch option.',
      icon: LucideIcons.utensils,
      type: SuggestionType.afternoon,
    ));
  } else {
    // Evening
    suggestions.add(const SmartSuggestion(
      id: 'wind_down',
      label: 'Wind Down',
      prompt: 'Give me a protocol to wind down for better deep sleep tonight.',
      icon: LucideIcons.bedDouble,
      type: SuggestionType.evening,
    ));
    suggestions.add(const SmartSuggestion(
      id: 'fasting_timer',
      label: 'Start Fasting',
      prompt: 'When should I start my fast tonight for optimal autonomy?',
      icon: LucideIcons.timer,
      type: SuggestionType.evening,
    ));
  }

  // 2. Data-Driven Context (Lab Reports)
  final labReports = ref.watch(labReportsProvider).value;
  if (labReports != null && labReports.isNotEmpty) {
    suggestions.insert(0, const SmartSuggestion(
      id: 'analyze_labs',
      label: 'Analyze Latest Labs',
      prompt: 'Deep dive into my latest blood work. What are the key red flags?',
      icon: LucideIcons.testTube,
      type: SuggestionType.data,
    ));
  }

  // 3. Profile Context (Bio-Age check)
  final profile = ref.watch(patientProfileProvider).value;
  if (profile != null) {
      if ((profile.age ?? 0) > 30) {
           suggestions.add(const SmartSuggestion(
              id: 'longevity',
              label: 'Longevity Plan',
              prompt: 'Create a longevity protocol to lower my biological age.',
              icon: LucideIcons.dna,
              type: SuggestionType.health,
            ));
      }
  }

  // === BRIDGE 3: INTELLIGENCE-AWARE SUGGESTIONS ===
  final intelligence = ref.watch(intelligenceDataProvider).value;
  if (intelligence != null && intelligence.healthDomains.isNotEmpty) {
    // Find the weakest domain — surface it as a priority chip
    final sorted = [...intelligence.healthDomains]..sort((a, b) => a.score.compareTo(b.score));
    final weakest = sorted.first;
    if (weakest.score < 70) {
      suggestions.insert(0, SmartSuggestion(
        id: 'fix_${weakest.name.toLowerCase()}',
        label: '${weakest.name} is ${weakest.grade ?? "Low"}',
        prompt: 'My ${weakest.name} health score is ${weakest.score}/100 (Grade: ${weakest.grade ?? "Low"}). What can I do to improve it?',
        icon: LucideIcons.heartPulse,
        type: SuggestionType.health,
      ));
    }

    // Disease risk warning chip
    if (intelligence.diseaseRisks.isNotEmpty) {
      final topRisk = intelligence.diseaseRisks.reduce((a, b) => a.probability > b.probability ? a : b);
      if (topRisk.probability > 20) {
        suggestions.add(SmartSuggestion(
          id: 'risk_${topRisk.condition.toLowerCase().replaceAll(' ', '_')}',
          label: 'Reduce ${topRisk.condition} Risk',
          prompt: 'My ${topRisk.condition} risk is ${topRisk.probability}%. Give me a protocol to reduce it.',
          icon: LucideIcons.shieldAlert,
          type: SuggestionType.health,
        ));
      }
    }
  }

  // === BRIDGE 3: PROTOCOL-AWARE SUGGESTIONS ===
  final protocolState = ref.watch(protocolProvider);
  final activeProtocol = protocolState.selectedProtocol;
  if (activeProtocol != null) {
    // Suggest simulating the protocol's diet
    if (activeProtocol.diet.features.isNotEmpty) {
      suggestions.add(SmartSuggestion(
        id: 'simulate_protocol_diet',
        label: 'Simulate My Diet',
        prompt: 'What happens to my body if I follow my ${activeProtocol.title} diet plan today? Simulate the metabolic impact.',
        icon: LucideIcons.flaskConical,
        type: SuggestionType.health,
      ));
    }

    // Suggest checking supplement impact
    if (activeProtocol.supplements.isNotEmpty) {
      final supNames = activeProtocol.supplements.map((s) => s.title).take(2).join(' & ');
      suggestions.add(SmartSuggestion(
        id: 'simulate_supplements',
        label: 'Check $supNames Impact',
        prompt: 'How do my current supplements ($supNames) affect my metabolic health? Simulate having a meal with and without them.',
        icon: LucideIcons.pill,
        type: SuggestionType.health,
      ));
    }
  }

  return suggestions.take(4).toList(); // Limit to 4 chips
});
