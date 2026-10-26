
import 'package:flutter/material.dart';

enum SuggestionType {
  morning,
  afternoon,
  evening,
  health,
  data,
  general
}

class SmartSuggestion {
  final String id;
  final String label;
  final String prompt;
  final IconData icon;
  final SuggestionType type;

  const SmartSuggestion({
    required this.id,
    required this.label,
    required this.prompt,
    required this.icon,
    this.type = SuggestionType.general,
  });
}
