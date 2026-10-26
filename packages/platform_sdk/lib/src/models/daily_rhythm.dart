import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class DailyRhythm {
  final String id;
  final DateTime date;
  final String summary; // AI's motivational note
  final List<RhythmTask> tasks;
  final String source; // 'generated', 'blueprint', or 'optimized'
  final int? blueprintDayNumber; // Links to the blueprint day this was derived from
  final String? morningText; // AI-generated 8AM push notification text
  final String? lunchText;   // AI-generated 1:30PM push notification text
  final String? eveningText; // AI-generated 9PM push notification text

  const DailyRhythm({
    required this.id,
    required this.date,
    required this.summary,
    required this.tasks,
    this.source = 'generated',
    this.blueprintDayNumber,
    this.morningText,
    this.lunchText,
    this.eveningText,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'summary': summary,
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'source': source,
      if (blueprintDayNumber != null) 'blueprintDayNumber': blueprintDayNumber,
      if (morningText != null) 'morningText': morningText,
      if (lunchText != null) 'lunchText': lunchText,
      if (eveningText != null) 'eveningText': eveningText,
    };
  }

  factory DailyRhythm.fromJson(Map<String, dynamic> json) {
    return DailyRhythm(
      id: json['id'],
      date: DateTime.parse(json['date']),
      summary: json['summary'] ?? "Let's make today count!",
      tasks: (json['tasks'] as List<dynamic>?)
          ?.map((t) => RhythmTask.fromJson(t))
          .toList() ?? [],
      source: json['source'] ?? 'generated',
      blueprintDayNumber: json['blueprintDayNumber'],
      morningText: json['morningText'],
      lunchText: json['lunchText'],
      eveningText: json['eveningText'],
    );
  }

  double get completionRate {
    if (tasks.isEmpty) return 0.0;
    final completedCount = tasks.where((t) => t.isCompleted).length;
    return completedCount / tasks.length;
  }
}

class RhythmTask {
  final String id;
  final String title;
  final String? detail;
  final String? time; // e.g. 'Morning', '10:00 AM', 'Post-Training'
  final String category; // 'lifestyle', 'diet', 'fitness', 'supplement'
  final bool isCompleted;

  const RhythmTask({
    required this.id,
    required this.title,
    this.detail,
    this.time,
    required this.category,
    this.isCompleted = false,
  });
  
  RhythmTask copyWith({bool? isCompleted}) {
    return RhythmTask(
      id: id,
      title: title,
      detail: detail,
      time: time,
      category: category,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'detail': detail,
      'time': time,
      'category': category,
      'isCompleted': isCompleted,
    };
  }

  factory RhythmTask.fromJson(Map<String, dynamic> json) {
    return RhythmTask(
      id: json['id'],
      title: json['title'],
      detail: json['detail'],
      time: json['time'],
      category: json['category'] ?? 'lifestyle',
      isCompleted: json['isCompleted'] ?? false,
    );
  }
  
  // Helper to get icon based on category
  IconData get icon {
    switch (category.toLowerCase()) {
      case 'diet': return LucideIcons.utensils;
      case 'fitness': return LucideIcons.dumbbell;
      case 'supplement': return LucideIcons.pill;
      case 'lifestyle': 
      default: return LucideIcons.sun;
    }
  }
  
  Color get color { // Helper specific to UI, but useful here if standard
     // Return null to let UI decide, or standard Zyndio colors
     return  const Color(0xFF10B981); // Emerald
  }
}
