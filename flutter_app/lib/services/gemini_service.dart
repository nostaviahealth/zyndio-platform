import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/daily_rhythm.dart';
import '../data/protocol_repository.dart';

class GeminiService {
  final String _apiKey;
  // Use stable v1 API endpoint instead of v1beta used by SDK
  // Also try gemini-1.5-flash as it is the current standard
  // Utilizing gemini-flash-latest which is confirmed supported by this key
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  GeminiService({String? apiKey}) : _apiKey = apiKey ?? const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '') {
    if (_apiKey.isEmpty) {
      debugPrint('Warning: GEMINI_API_KEY is missing. Chat will not function properly.');
    }
  }

  /// Generates a personalized daily rhythm based on protocol and history
  Future<DailyRhythm?> generateDailyRhythm(ProtocolData protocol, DailyRhythm? yesterday) async {
      if (_apiKey.isEmpty) return null;

      try {
        final url = Uri.parse('$_baseUrl?key=$_apiKey');
        
        // Construct the prompt
        final buffer = StringBuffer();
        buffer.writeln("Act as an expert Habit Coach and Health Planner.");
        buffer.writeln("Generate a specific 'Daily Rhythm' (To-Do List) for TODAY.");
        buffer.writeln("\nCONTEXT:");
        buffer.writeln("Protocol: ${protocol.title} (${protocol.currentPhase})");
        buffer.writeln("Focus: ${protocol.subtitle}");
        
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
           buffer.writeln("Completion: $completed/$total tasks.");
           buffer.writeln("Missed Tasks: ${yesterday.tasks.where((t) => !t.isCompleted).map((t) => t.title).join(', ')}");
        } else {
           buffer.writeln("\nThis is the first day of tracking.");
        }

        buffer.writeln("\nINSTRUCTIONS:");
        buffer.writeln("1. Create 7-10 high-impact tasks for TODAY.");
        buffer.writeln("2. Categories must be: 'lifestyle', 'diet', or 'fitness'. DO NOT include 'supplement'.");
        buffer.writeln("3. Ensure at least 2 tasks for Diet and 2 for Lifestyle.");
        buffer.writeln("4. Adapt to yesterday's progress.");
        buffer.writeln("5. Provide a 1-sentence motivational summary.");
        buffer.writeln("6. OUTPUT MUST BE STRICT JSON ONLY. No markdown, no backticks.");
        
        buffer.writeln("\nREQUIRED JSON FORMAT:");
        buffer.writeln('''
        {
          "summary": "Your motivational message here.",
          "tasks": [
            {
              "id": "1",
              "title": "Task Title",
              "detail": "Short details (e.g. 10 mins)",
              "category": "lifestyle",
              "isCompleted": false
            }
          ]
        }
        ''');

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [{
              "parts": [{"text": buffer.toString()}]
            }]
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
             String text = data['candidates'][0]['content']['parts'][0]['text'];
             
             // Robust JSON extraction
             final startIndex = text.indexOf('{');
             final endIndex = text.lastIndexOf('}');
             if (startIndex != -1 && endIndex != -1) {
               text = text.substring(startIndex, endIndex + 1);
               
               try {
                 final jsonMap = jsonDecode(text);
                 // Inject ID and Date locally
                 jsonMap['id'] = DateTime.now().toIso8601String(); 
                 jsonMap['date'] = DateTime.now().toIso8601String();
                 return DailyRhythm.fromJson(jsonMap);
               } catch (e) {
                 debugPrint("JSON Parse Error: $e");
               }
             }
          }
        }
        debugPrint('Gemini Rhythm Error: ${response.statusCode} ${response.body}');
        debugPrint('Gemini Rhythm Error: ${response.statusCode} ${response.body}');
        return _getFallbackRhythm(protocol); // Fail gracefully with protocol content
      } catch (e) {
        debugPrint('Gemini Rhythm Network Error: $e');
        return _getFallbackRhythm(protocol);
      }
  }

  DailyRhythm _getFallbackRhythm(ProtocolData protocol) {
    // Merge all protocol tasks into a single list
    final List<RhythmTask> fallbackTasks = [];
    
    // Add Lifestyle Tasks
    fallbackTasks.addAll(protocol.lifestyle.map((t) => RhythmTask(
      id: 'life_${t.title.hashCode}',
      title: t.title,
      detail: t.detail,
      category: 'lifestyle',
      isCompleted: false,
    )));

    // Add Fitness Tasks
    fallbackTasks.addAll(protocol.fitness.map((t) => RhythmTask(
      id: 'fit_${t.title.hashCode}',
      title: t.title,
      detail: t.detail,
      category: 'fitness',
      isCompleted: false,
    )));

    // Note: Supplements are appended by RhythmNotifier automatically, 
    // but we can add them here if we want to ensure they appear in fallback too.
    // However, RhythmNotifier appends them AFTER this returns. 
    // Wait, RhythmNotifier only appends if newRhythm != null. 
    // And this function returns a DailyRhythm, so it IS newRhythm.
    // So RhythmNotifier WILL append supplements again. 
    // Let's NOT add supplements here to avoid duplication.
    
    // If protocol has NO tasks (e.g. empty admin phase), use generic fallback
    if (fallbackTasks.isEmpty) {
       return DailyRhythm(
        id: "fallback-${DateTime.now().day}",
        date: DateTime.now(),
        summary: "Let's focus on the basics today.",
        tasks: [
          const RhythmTask(id: "f1", title: "Hydrate (500ml)", category: "diet", detail: "Upon waking"),
          const RhythmTask(id: "f3", title: "Morning Light", category: "lifestyle", detail: "10-15 mins outdoors"),
          const RhythmTask(id: "f5", title: "Movement", category: "fitness", detail: "30 min brisk walk"),
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

  Future<String> sendMessage(String message, {
    List<Map<String, String>>? history, 
    String? systemContext
  }) async {
    if (_apiKey.isEmpty) {
      return "I'm sorry, my connection to the intelligence core (API Key) is missing. Please check your configuration.";
    }

    try {
      final url = Uri.parse('$_baseUrl?key=$_apiKey');
      
      // Build contents array
      final List<Map<String, dynamic>> contents = [];

      // 1. Inject System Context as the first "user" message (effective for models without system_instruction in REST)
      // Or prepend it to the first message if history is empty.
      if (systemContext != null && systemContext.isNotEmpty) {
         // We'll treat this as a pre-prompt to set behavior
         // For cleanliness in chat UI, we usually don't show this, but here we just send it to API
         if (history == null || history.isEmpty) {
           // If no history, just prepend to current message
           message = "$systemContext\n\nUser Question: $message";
         } else {
           // If history exists, we need to ensure context is part of the flow. 
           // Best approach: Add a hidden first turn if possible, but simplest is to inject into the latest prompt for stateless REST
           // ACTUALLY, compliant way:
           // "contents": [ { "role": "user", "parts": [{"text": systemContext}] }, { "role": "model", "parts": [{"text": "Understood."}] }, ... history ... ]
           // A simpler hack: Prepend to the very first message in 'history' if it exists, or current message.
           // Let's go with prepending to current message to ensure it's always "fresh" in the context window.
           message = "CONTEXT:\n$systemContext\n\n---\n\nUser: $message";
         }
      }

      // 2. Add History
      if (history != null) {
        for (var msg in history) {
          contents.add({
            "role": msg['role'] ?? 'user', // 'user' or 'model'
            "parts": [{"text": msg['text']}]
          });
        }
      }

      // 3. Add Current Message
      contents.add({
        "role": "user",
        "parts": [{"text": message}]
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": contents
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
           final parts = data['candidates'][0]['content']['parts'];
           if (parts != null && parts.isNotEmpty) {
             return parts[0]['text'];
           }
        }
        return "I received your message but couldn't generate a meaningful response.";
      } else {
        // Detailed error for debugging
        debugPrint('Gemini API Error: ${response.body}');
        return "Connection Error (${response.statusCode}): ${response.body}";
      }
    } catch (e) {
      debugPrint('Gemini Network Error: $e');
      return "Network Error: ${e.toString()}";
    }
  }

}
