import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../zyndio_config.dart';
import '../models/daily_rhythm.dart';
import '../models/protocol_blueprint.dart';
import '../models/protocol_data.dart';
import '../models/wearable_snapshot.dart';

class ProtocolIntelligenceService {
  /// Helper to extract clean JSON from a markdown-wrapped string
  static String _cleanJson(String text) {
    String cleaned = text.trim();
    if (cleaned.contains('```json')) {
      final start = cleaned.indexOf('```json') + 7;
      final end = cleaned.lastIndexOf('```');
      if (end > start) {
        cleaned = cleaned.substring(start, end);
      }
    } else if (cleaned.contains('```')) {
      final start = cleaned.indexOf('```') + 3;
      final end = cleaned.lastIndexOf('```');
      if (end > start) {
        cleaned = cleaned.substring(start, end);
      }
    }
    cleaned = cleaned.trim();
    if (!cleaned.startsWith('{')) {
      final firstBrace = cleaned.indexOf('{');
      final lastBrace = cleaned.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
        cleaned = cleaned.substring(firstBrace, lastBrace + 1);
      }
    }
    return cleaned.trim();
  }

  static Future<String?> _callAzureAPI(List<Map<String, dynamic>> messages, {bool jsonMode = false, int maxTokens = 4096}) async {
    try {
      final config = BrandConfig.instance;
      final url = Uri.parse('\${config.apiEndpoint}/chat/completions');
      
      final body = <String, dynamic>{
        "messages": messages,
        "max_tokens": maxTokens,
      };
      if (jsonMode) {
        body["response_format"] = {"type": "json_object"};
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api-key': config.apiKey,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        debugPrint('ProtocolIntelligenceService API Error: \${response.statusCode} - \${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('ProtocolIntelligenceService Exception: \$e');
      return null;
    }
  }

  /// Optimizes an existing blueprint day based on real-time body state.
  static Future<DailyRhythm?> optimizeBlueprintDay(
    BlueprintDay blueprintDay,
    ProtocolData protocol, {
    WearableSnapshot? wearable,
    DailyRhythm? yesterday,
    double progress = 0.0,
    String? userName,
    List<String>? userContext,
    String? habitContext,
  }) async {
    final name = userName ?? 'there';
    final buffer = StringBuffer();
    buffer.writeln("You are 'the Intelligence' — a personal AI health concierge inside the Zyndio app.");
    buffer.writeln("You are talking TO the user, whose name is \$name. Address them by first name.");
    buffer.writeln("Below is the PRE-PLANNED schedule for today (Day \${blueprintDay.dayNumber}, Week \${blueprintDay.weekNumber}).");
    buffer.writeln("Optimize it based on their current body state.");
    buffer.writeln("Keep the protocol's core intent. Only modify what's necessary.");
    buffer.writeln("");
    buffer.writeln("PROTOCOL: \${protocol.title} (\${protocol.currentPhase})");
    buffer.writeln("PROGRESS: \${(progress * 100).toInt()}%");
    buffer.writeln("");

    if (userContext != null && userContext.isNotEmpty) {
      buffer.writeln("WHAT I KNOW ABOUT \$name (from past conversations):");
      for (final fact in userContext) {
        buffer.writeln("  - \$fact");
      }
      buffer.writeln("");
    }

    if (habitContext != null) {
      buffer.writeln(habitContext);
      buffer.writeln("");
    }

    buffer.writeln("TODAY'S PLANNED TASKS:");
    for (var task in blueprintDay.tasks) {
      buffer.writeln("  - [\${task.category}] \${task.title}: \${task.detail ?? ''} @ \${task.time ?? 'Flexible'}");
    }
    buffer.writeln("PLANNED SUMMARY: \${blueprintDay.summary}");

    if (wearable != null && (wearable.recoveryScore > 0 || wearable.sleepHours > 0)) {
      buffer.writeln("\\nTODAY'S BODY STATE:");
      buffer.writeln("Recovery: \${wearable.recoveryScore}/100");
      buffer.writeln("Sleep: \${wearable.sleepHours.toStringAsFixed(1)}h (Score: \${wearable.sleepScore}/100)");
      buffer.writeln("Strain: \${wearable.strainScore}/100");
      buffer.writeln("Stress: \${wearable.stressScore}/100");
      if (wearable.rhr != null) buffer.writeln("Resting HR: \${wearable.rhr} bpm");
      if (wearable.hrv != null) buffer.writeln("HRV: \${wearable.hrv!.toStringAsFixed(0)} ms");
    }

    if (yesterday != null) {
      final completed = yesterday.tasks.where((t) => t.isCompleted).length;
      final total = yesterday.tasks.length;
      buffer.writeln("\\nYESTERDAY: \$name completed \$completed/\$total tasks.");
      final missed = yesterday.tasks.where((t) => !t.isCompleted).map((t) => t.title).toList();
      if (missed.isNotEmpty) buffer.writeln("Missed: \${missed.join(', ')}");
    }

    buffer.writeln("\\nINSTRUCTIONS:");
    buffer.writeln("1. If recovery LOW (<50) or sleep <6h: Replace high-intensity fitness with recovery.");
    buffer.writeln("2. If stress HIGH (>70): Add calming tasks.");
    buffer.writeln("3. If body state GOOD: Keep plan as-is or push slightly harder.");
    buffer.writeln("4. If no body state data: Return the plan mostly unchanged.");
    buffer.writeln("5. Re-include missed yesterday tasks if important.");
    buffer.writeln("6. Update summary to reflect optimization reason. Write it AS IF talking to \$name directly.");
    buffer.writeln("7. Categories: 'lifestyle', 'diet', 'fitness'. No 'supplement'.");
    buffer.writeln("8. Generate 3 personalized PUSH NOTIFICATION texts:");
    buffer.writeln("   - morningText: For 8:00 AM. Under 80 chars. Use 1 emoji.");
    buffer.writeln("   - lunchText: For 1:30 PM. Under 80 chars. Use 1 emoji.");
    buffer.writeln("   - eveningText: For 9:00 PM. Under 80 chars. Use 1 emoji.");
    buffer.writeln("   NOTIFICATION VOICE RULES:");
    buffer.writeln("   - You ARE the Intelligence. Talk like a sharp, slightly casual friend who knows \$name's life.");
    buffer.writeln("   - Address \$name by first name.");
    buffer.writeln("   - Reference REAL data: biometrics, yesterday's completion.");
    buffer.writeln("   - Tone: warm but direct. Like a coach who genuinely cares.");

    buffer.writeln("\\nRETURN STRICT JSON:");
    buffer.writeln('''
{
  "summary": "Updated motivational message addressing \$name directly",
  "morningText": "Short 8AM push notification addressing \$name by name with emoji",
  "lunchText": "Short 1:30PM push notification addressing \$name by name with emoji",
  "eveningText": "Short 9PM push notification addressing \$name by name with emoji",
  "tasks": [{"id": "1", "title": "...", "detail": "...", "time": "...", "category": "...", "isCompleted": false}]
}
''');

    final messages = [
      {"role": "system", "content": "You are 'the Intelligence' — a personal AI health concierge. Respond with valid JSON only."},
      {"role": "user", "content": buffer.toString()}
    ];

    final responseText = await _callAzureAPI(messages, jsonMode: true);

    if (responseText != null) {
      try {
        final jsonMap = jsonDecode(_cleanJson(responseText));
        jsonMap['id'] = 'optimized_day_\${blueprintDay.dayNumber}';
        jsonMap['date'] = blueprintDay.date.toIso8601String();
        jsonMap['source'] = 'optimized';
        jsonMap['blueprintDayNumber'] = blueprintDay.dayNumber;
        return DailyRhythm.fromJson(jsonMap);
      } catch (e) {
        debugPrint("JSON Parse Error in optimizeBlueprintDay: \$e");
      }
    }

    return blueprintDay.toDailyRhythm();
  }

  /// Generates a personalized daily rhythm based on protocol and history
  static Future<DailyRhythm?> generateDailyRhythm(
    ProtocolData protocol, 
    DailyRhythm? yesterday, {
    WearableSnapshot? wearable,
    double progress = 0.0,
    String? userName,
    List<String>? userContext,
    String? habitContext,
  }) async {
    final name = userName ?? 'there';
    final buffer = StringBuffer();
    buffer.writeln("You are 'the Intelligence' — a personal AI health concierge inside the Zyndio app.");
    buffer.writeln("You are talking TO the user, whose name is \$name. Address them by first name.");
    buffer.writeln("Generate a specific 'Daily Rhythm' (To-Do List) for TODAY.");
    buffer.writeln("\\nPHASE PROGRESS:");
    buffer.writeln("\$name is \${(progress * 100).toInt()}% through the \${protocol.currentPhase} of \${protocol.title}.");

    if (userContext != null && userContext.isNotEmpty) {
      buffer.writeln("\\nWHAT I KNOW ABOUT \$name (from past conversations):");
      for (final fact in userContext) {
        buffer.writeln("  - \$fact");
      }
    }

    if (habitContext != null) {
      buffer.writeln("\\n\$habitContext");
    }
    
    buffer.writeln("\\nCONTEXT:");
    buffer.writeln("Protocol: \${protocol.title} (\${protocol.currentPhase})");
    buffer.writeln("Focus: \${protocol.subtitle}");
    
    if (wearable != null && (wearable.recoveryScore > 0 || wearable.sleepHours > 0)) {
      buffer.writeln("\\nTODAY'S BODY STATE (from wearable sensors):");
      buffer.writeln("Recovery Score: \${wearable.recoveryScore}/100");
      buffer.writeln("Strain Score: \${wearable.strainScore}/100");
      buffer.writeln("Stress Score: \${wearable.stressScore}/100");
      buffer.writeln("Sleep: \${wearable.sleepHours.toStringAsFixed(1)}h (Score: \${wearable.sleepScore}/100)");
      buffer.writeln("Energy/Readiness: \${wearable.energyScore}/100");
      if (wearable.rhr != null) buffer.writeln("Resting HR: \${wearable.rhr} bpm");
      if (wearable.hrv != null) buffer.writeln("HRV: \${wearable.hrv!.toStringAsFixed(0)} ms");
      buffer.writeln("Steps so far: \${wearable.steps}");
    }
    
    buffer.writeln("\\nPROTOCOL REQUIREMENTS:");
    if (protocol.lifestyle.isNotEmpty) {
       buffer.writeln("Lifestyle: \${protocol.lifestyle.map((t) => t.title).join(', ')}");
    }
    if (protocol.fitness.isNotEmpty) {
       buffer.writeln("Fitness: \${protocol.fitness.map((t) => t.title).join(', ')}");
    }
    
    if (yesterday != null) {
       buffer.writeln("\\nYESTERDAY'S PROGRESS:");
       int completed = yesterday.tasks.where((t) => t.isCompleted).length;
       int total = yesterday.tasks.length;
       buffer.writeln("\$name completed \$completed/\$total tasks.");
       buffer.writeln("Missed Tasks: \${yesterday.tasks.where((t) => !t.isCompleted).map((t) => t.title).join(', ')}");
    }
    
    buffer.writeln("\\nINSTRUCTIONS:");
    buffer.writeln("1. Create 7-10 high-impact tasks for TODAY.");
    buffer.writeln("2. Categories must be: 'lifestyle', 'diet', or 'fitness'.");
    buffer.writeln("3. Adapt intensity based on the body state scores.");
    buffer.writeln("4. Provide a 1-sentence motivational summary ADDRESSED DIRECTLY to \$name.");
    buffer.writeln("5. Order tasks chronologically from morning to night.");
    buffer.writeln("6. Generate 3 personalized PUSH NOTIFICATION texts (morning, lunch, evening).");
    buffer.writeln("7. OUTPUT MUST BE STRICT JSON ONLY.");
    
    buffer.writeln('''\\nREQUIRED JSON FORMAT:
{
  "summary": "Motivational message addressing \$name directly.",
  "morningText": "Short 8AM push notification addressing \$name by name with emoji",
  "lunchText": "Short 1:30PM push notification addressing \$name by name with emoji",
  "eveningText": "Short 9PM push notification addressing \$name by name with emoji",
  "tasks": [
    {
      "id": "1",
      "title": "Task Title",
      "detail": "Short details",
      "time": "Morning",
      "category": "lifestyle",
      "isCompleted": false
    }
  ]
}''');

    final messages = [
      {"role": "system", "content": "You are 'the Intelligence' — a personal AI health concierge. Respond with valid JSON only."},
      {"role": "user", "content": buffer.toString()}
    ];

    final responseText = await _callAzureAPI(messages, jsonMode: true);
    
    if (responseText != null) {
      try {
        final jsonMap = jsonDecode(_cleanJson(responseText));
        jsonMap['id'] = DateTime.now().toIso8601String();
        jsonMap['date'] = DateTime.now().toIso8601String();
        return DailyRhythm.fromJson(jsonMap);
      } catch (e) {
        debugPrint("JSON Parse Error in generateDailyRhythm: \$e");
      }
    }
    
    return _getFallbackRhythm(protocol);
  }

  static DailyRhythm _getFallbackRhythm(ProtocolData protocol) {
    final List<RhythmTask> fallbackTasks = [];
    fallbackTasks.addAll(protocol.lifestyle.map((t) => RhythmTask(
      id: 'life_\${t.title.hashCode}',
      title: t.title,
      detail: t.detail,
      time: t.time.isNotEmpty ? t.time : 'Morning',
      category: 'lifestyle',
      isCompleted: false,
    )));

    fallbackTasks.addAll(protocol.fitness.map((t) => RhythmTask(
      id: 'fit_\${t.title.hashCode}',
      title: t.title,
      detail: t.detail,
      time: t.time.isNotEmpty ? t.time : 'Afternoon',
      category: 'fitness',
      isCompleted: false,
    )));

    return DailyRhythm(
      id: "fallback-\${DateTime.now().day}",
      date: DateTime.now(),
      summary: "Focusing on your core \${protocol.title} routine today.",
      tasks: fallbackTasks.isNotEmpty ? fallbackTasks : [
          const RhythmTask(id: "f1", title: "Hydrate (500ml)", category: "diet", detail: "Upon waking", time: "Morning"),
          const RhythmTask(id: "f5", title: "Movement", category: "fitness", detail: "30 min brisk walk", time: "Afternoon"),
      ],
    );
  }
}
