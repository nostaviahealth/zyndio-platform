import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import '../models/daily_rhythm.dart';
import '../data/protocol_repository.dart';
import '../models/food_analysis.dart';
import '../models/protocol_blueprint.dart';
import '../models/patient_profile.dart';
import '../providers/intelligence_provider.dart';
import '../services/user_habit_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'prompt_templates.dart';


class AIResponse {
  final String? content;
  final List<ToolCall>? toolCalls;

  AIResponse({this.content, this.toolCalls});
}

class AIStreamEvent {
  final String? contentDelta;
  final List<ToolCall>? toolCalls; 
  final bool isDone;
  
  AIStreamEvent({this.contentDelta, this.toolCalls, this.isDone = false});
}

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  ToolCall({required this.id, required this.name, required this.arguments});
}

/// TC-021 #11: thrown (before any request is built) when an intelligence
/// call is attempted without a signed-in session. Every call site already
/// treats an exception as a failed call, so nothing is sent.
class IntelligenceSignedOutException implements Exception {
  @override
  String toString() => 'IntelligenceSignedOutException: sign in to use intelligence';
}

class AzureOpenAIService {
  AzureOpenAIService({String? Function()? accessToken})
      : _accessToken = accessToken ?? (() => SupabaseConfig.currentSession?.accessToken);

  /// Source of the signed-in user's JWT (injectable for tests).
  final String? Function() _accessToken;

  /// Stores the last error message for diagnostics
  String? lastError;

  /// Returns the base URL for Supabase Edge Functions.
  String get _functionsUrl => SupabaseConfig.url;

  /// Returns the authorization headers needed to call Edge Functions.
  /// Only a signed-in user's JWT is ever sent: there is no anon-key
  /// fallback, so a signed-out app cannot call intelligence (TC-021 #11).
  Map<String, String> get _headers {
    final accessToken = _accessToken();
    if (accessToken == null || accessToken.isEmpty) {
      throw IntelligenceSignedOutException();
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'apikey': SupabaseConfig.anonKey,
    };
  }

  /// Helper to extract clean JSON from a markdown-wrapped string
  String cleanJson(String text) {
    String cleaned = text.trim();
    
    // 1. Strip markdown code fence at start
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }

    // Strip markdown code fence at end
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }

    cleaned = cleaned.trim();

    // 2. Extract JSON object {...}
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    return cleaned.trim();
  }

  /// Helper to make AI API calls via the Edge Function proxy
  Future<String?> callAzureAPI(
    List<Map<String, dynamic>> messages, {
    bool jsonMode = false,
    String feature = 'companion',
  }) async {
    try {
      final url = Uri.parse('$_functionsUrl/functions/v1/intelligence');
      
      final body = <String, dynamic>{
        "messages": messages,
        "max_completion_tokens": 4096,
        "feature": feature,
      };
      if (jsonMode) {
        body["response_format"] = {"type": "json_object"};
      }

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        debugPrint('AI Proxy Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('AI Proxy Exception: $e');
      return null;
    }
  }

  /// Generates a concise summary of a chat session
  Future<String> generateChatSummary(List<Map<String, String>> messages) async {
     if (messages.isEmpty) return "";

     final promptMessages = [
       {
         "role": "system", 
         "content": "You are a helpful assistant. Summarize the following health conversation in 2-3 sentences. Focus on key symptoms, advice given, and any action items. Do not include 'User said' or 'AI said'."
       },
       ...messages.map((m) => {"role": m['role'] == 'model' ? 'assistant' : m['role'], "content": m['text']}),
     ];

     final summary = await callAzureAPI(
       promptMessages.cast<Map<String, dynamic>>(),
       feature: 'memory',
     );
     return summary ?? "";
  }

  /// Generates personalized nutrition goals based on profile and protocol.
  Future<Map<String, int>?> recommendNutritionGoals({
    required PatientProfile profile,
    required ProtocolData? protocol,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln("You are an expert performance nutritionist.");
    buffer.writeln("Generate daily nutritional targets as JSON.");
    buffer.writeln("");
    buffer.writeln("USER BIO:");
    buffer.writeln("- Age: ${profile.age ?? 30}");
    if (profile.bioAge != null) buffer.writeln("- Biological Age: ${profile.bioAge}");
    if (profile.questionnaireData != null) {
      final gender = profile.questionnaireData!['gender'] ?? 'Unknown';
      final weight = profile.questionnaireData!['weight'] ?? 'Unknown';
      final height = profile.questionnaireData!['height'] ?? 'Unknown';
      buffer.writeln("- Gender: $gender");
      buffer.writeln("- Weight: $weight kg");
      buffer.writeln("- Height: $height cm");
    }
    
    if (protocol != null) {
      buffer.writeln("");
      buffer.writeln("ACTIVE PROTOCOL: ${protocol.title}");
      buffer.writeln("FOCUS: ${protocol.subtitle}");
      if (protocol.diet.features.isNotEmpty) {
        buffer.writeln("DIET FEATURES: ${protocol.diet.features.join(', ')}");
      }
    }

    buffer.writeln("");
    buffer.writeln("RULES:");
    buffer.writeln("1. Calculate Calories, Protein(g), Carbs(g), and Fat(g).");
    buffer.writeln("2. Protein should be high for muscle preservation/longevity (1.6g-2.2g per kg if known).");
    buffer.writeln("3. Balance Carbs and Fats based on the ${protocol?.title ?? 'General Health'} protocol.");
    buffer.writeln("4. Return ONLY a JSON object with keys: calories, protein, carbs, fat.");

    final messages = [
      {"role": "system", "content": "You are a calculation engine. Output valid JSON only."},
      {"role": "user", "content": buffer.toString()}
    ];

    final responseText = await callAzureAPI(messages, jsonMode: true, feature: 'coaching');
    if (responseText != null) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(cleanJson(responseText));
        return {
          'calories': (jsonMap['calories'] as num).toInt(),
          'protein': (jsonMap['protein'] as num).toInt(),
          'carbs': (jsonMap['carbs'] as num).toInt(),
          'fat': (jsonMap['fat'] as num).toInt(),
          'fiber': (jsonMap['fiber'] as num?)?.toInt() ?? 0,
        };
      } catch (e) {
        debugPrint("JSON Parse Error in recommendNutritionGoals: $e");
      }
    }
    return null;
  }


  /// Generates a week blueprint batch for a protocol — LEAN prompt for speed.
  Future<List<BlueprintDay>?> generateBlueprintWeeksBatch(
    ProtocolData protocol, {
    required int startWeek,
    required int count,
    required int totalWeeks,
    required DateTime startDate,
    String? previousWeekSummary,
  }) async {
    final totalDays = count * 7;
    final startDay = (startWeek - 1) * 7 + 1;
    final dateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';

    // Build compact protocol context
    final lifestyleStr = protocol.lifestyle.isNotEmpty
        ? protocol.lifestyle.map((t) => t.title).join(', ')
        : 'Sleep hygiene, Stress management';
    final fitnessStr = protocol.fitness.isNotEmpty
        ? protocol.fitness.map((t) => '${t.title} [${t.frequency ?? "Daily"}]').join(', ')
        : 'Walking, Stretching';
    final dietStr = protocol.diet.features.isNotEmpty
        ? protocol.diet.features.take(5).join(', ')
        : 'Balanced nutrition';

    String phase = 'Foundation';
    if (startWeek > totalWeeks * 0.7) {
      phase = 'Peak';
    } else if (startWeek > totalWeeks * 0.3) {
      phase = 'Progressive';
    }

    final prompt = '''
Generate $totalDays days of health tasks as JSON. Week $startWeek${count > 1 ? '-${startWeek + count - 1}' : ''} of $totalWeeks.
Protocol: ${protocol.title}. Phase: $phase.
Lifestyle: $lifestyleStr
Fitness: $fitnessStr
Diet: $dietStr
${previousWeekSummary != null ? 'Previous: $previousWeekSummary' : ''}

Rules:
- 5 tasks per day (2 lifestyle, 1-2 diet, 1-2 fitness)
- Each task: id, title, detail (1 sentence), time, category, isCompleted:false
- Day numbers start at $startDay, dates start $dateStr
- Categories: lifestyle, diet, fitness only
- Sunday = active recovery

Respond ONLY with: {"days":[{"day":$startDay,"week":$startWeek,"date":"$dateStr","summary":"...","tasks":[...]},...]}''';

    final messages = [
      {"role": "system", "content": "You are a health task generator. Output valid JSON only. Be concise."},
      {"role": "user", "content": prompt}
    ];

    // Use higher token limit for blueprint generation
    final responseText = await _callAzureAPIWithTokens(messages, maxTokens: 16384, jsonMode: true);

    if (responseText != null) {
      try {
        final jsonMap = jsonDecode(cleanJson(responseText));
        final daysJson = jsonMap['days'] as List<dynamic>?;
        if (daysJson != null && daysJson.isNotEmpty) {
          return daysJson.asMap().entries.map((entry) {
            final idx = entry.key;
            final dayMap = Map<String, dynamic>.from(entry.value as Map);
            final globalDay = (startWeek - 1) * 7 + idx + 1;
            final globalWeek = ((globalDay - 1) / 7).floor() + 1;
            final dDate = startDate.add(Duration(days: idx));

            dayMap['day'] = globalDay;
            dayMap['week'] = globalWeek;
            dayMap['date'] = '${dDate.year}-${dDate.month.toString().padLeft(2, '0')}-${dDate.day.toString().padLeft(2, '0')}';

            return BlueprintDay.fromJson(dayMap);
          }).toList();
        }
      } catch (e) {
        debugPrint("JSON Parse Error in generateBlueprintWeeksBatch: $e");
      }
    }
    return null;
  }

  /// Dedicated API call with configurable token limits for blueprint generation
  Future<String?> _callAzureAPIWithTokens(
    List<Map<String, dynamic>> messages, {
    required int maxTokens,
    bool jsonMode = false,
    String feature = 'coaching',
  }) async {
    try {
      final url = Uri.parse('$_functionsUrl/functions/v1/intelligence');
      
      final body = <String, dynamic>{
        "messages": messages,
        "max_completion_tokens": maxTokens,
        "feature": feature,
      };
      if (jsonMode) {
        body["response_format"] = {"type": "json_object"};
      }

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        debugPrint('AI Blueprint Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('AI Blueprint Exception: $e');
      return null;
    }
  }

  /// Optimizes an existing blueprint day based on real-time body state.
  /// Much lighter than full generation — only modifies what's necessary.
  Future<DailyRhythm?> optimizeBlueprintDay(
    BlueprintDay blueprintDay,
    ProtocolData protocol, {
    WearableSnapshot? wearable,
    DailyRhythm? yesterday,
    double progress = 0.0,
    String? userName,
    List<String>? userContext,
    UserHabitProfile? habitProfile,
  }) async {
    final name = userName ?? 'there';
    final buffer = StringBuffer();
    buffer.writeln("You are 'the Intelligence' — a personal AI health concierge inside the Zyndio app.");
    buffer.writeln("You are talking TO the user, whose name is $name. Address them by first name.");
    buffer.writeln("Below is the PRE-PLANNED schedule for today (Day ${blueprintDay.dayNumber}, Week ${blueprintDay.weekNumber}).");
    buffer.writeln("Optimize it based on their current body state.");
    buffer.writeln("Keep the protocol's core intent. Only modify what's necessary.");
    buffer.writeln("");
    buffer.writeln("PROTOCOL: ${protocol.title} (${protocol.currentPhase})");
    buffer.writeln("PROGRESS: ${(progress * 100).toInt()}%");
    buffer.writeln("");

    // Inject long-term memory context (user facts, habits, preferences)
    if (userContext != null && userContext.isNotEmpty) {
      buffer.writeln("WHAT I KNOW ABOUT $name (from past conversations):");
      for (final fact in userContext) {
        buffer.writeln("  - $fact");
      }
      buffer.writeln("");
    }

    if (habitProfile != null) {
      buffer.writeln(habitProfile.toAIContext());
      buffer.writeln("");
    }

    buffer.writeln("TODAY'S PLANNED TASKS:");
    for (var task in blueprintDay.tasks) {
      buffer.writeln("  - [${task.category}] ${task.title}: ${task.detail ?? ''} @ ${task.time ?? 'Flexible'}");
    }
    buffer.writeln("PLANNED SUMMARY: ${blueprintDay.summary}");

    if (wearable != null && (wearable.recoveryScore > 0 || wearable.sleepHours > 0)) {
      buffer.writeln("\nTODAY'S BODY STATE:");
      buffer.writeln("Recovery: ${wearable.recoveryScore}/100");
      buffer.writeln("Sleep: ${wearable.sleepHours.toStringAsFixed(1)}h (Score: ${wearable.sleepScore}/100)");
      buffer.writeln("Strain: ${wearable.strainScore}/100");
      buffer.writeln("Stress: ${wearable.stressScore}/100");
      if (wearable.rhr != null) buffer.writeln("Resting HR: ${wearable.rhr} bpm");
      if (wearable.hrv != null) buffer.writeln("HRV: ${wearable.hrv!.toStringAsFixed(0)} ms");
    }

    if (yesterday != null) {
      final completed = yesterday.tasks.where((t) => t.isCompleted).length;
      final total = yesterday.tasks.length;
      buffer.writeln("\nYESTERDAY: $name completed $completed/$total tasks.");
      final missed = yesterday.tasks.where((t) => !t.isCompleted).map((t) => t.title).toList();
      if (missed.isNotEmpty) buffer.writeln("Missed: ${missed.join(', ')}");
    }

    buffer.writeln("\nINSTRUCTIONS:");
    buffer.writeln("1. If recovery LOW (<50) or sleep <6h: Replace high-intensity fitness with recovery.");
    buffer.writeln("2. If stress HIGH (>70): Add calming tasks.");
    buffer.writeln("3. If body state GOOD: Keep plan as-is or push slightly harder.");
    buffer.writeln("4. If no body state data: Return the plan mostly unchanged.");
    buffer.writeln("5. Re-include missed yesterday tasks if important.");
    buffer.writeln("6. Update summary to reflect optimization reason. Write it AS IF talking to $name directly.");
    buffer.writeln("7. Categories: 'lifestyle', 'diet', 'fitness'. No 'supplement'.");
    buffer.writeln("8. Generate 3 personalized PUSH NOTIFICATION texts:");
    buffer.writeln("   - morningText: For 8:00 AM. Under 80 chars. Use 1 emoji.");
    buffer.writeln("   - lunchText: For 1:30 PM. Under 80 chars. Use 1 emoji.");
    buffer.writeln("   - eveningText: For 9:00 PM. Under 80 chars. Use 1 emoji.");
    buffer.writeln("   NOTIFICATION VOICE RULES:");
    buffer.writeln("   - You ARE the Intelligence. Talk like a sharp, slightly casual friend who knows $name's life.");
    buffer.writeln("   - Address $name by first name. Example: '$name, only 5h sleep — I adjusted your plan ⚡'");
    buffer.writeln("   - Reference REAL data: biometrics, yesterday's completion, known habits/preferences.");
    buffer.writeln("   - If you know something about $name from context (injury, diet, goal), weave it in naturally.");
    buffer.writeln("   - NEVER be generic. NEVER say 'Dear user'. NEVER sound like a robot.");
    buffer.writeln("   - Tone: warm but direct. Like a coach who genuinely cares.");

    buffer.writeln("\nRETURN STRICT JSON:");
    buffer.writeln('''
{
  "summary": "Updated motivational message addressing $name directly",
  "morningText": "Short 8AM push notification addressing $name by name with emoji",
  "lunchText": "Short 1:30PM push notification addressing $name by name with emoji",
  "eveningText": "Short 9PM push notification addressing $name by name with emoji",
  "tasks": [{"id": "1", "title": "...", "detail": "...", "time": "...", "category": "...", "isCompleted": false}]
}
''');

    final messages = [
      {"role": "system", "content": "You are 'the Intelligence' — a personal AI health concierge built into the Zyndio app. You know the user by name. You speak directly to them in a warm but sharp tone. You reference their real biometric data and past habits. You never sound generic or robotic. Respond with valid JSON only."},
      {"role": "user", "content": buffer.toString()}
    ];

    final responseText = await callAzureAPI(messages, jsonMode: true, feature: 'coaching');

    if (responseText != null) {
      try {
        final jsonMap = jsonDecode(cleanJson(responseText));
        jsonMap['id'] = 'optimized_day_${blueprintDay.dayNumber}';
        jsonMap['date'] = blueprintDay.date.toIso8601String();
        jsonMap['source'] = 'optimized';
        jsonMap['blueprintDayNumber'] = blueprintDay.dayNumber;
        return DailyRhythm.fromJson(jsonMap);
      } catch (e) {
        debugPrint("JSON Parse Error in optimizeBlueprintDay: $e");
      }
    }

    // Fallback: return blueprint as-is
    return blueprintDay.toDailyRhythm();
  }

  /// Generates a personalized daily rhythm based on protocol and history
  Future<DailyRhythm?> generateDailyRhythm(
    ProtocolData protocol, 
    DailyRhythm? yesterday, {
    WearableSnapshot? wearable,
    double progress = 0.0,
    String? userName,
    List<String>? userContext,
    UserHabitProfile? habitProfile,
  }) async {
    final name = userName ?? 'there';
    final buffer = StringBuffer();
    buffer.writeln("You are 'the Intelligence' — a personal AI health concierge inside the Zyndio app.");
    buffer.writeln("You are talking TO the user, whose name is $name. Address them by first name.");
    buffer.writeln("Generate a specific 'Daily Rhythm' (To-Do List) for TODAY.");
    buffer.writeln("\nPHASE PROGRESS:");
    buffer.writeln("$name is ${(progress * 100).toInt()}% through the ${protocol.currentPhase} of ${protocol.title}.");
    if (progress >= 0.8) buffer.writeln("COACHING NOTE: $name is in the final stretch. Focus on perfect consistency for phase advancement.");
    else if (progress >= 0.4 && progress <= 0.6) buffer.writeln("COACHING NOTE: $name is at the midway point. Boost motivation!");

    // Inject long-term memory context (user facts, habits, preferences)
    if (userContext != null && userContext.isNotEmpty) {
      buffer.writeln("\nWHAT I KNOW ABOUT $name (from past conversations):");
      for (final fact in userContext) {
        buffer.writeln("  - $fact");
      }
    }

    if (habitProfile != null) {
      buffer.writeln("\n${habitProfile.toAIContext()}");
    }
    
    buffer.writeln("\nCONTEXT:");
    buffer.writeln("Protocol: ${protocol.title} (${protocol.currentPhase})");
    buffer.writeln("Focus: ${protocol.subtitle}");
    
    // ── Wearable Intelligence Context ──
    if (wearable != null && (wearable.recoveryScore > 0 || wearable.sleepHours > 0)) {
      buffer.writeln("\nTODAY'S BODY STATE (from wearable sensors):");
      buffer.writeln("Recovery Score: ${wearable.recoveryScore}/100");
      buffer.writeln("Strain Score: ${wearable.strainScore}/100");
      buffer.writeln("Stress Score: ${wearable.stressScore}/100");
      buffer.writeln("Sleep: ${wearable.sleepHours.toStringAsFixed(1)}h (Score: ${wearable.sleepScore}/100)");
      buffer.writeln("Energy/Readiness: ${wearable.energyScore}/100");
      if (wearable.rhr != null) buffer.writeln("Resting HR: ${wearable.rhr} bpm");
      if (wearable.hrv != null) buffer.writeln("HRV: ${wearable.hrv!.toStringAsFixed(0)} ms");
      buffer.writeln("Steps so far: ${wearable.steps}");
    }
    
    buffer.writeln("\nPROTOCOL REQUIREMENTS:");
    if (protocol.lifestyle.isNotEmpty) {
       buffer.writeln("Lifestyle: ${protocol.lifestyle.map((t) => t.title).join(', ')}");
    }
    if (protocol.fitness.isNotEmpty) {
       buffer.writeln("Fitness: ${protocol.fitness.map((t) => t.title).join(', ')}");
    }
    if (protocol.supplements.isNotEmpty) {
       buffer.writeln("Supplements: ${protocol.supplements.map((t) => t.title).join(', ')}");
    }
    
    if (yesterday != null) {
       buffer.writeln("\nYESTERDAY'S PROGRESS:");
       int completed = yesterday.tasks.where((t) => t.isCompleted).length;
       int total = yesterday.tasks.length;
       buffer.writeln("$name completed $completed/$total tasks.");
       buffer.writeln("Missed Tasks: ${yesterday.tasks.where((t) => !t.isCompleted).map((t) => t.title).join(', ')}");
    } else {
       buffer.writeln("\nThis is $name's first day of tracking.");
    }

    buffer.writeln("\nINSTRUCTIONS:");
    buffer.writeln("1. Create 7-10 high-impact tasks for TODAY.");
    buffer.writeln("2. Categories must be: 'lifestyle', 'diet', or 'fitness'. DO NOT include 'supplement'.");
    buffer.writeln("3. Ensure at least 2 tasks for Diet and 2 for Lifestyle.");
    buffer.writeln("4. Adapt to yesterday's progress.");
    buffer.writeln("5. CRITICALLY adapt intensity based on the body state scores: If Recovery < 50 or Sleep < 6h, replace high-intensity fitness with recovery activities (stretching, yoga, walking). If Stress > 70, add calming lifestyle tasks (meditation, breathwork). If Recovery > 75 and Strain is low, push for a harder workout.");
    buffer.writeln("6. Provide a 1-sentence motivational summary ADDRESSED DIRECTLY to $name.");
    buffer.writeln("7. Each task MUST include a 'time' field with a specific time of day (e.g. 'Morning', 'Afternoon', 'Evening', 'Night', or a specific time like '7:00 AM').");
    buffer.writeln("8. Order tasks chronologically from morning to night.");
    buffer.writeln("9. Generate 3 personalized PUSH NOTIFICATION texts:");
    buffer.writeln("   - morningText: For 8:00 AM. Under 80 chars. Use 1 emoji.");
    buffer.writeln("   - lunchText: For 1:30 PM. Under 80 chars. Use 1 emoji.");
    buffer.writeln("   - eveningText: For 9:00 PM. Under 80 chars. Use 1 emoji.");
    buffer.writeln("   NOTIFICATION VOICE RULES:");
    buffer.writeln("   - You ARE the Intelligence. Talk like a sharp, slightly casual friend who knows $name's life.");
    buffer.writeln("   - Address $name by first name. Example: '$name, 7h sleep last night — solid base ⚡'");
    buffer.writeln("   - Reference REAL data: biometrics, yesterday's completion, known habits/preferences.");
    buffer.writeln("   - If you know something about $name from context (injury, diet preference, goal), weave it in naturally.");
    buffer.writeln("   - NEVER be generic. NEVER say 'Dear user'. NEVER sound like a robot.");
    buffer.writeln("   - Tone: warm but direct. Like a coach who genuinely cares.");
    buffer.writeln("10. OUTPUT MUST BE STRICT JSON ONLY.");
    
    buffer.writeln('''\nREQUIRED JSON FORMAT:''');
    buffer.writeln('''
    {
      "summary": "Motivational message addressing $name directly.",
      "morningText": "Short 8AM push notification addressing $name by name with emoji",
      "lunchText": "Short 1:30PM push notification addressing $name by name with emoji",
      "eveningText": "Short 9PM push notification addressing $name by name with emoji",
      "tasks": [
        {
          "id": "1",
          "title": "Task Title",
          "detail": "Short details (e.g. 10 mins)",
          "time": "Morning",
          "category": "lifestyle",
          "isCompleted": false
        }
      ]
    }
    ''');

    final messages = [
      {"role": "system", "content": "You are 'the Intelligence' — a personal AI health concierge built into the Zyndio app. You know the user by name. You speak directly to them in a warm but sharp tone. You reference their real biometric data and past habits. You never sound generic or robotic. Respond with valid JSON only."},
      {"role": "user", "content": buffer.toString()}
    ];

    final responseText = await callAzureAPI(messages, jsonMode: true, feature: 'coaching');
    
    if (responseText != null) {
      try {
        final jsonMap = jsonDecode(cleanJson(responseText));
        jsonMap['id'] = DateTime.now().toIso8601String();
        jsonMap['date'] = DateTime.now().toIso8601String();
        return DailyRhythm.fromJson(jsonMap);
      } catch (e) {
        debugPrint("JSON Parse Error in generateDailyRhythm: $e");
      }
    }
    
    return _getFallbackRhythm(protocol);
  }

  DailyRhythm _getFallbackRhythm(ProtocolData protocol) {
    final List<RhythmTask> fallbackTasks = [];
    
    fallbackTasks.addAll(protocol.lifestyle.map((t) => RhythmTask(
      id: 'life_${t.title.hashCode}',
      title: t.title,
      detail: t.detail,
      time: t.time.isNotEmpty ? t.time : 'Morning',
      category: 'lifestyle',
      isCompleted: false,
    )));

    fallbackTasks.addAll(protocol.fitness.map((t) => RhythmTask(
      id: 'fit_${t.title.hashCode}',
      title: t.title,
      detail: t.detail,
      time: t.time.isNotEmpty ? t.time : 'Afternoon',
      category: 'fitness',
      isCompleted: false,
    )));

    if (fallbackTasks.isEmpty) {
       return DailyRhythm(
        id: "fallback-${DateTime.now().day}",
        date: DateTime.now(),
        summary: "Let's focus on the basics today.",
        tasks: [
          const RhythmTask(id: "f1", title: "Hydrate (500ml)", category: "diet", detail: "Upon waking", time: "Morning"),
          const RhythmTask(id: "f3", title: "Morning Light", category: "lifestyle", detail: "10-15 mins outdoors", time: "Morning"),
          const RhythmTask(id: "f5", title: "Movement", category: "fitness", detail: "30 min brisk walk", time: "Afternoon"),
        ],
      );
    }

    return DailyRhythm(
      id: "fallback-${DateTime.now().day}",
      date: DateTime.now(),
      summary: "Focusing on your core ${protocol.title} routine today.",
      tasks: fallbackTasks,
    );
  }

  /// Sends a chat message and returns the AI response with optional tool calls
  Future<AIResponse> getChatResponse(
      List<Map<String, dynamic>> messages, {
      List<Map<String, dynamic>>? tools,
  }) async {
    try {
      final url = Uri.parse('$_functionsUrl/functions/v1/intelligence');

      final body = <String, dynamic>{
        "messages": messages,
        "max_completion_tokens": 4096,
        "feature": "companion",
      };

      if (tools != null && tools.isNotEmpty) {
          body['tools'] = tools;
          body['tool_choice'] = "auto";
      }

      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choice = data['choices'][0];
        final message = choice['message'];
        
        final content = message['content'];
        final toolCallsJson = message['tool_calls'];

        List<ToolCall>? toolCalls;
        if (toolCallsJson != null) {
            toolCalls = (toolCallsJson as List).map((tc) {
                return ToolCall(
                    id: tc['id'], 
                    name: tc['function']['name'], 
                    arguments: jsonDecode(tc['function']['arguments'])
                );
            }).toList();
        }

        return AIResponse(content: content, toolCalls: toolCalls);
      } else {
        debugPrint("AI API Error: ${response.statusCode} - ${response.body}");
        // Friendlier error message for the user
        return AIResponse(content: "A lot of people are talking to me right now! My brain is a bit busy. Please try again in a moment.");
      }
    } catch (e) {
      debugPrint("AI API Exception: $e");
      return AIResponse(content: "I hit a small snag. Could you try sending that again?");
    }
  }

  /// Streams a chat response, parsing SSE chunks for text content and tool calls.
  Stream<AIStreamEvent> getChatResponseStream(
      List<Map<String, dynamic>> messages, {
      List<Map<String, dynamic>>? tools,
  }) async* {
    try {
      final url = Uri.parse('$_functionsUrl/functions/v1/intelligence');

      final body = <String, dynamic>{
        "messages": messages,
        "max_completion_tokens": 4096,
        "stream": true,
        "feature": "companion",
      };

      if (tools != null && tools.isNotEmpty) {
        body['tools'] = tools;
        body['tool_choice'] = "auto";
      }

      final request = http.Request('POST', url);
      request.headers.addAll(_headers);
      request.body = jsonEncode(body);

      final client = http.Client();
      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorString = await response.stream.bytesToString();
        debugPrint("AI Stream Error: ${response.statusCode} - $errorString");
        
        // Friendlier error message for the user
        yield AIStreamEvent(
          contentDelta: "A lot of people are talking to me right now! My brain is a bit busy. Please try again in a moment.", 
          isDone: true
        );
        client.close();
        return;
      }

      Map<int, Map<String, dynamic>> toolCallsMap = {};
      
      await for (var chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final dataStr = chunk.substring(6).trim();
          if (dataStr == '[DONE]') {
            break;
          }
          
          try {
            final data = jsonDecode(dataStr);
            final choices = data['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'];
              
              if (delta['tool_calls'] != null) {
                for (var tc in delta['tool_calls']) {
                  int index = tc['index'];
                  if (!toolCallsMap.containsKey(index)) {
                     toolCallsMap[index] = {
                       "id": tc['id'],
                       "function": {
                         "name": tc['function']?['name'] ?? "",
                         "arguments": tc['function']?['arguments'] ?? ""
                       }
                     };
                  } else {
                     if (tc['function']?['arguments'] != null) {
                       toolCallsMap[index]!['function']['arguments'] += tc['function']['arguments'];
                     }
                  }
                }
              }
              
              if (delta['content'] != null) {
                yield AIStreamEvent(contentDelta: delta['content']);
              }
            }
          } catch (e) {
            // Silently ignore parse errors for partial JSON chunks
          }
        }
      }

      if (toolCallsMap.isNotEmpty) {
        List<ToolCall> finalToolCalls = toolCallsMap.values.map((tc) {
          return ToolCall(
            id: tc['id'],
            name: tc['function']['name'],
            arguments: jsonDecode(tc['function']['arguments'])
          );
        }).toList();
        yield AIStreamEvent(toolCalls: finalToolCalls, isDone: true);
      } else {
        yield AIStreamEvent(isDone: true);
      }
      
      client.close();
    } catch (e) {
      debugPrint("Stream Exception: $e");
      final errorStr = e.toString();
      // Silently finish if connection is closed/aborted, rather than showing raw URIs
      if (errorStr.contains("Connection closed") || errorStr.contains("ClientException") || errorStr.contains("SocketException")) {
         yield AIStreamEvent(isDone: true);
      } else {
         yield AIStreamEvent(contentDelta: "\n\n[Network interruption]", isDone: true);
      }
    }
  }

  /// Extracts biomarkers from a list of lab report images.
  /// Medical-grade: extracts EXACTLY what the lab printed — names, values,
  /// units, reference ranges, categories/sections, and the lab's own flags.
  Future<Map<String, dynamic>> extractBiomarkers(List<File> images) async {
    const String systemPrompt = '''
You are a meticulous clinical medical data extraction assistant. Your job is to extract EVERY single test result from the provided lab report images with surgical precision.

CRITICAL RULES:
1. READ EVERY PAGE from start to finish. Do NOT skip any test result.
2. Extract EXACTLY what the lab printed — do not invent, assume, or normalize values.
3. Preserve the lab's own SECTION HEADERS as categories (e.g. "Complete Blood Count", "Liver Function Test", "Lipid Profile", "Thyroid Profile", "Renal Function Test", "Urine Routine", etc.).
4. For each biomarker, extract:
   - name: The exact test name as printed on the report
   - value: The numeric or text value as printed
   - unit: The unit as printed (e.g. mg/dL, U/L, %, g/dL)
   - referenceRange: The reference range AS PRINTED on the report (e.g. "70-100", "<150", ">40"). This is CRITICAL. Perform a surgical search: look at headers, footnotes, or distant columns. If it is on the page, you MUST find it.
   - status: MUST be strictly either 'Outlier' (if the value is flagged as High, Low, Abnormal, or Critical) or 'In-range' (if the value is Normal or within the reference range). DO NOT use any other words like 'Normal' or 'High' for this field.
5. Find the report title/lab name, collection date ("Sample Date", "Collection Date", "Drawn Date"), patient age, and gender.
6. If a biomarker appears under multiple sections, include it in the FIRST section where it appears.
7. Use strictly professional medical terminology. Preserve original test names. Aggressively search for reference ranges even in small print or footnotes.

OUTPUT FORMAT (strict JSON):
{
  "title": "Report title or lab name",
  "date": "YYYY-MM-DD (collection/sample date)",
  "age": number | null,
  "gender": "Male" | "Female" | null,
  "labName": "Name of the laboratory if visible" | null,
  "categories": [
    {
      "name": "Section header as printed (e.g. Complete Blood Count)",
      "markers": [
        {
          "name": "Test name as printed",
          "value": "Value as printed (number or text)",
          "unit": "Unit as printed",
          "referenceRange": "Reference range as printed on report",
          "status": "Outlier" | "In-range"
        }
      ]
    }
  ]
}

If a test does not clearly belong to any section header, group it under "General" or "Other Tests".
''';

    final List<Map<String, dynamic>> messages = [
      {
        "role": "system",
        "content": systemPrompt
      },
      {
        "role": "user",
        "content": [
          {"type": "text", "text": "Extract every single test result from these lab report pages. Preserve the lab's own section headers, reference ranges, units, and flags exactly as printed."},
          ...await Future.wait(images.map((image) async {
            final bytes = await image.readAsBytes();
            final base64Image = base64Encode(bytes);
            return {
              "type": "image_url",
              "image_url": {
                "url": "data:image/jpeg;base64,$base64Image"
              }
            };
          }))
        ]
      }
    ];

    try {
      final url = Uri.parse('$_functionsUrl/functions/v1/intelligence');
      
      final body = jsonEncode({
          "messages": messages,
          "max_completion_tokens": 16384,
          "response_format": {"type": "json_object"},
          "feature": "lab_extraction",
      });

      final response = await http.post(
        url,
        headers: _headers,
        body: body,
      ).timeout(
        const Duration(seconds: 180),
        onTimeout: () {
          throw Exception('Analysis timed out. The report might be too large or the service is slow. Please try again.');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return jsonDecode(cleanJson(content));
      } else {
        // TC-039: the proxy's response body is neither printed nor copied
        // into the exception (it can carry backend error text); the status
        // code is enough for the caller's fixed error state.
        if (response.statusCode == 504) {
          throw Exception('Analysis timed out (Error 504). This usually happens with very large reports or slow connections. We have optimized the process — please try again.');
        }
        throw Exception('Extraction failed (Error ${response.statusCode})');
      }
    } catch (_) {
      // TC-039: not printed; the caller shows its own error state.
      rethrow;
    }
  }

  /// Returns time-of-day context string for circadian analysis.
  String _getCurrentTimeContext() {
    final now = DateTime.now();
    final hour = now.hour;
    String timeOfDay;
    if (hour >= 5 && hour < 12) {
      timeOfDay = "Morning";
    } else if (hour >= 12 && hour < 17) {
      timeOfDay = "Afternoon";
    } else if (hour >= 17 && hour < 21) {
      timeOfDay = "Evening";
    } else {
        timeOfDay = "Late Night";
    }
    return "$timeOfDay (${now.hour}:${now.minute.toString().padLeft(2,'0')})";
  }

  /// PHASE 1 (FAST): Returns quick macro analysis and basic bio-impact.
  /// Accepts optional [base64String] to avoid re-encoding the same image bytes.
  /// [userCorrection] allows guiding the AI if it misidentified the food.
  Future<FoodAnalysis?> analyzeFoodImageFast(File image, {String? base64String, String? userCorrection}) async {
    const int maxAttempts = 3;

    final String mainPrompt = 'Expert clinical nutritionist. Identify meal with HIGH SPECIFICITY — name every visible component (e.g. "Masala Dosa with Coconut Chutney" not "Pancake", "Chicken Tikka Masala with Basmati Rice" not "Curry"). Consider regional cuisine (Indian, Asian, Mexican, etc). Estimate portion from visual cues. Output strict JSON: {food_name, calories, macros:{protein, carbs, fat}, metabolic_impact:{digestion_time:"Rapid|Moderate|Slow", energy_curve:"Spike|Sustained|Crash"}, score(1-100), intelligence_insight (3-4 lines), bio_impact:[{category, title, description, impact:"positive|neutral|negative"}]}.';

    // Ultra-minimal fallback prompt for final attempt
    const String fallbackPrompt = 'Nutritionist. Identify the food in this image. Output JSON: {food_name, calories, macros:{protein, carbs, fat}, score(1-100), intelligence_insight, bio_impact:[{category, title, description, impact}]}.';

    final String extension = image.path.split('.').last.toLowerCase();
    final String mimeType = (extension == 'png') ? 'image/png' : 'image/jpeg';
    final String b64 = base64String ?? base64Encode(await image.readAsBytes());

    lastError = null;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final bool isFinalAttempt = attempt == maxAttempts;
        final String systemPrompt = isFinalAttempt ? fallbackPrompt : mainPrompt;

        final String userText = userCorrection != null && userCorrection.isNotEmpty
            ? "I am eating '$userCorrection'. Use this to guide your identification. Time: ${_getCurrentTimeContext()}. Analyze the image carefully."
            : "Analyze this meal. Time: ${_getCurrentTimeContext()}. Examine every visible component.";

        final List<Map<String, dynamic>> messages = [
          {"role": "system", "content": systemPrompt},
          {
            "role": "user",
            "content": <Map<String, dynamic>>[
              {"type": "text", "text": userText},
              {"type": "image_url", "image_url": {"url": "data:$mimeType;base64,$b64"}},
            ]
          }
        ];

        final primaryUrl = Uri.parse('$_functionsUrl/functions/v1/intelligence');
        final directUrl = Uri.parse('${SupabaseConfig.url}/functions/v1/intelligence');
        
        final targetUrl = (attempt == 2) ? directUrl : primaryUrl;
        
        final response = await http.post(
          targetUrl,
          headers: _headers,
          body: jsonEncode({
            "messages": messages,
            "max_completion_tokens": 2048,
            "response_format": {"type": "json_object"},
            "feature": "food_analysis",
          }),
        ).timeout(const Duration(seconds: 45));

        if (response.statusCode != 200) {
          lastError = 'API Error ${response.statusCode}: ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}';
          debugPrint('[LENS] API Error (Attempt $attempt/$maxAttempts on $targetUrl): ${response.statusCode} - ${response.body}');
          
          if (response.statusCode == 429) {
            await Future.delayed(Duration(seconds: 2 * attempt));
          } else {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
          }
          continue;
        }

        // ── Parse the response ──────────────────────────────────────
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        
        if (choices == null || choices.isEmpty) {
          lastError = 'AI returned empty choices array';
          debugPrint('[LENS] No choices in response (Attempt $attempt)');
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }

        final message = choices[0]['message'];
        final finishReason = choices[0]['finish_reason']?.toString() ?? '';
        final content = message?['content']?.toString();

        // ── Check finish_reason ─────────────────────────────────────
        if (finishReason == 'content_filter') {
          lastError = 'Content filtered by AI safety filter';
          debugPrint('[LENS] Content filtered by Azure (Attempt $attempt). Retrying...');
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }

        if (content == null || content.isEmpty) {
          lastError = 'Empty content from AI model';
          debugPrint('[LENS] Empty content from AI (Attempt $attempt, finish_reason: $finishReason)');
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }

        // ── Parse JSON ──────────────────────────────────────────────
        try {
          final jsonStr = cleanJson(content);
          final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
          
          // Extract food_name flexibly across all possible LLM key aliases
          final foodNameVal = jsonMap['food_name'] ?? jsonMap['foodName'] ?? jsonMap['food'] ?? jsonMap['name'] ?? jsonMap['meal'] ?? jsonMap['meal_name'] ?? jsonMap['title'];
          jsonMap['food_name'] = foodNameVal?.toString() ?? 'Scanned Meal';
          
          lastError = null;
          return FoodAnalysis.fromJson(jsonMap);
        } catch (parseError) {
          lastError = 'JSON Parse Error: $parseError';
          debugPrint('[LENS] JSON Parse Error (Attempt $attempt): $parseError');
          debugPrint('[LENS] Raw content: ${content.length > 300 ? content.substring(0, 300) : content}');
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }

      } catch (e) {
        lastError = 'Network Exception: $e';
        debugPrint('[LENS] Exception (Attempt $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    
    debugPrint('[LENS] All $maxAttempts attempts failed for food analysis.');
    return null;
  }

  /// TEXT ONLY: Identify meal from text description.
  Future<FoodAnalysis?> analyzeFoodText(String description) async {
    final String systemPrompt = '''Expert clinical nutritionist and longevity scientist. Identify meal from text description.
STRICT RULE: Do NOT invent or assume specific ingredients that were not mentioned (e.g., do not assume 'Ham and Cheese' if the user only said 'Sandwich').
If the description is vague, provide a generic high-level analysis or use healthy standard baselines (e.g., multi-grain bread) and explicitly mention your assumptions in the 'intelligence_insight'.
Maintain HIGH SPECIFICITY for what IS provided, but ZERO ASSUMPTION for what IS NOT.
Output strict JSON: 
{"food_name":str,"calories":int,"macros":{"protein":int,"carbs":int,"fat":int},"metabolic_impact":{"digestion_time":"Rapid|Moderate|Slow","energy_curve":"Spike|Sustained|Crash"},"score":0-100,"intelligence_insight":"personalized, 3-4 lines","toxins":[{"name":str,"details":str,"severity":"High|Medium|Low"}],"upf_analysis":{"score":0-10,"level":"Whole Food|Minimally Processed|Processed|Ultra-Processed","additives":[str],"verdict":str},"circadian_match":{"meal_time":"Morning|Afternoon|Evening|Late Night","match":"Excellent|Good|Fair|Poor","match_score":0-100,"reason":str,"recommendation":str},"bio_hack":{"tip":str,"mechanism":str,"timing":str,"potency_percent":int},"hormonal_impact":{"insulin":{"name":"Insulin","response":"Spike|Moderate Rise|Stable|Decrease","impact":"positive|neutral|negative","detail":str},"leptin":{"name":"Leptin","response":"Increase|Stable|Blunted Response","impact":same,"detail":str},"ghrelin":{"name":"Ghrelin","response":"Suppressed|Stable|Elevated","impact":same,"detail":str}},"bioavailability":{"absorption_score":0-100,"tips":[{"type":"Synergy|Anti-Nutrient|Preparation","title":str,"description":str,"impact":"positive|negative"}]},"longevity_impact":{"longevity_score":0-100,"sirtuin_effect":"Activating|Neutral|Suppressing","mtor_effect":"Inhibiting|Neutral|Activating","inflammation_effect":"Anti-inflammatory|Neutral|Pro-inflammatory","longevity_summary":str,"longevity_credit":-20 to +20},"bio_impact":[{"category":str,"title":str,"description":str,"impact":"positive|neutral|negative"}]}''';

    try {
      final List<Map<String, dynamic>> messages = [
        {"role": "system", "content": systemPrompt},
        {"role": "user", "content": "I am eating: $description. Time: ${_getCurrentTimeContext()}."}
      ];

      final url = Uri.parse('$_functionsUrl/functions/v1/intelligence');
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          "messages": messages,
          "max_completion_tokens": 2048,
          "response_format": {"type": "json_object"},
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        final jsonMap = jsonDecode(cleanJson(content)) as Map<String, dynamic>;
        return FoodAnalysis.fromJson(jsonMap);
      } else {
        debugPrint('[LENS] Text Analysis Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[LENS] Text Analysis Exception: $e');
    }
    return null;
  }

  /// PHASE 2 (DEEP): Returns deep V2 biological analysis.
  /// Uses the Phase 1 food context (no need to re-analyze the image from scratch).
  /// Accepts optional [base64String] to avoid re-encoding the same image bytes.
  Future<Map<String, dynamic>?> analyzeFoodImageDeep(File image, String foodName, int calories, {String? base64String}) async {
    int attempts = 0;
    const int maxAttempts = 2;

    final String systemPrompt = '''Longevity scientist. Meal: "$foodName" (~$calories kcal). Deep biological analysis → strict JSON.
{"score":0-100,"intelligence_insight":"personalized, 3-4 lines","toxins":[{"name":str,"details":str,"severity":"High|Medium|Low"}],"upf_analysis":{"score":0-10,"level":"Whole Food|Minimally Processed|Processed|Ultra-Processed","additives":[str],"verdict":str},"circadian_match":{"meal_time":"Morning|Afternoon|Evening|Late Night","match":"Excellent|Good|Fair|Poor","match_score":0-100,"reason":str,"recommendation":str},"bio_hack":{"tip":str,"mechanism":str,"timing":str,"potency_percent":int},"hormonal_impact":{"insulin":{"name":"Insulin","response":"Spike|Moderate Rise|Stable|Decrease","impact":"positive|neutral|negative","detail":str},"leptin":{"name":"Leptin","response":"Increase|Stable|Blunted Response","impact":same,"detail":str},"ghrelin":{"name":"Ghrelin","response":"Suppressed|Stable|Elevated","impact":same,"detail":str}},"bioavailability":{"absorption_score":0-100,"tips":[{"type":"Synergy|Anti-Nutrient|Preparation","title":str,"description":str,"impact":"positive|negative"}]},"longevity_impact":{"longevity_score":0-100,"sirtuin_effect":"Activating|Neutral|Suppressing","mtor_effect":"Inhibiting|Neutral|Activating","inflammation_effect":"Anti-inflammatory|Neutral|Pro-inflammatory","longevity_summary":str,"longevity_credit":-20 to +20}}
Score rule: Refine score considering UPF level, longevity credits, hormonal disruption. High UPF → lower score.''';

    while (attempts < maxAttempts) {
      attempts++;
      try {
        final List<Map<String, dynamic>> messages = [
          {"role": "system", "content": systemPrompt},
          {
            "role": "user",
            "content": <Map<String, dynamic>>[
              {"type": "text", "text": "Deep analysis. Time: ${_getCurrentTimeContext()}."},
            ]
          }
        ];

        final String extension = image.path.split('.').last.toLowerCase();
        final String mimeType = (extension == 'png') ? 'image/png' : 'image/jpeg';
        final String b64 = base64String ?? base64Encode(await image.readAsBytes());
        
        (messages[1]['content'] as List).add({
          "type": "image_url",
          "image_url": {"url": "data:$mimeType;base64,$b64"}
        });

        final url = Uri.parse('$_functionsUrl/functions/v1/intelligence');
        
        final response = await http.post(
          url,
          headers: _headers,
          body: jsonEncode({
            "messages": messages,
            "max_completion_tokens": 4096,
            "response_format": {"type": "json_object"},
            "feature": "food_analysis",
          }),
        ).timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final content = data['choices'][0]['message']['content'];
          return jsonDecode(cleanJson(content));
        } else {
          debugPrint('AI Deep Analysis Error (Attempt $attempts): ${response.statusCode} - ${response.body}');
          if (attempts >= maxAttempts) return null;
        }
      } catch (e) {
        debugPrint('AI Deep Analysis Exception (Attempt $attempts): $e');
        if (attempts >= maxAttempts) return null;
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    return null;
  }

  /// ── DYNAMIC INTELLIGENCE NOTIFICATION LAYER ──

  /// Generates a contextual anchor nudge (Lunch/Evening)
  Future<Map<String, String>?> generateContextualNudge({
    required String anchorType, // 'Lunch' or 'Evening'
    required String userName,
    required double adherence,
    required List<RhythmTask> todayTasks,
    WearableSnapshot? wearable,
    UserHabitProfile? habitProfile,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln(PromptTemplates.getPersonaForAdherence(adherence));
    buffer.writeln(PromptTemplates.contextualAnchorGuidelines);
    buffer.writeln("\nUSER: $userName");
    buffer.writeln("ANCHOR: $anchorType");
    
    buffer.writeln("\nTODAY'S TASKS:");
    int completed = 0;
    final missed = <String>[];
    for (var task in todayTasks) {
      if (task.isCompleted) {
        completed++;
      } else if (anchorType == 'Evening' || (task.time != null && task.time!.contains('Morning'))) {
        missed.add(task.title);
      }
    }
    buffer.writeln("Completed: $completed/${todayTasks.length}");
    if (missed.isNotEmpty) buffer.writeln("Pending/Missed: ${missed.join(', ')}");

    if (wearable != null) {
      buffer.writeln("\nCURRENT BIOMETRICS:");
      buffer.writeln("- Recovery: ${wearable.recoveryScore}/100");
      buffer.writeln("- Stress: ${wearable.stressScore}/100");
    }

    if (habitProfile != null) {
      buffer.writeln("\nHABIT DRIFT:");
      buffer.writeln(habitProfile.toAIContext());
    }

    final messages = [
      {"role": "system", "content": "Respond exactly in JSON: {'title': '...', 'body': '...'}"},
      {"role": "user", "content": buffer.toString()}
    ];

    final responseText = await callAzureAPI(messages, jsonMode: true, feature: 'coaching');
    if (responseText != null) {
      try {
        final Map<String, dynamic> jsonMap = jsonDecode(cleanJson(responseText));
        return {
          'title': jsonMap['title']?.toString() ?? 'Zyndio',
          'body': jsonMap['body']?.toString() ?? '',
        };
      } catch (e) {
        debugPrint("JSON Parse Error in generateContextualNudge: $e");
      }
    }
    return null;
  }

  /// Generates an immediate reward nudge upon task completion
  Future<String?> generateRewardNudge({
    required String userName,
    required RhythmTask task,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln("USER: $userName");
    buffer.writeln("COMPLETED TASK: [${task.category}] ${task.title}");
    if (task.detail != null) buffer.writeln("DETAIL: ${task.detail}");

    final messages = [
      {"role": "system", "content": PromptTemplates.rewardNudgeGuidelines},
      {"role": "user", "content": buffer.toString()}
    ];

    try {
      final url = Uri.parse('$_functionsUrl/functions/v1/intelligence');
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({
          "messages": messages,
          "max_completion_tokens": 100, // Small limit for speed
          "feature": "coaching",
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      }
    } catch (e) {
      debugPrint('AI Reward Nudge Exception: $e');
    }
    return null;
  }

  /// Refines a raw speech transcript to correct typos and homophones.
  Future<String> refineTranscript(String rawText) async {
    if (rawText.isEmpty) return "";

    final messages = [
      {
        "role": "system",
        "content": "You are a transcription correction engine. Your task is to take a potentially messy speech-to-text transcript of someone describing their food and return a CLEAN, grammatically correct, and semantically accurate version. Fix homophones, typos, and identify food names correctly. Return ONLY the refined text. No conversational filler."
      },
      {"role": "user", "content": "Raw transcript: '$rawText'"}
    ];

    try {
      final response = await callAzureAPI(messages, feature: 'food_analysis');
      return response?.trim() ?? rawText;
    } catch (e) {
      debugPrint('Transcript Refinement Exception: $e');
      return rawText;
    }
  }
}

final azureOpenAIServiceProvider = Provider<AzureOpenAIService>((ref) {
  return AzureOpenAIService();
});
