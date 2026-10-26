import 'package:flutter/material.dart';

class ProtocolData {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String currentPhase;
  final List<String> availablePhases;
  final bool isPremium;
  final DietBlueprint diet;
  final List<ProtocolTask> lifestyle;
  final List<ProtocolTask> fitness;
  final List<ProtocolTask> supplements;
  final Map<String, dynamic> debugGoal;
  final List<String> targetMetrics;

  const ProtocolData({
    required this.id,
    required this.title,
    required this.subtitle,
    this.description = '',
    required this.currentPhase,
    required this.availablePhases,
    this.isPremium = false,
    required this.diet,
    required this.lifestyle,
    required this.fitness,
    required this.supplements,
    this.debugGoal = const {},
    this.targetMetrics = const [],
  });
}

class DietBlueprint {
  final List<MacroItem> macros;
  final List<String> features;
  final List<TargetItem> targets;
  final List<String> avoid;

  const DietBlueprint({
    required this.macros,
    required this.features,
    required this.targets,
    required this.avoid,
  });
}

class MacroItem { 
  final String label; 
  final String value; 
  const MacroItem({required this.label, required this.value}); 
}

class TargetItem { 
  final String label; 
  final String value; 
  const TargetItem({required this.label, required this.value}); 
}

class ProtocolTask {
  final String title;
  final String detail;
  final String time;
  final String? frequency;
  final String? buyLink;
  final IconData? icon;
  final String? category;

  const ProtocolTask({
    required this.title,
    required this.detail,
    required this.time,
    this.frequency,
    this.buyLink,
    this.icon,
    this.category,
  });
}
