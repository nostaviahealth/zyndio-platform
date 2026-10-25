import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../config/supabase_config.dart';
import 'azure_openai_service.dart';
import 'user_habit_service.dart';

/// A recalled memory fragment from the vector store.
class MemoryFragment {
  final String id;
  final String content;
  final String memoryType;
  final double similarity;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  MemoryFragment({
    required this.id,
    required this.content,
    required this.memoryType,
    required this.similarity,
    required this.createdAt,
    this.metadata,
  });

  factory MemoryFragment.fromJson(Map<String, dynamic> json) {
    return MemoryFragment(
      id: json['id']?.toString() ?? '',
      content: json['content'] ?? '',
      memoryType: json['memory_type'] ?? 'conversation_summary',
      similarity: (json['similarity'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      metadata: json['metadata'],
    );
  }
}

/// Service that handles storing and recalling long-term memories
/// via Supabase Edge Functions backed by pgvector.
class MemoryService {
  final AzureOpenAIService _aiService;

  MemoryService(this._aiService);

  String get _supabaseUrl => SupabaseConfig.url;
  String get _supabaseAnonKey => SupabaseConfig.anonKey;
  String? get _accessToken => SupabaseConfig.currentSession?.accessToken;
  String? get _userId => SupabaseConfig.currentUser?.id;

  /// Store a memory (conversation summary or user fact) in the vector store.
  Future<bool> storeMemory({
    required String content,
    String memoryType = 'conversation_summary',
    Map<String, dynamic>? metadata,
  }) async {
    if (_userId == null || content.trim().isEmpty) return false;

    try {
      final url = Uri.parse('$_supabaseUrl/functions/v1/embed-memory');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_accessToken ?? _supabaseAnonKey}',
          'apikey': _supabaseAnonKey,
        },
        body: jsonEncode({
          'user_id': _userId,
          'content': content,
          'memory_type': memoryType,
          'metadata': metadata ?? {},
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        debugPrint('RAG SUCCESS: Memory stored: ${content.substring(0, content.length.clamp(0, 50))}...');
        return true;
      } else {
        debugPrint('RAG ERROR: Store failed (${response.statusCode}): ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('RAG EXCEPTION: $e');
      return false;
    }
  }

  /// Recall relevant memories for a given query.
  Future<List<MemoryFragment>> recallMemories(String query, {int count = 5}) async {
    if (_userId == null || query.trim().isEmpty) return [];

    try {
      final url = Uri.parse('$_supabaseUrl/functions/v1/search-memory');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_accessToken ?? _supabaseAnonKey}',
          'apikey': _supabaseAnonKey,
        },
        body: jsonEncode({
          'user_id': _userId,
          'query': query,
          'match_count': count,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final memoriesJson = data['memories'] as List<dynamic>? ?? [];
        final memories = memoriesJson.map((m) => MemoryFragment.fromJson(m)).toList();
        debugPrint('Recalled ${memories.length} memories for query: "${query.substring(0, query.length.clamp(0, 40))}"');
        return memories;
      } else {
        debugPrint('Memory search failed: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('Memory recall error: $e');
      return [];
    }
  }

  /// Fetch all stored memories for the current user.
  Future<List<MemoryFragment>> fetchAllMemories() async {
    if (_userId == null) return [];

    try {
      final client = SupabaseConfig.client;
      if (client == null) return [];

      final response = await client
          .from('chat_memories')
          .select()
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      return (response as List).map((m) => MemoryFragment.fromJson(m)).toList();
    } catch (e) {
      debugPrint('Error fetching all memories: $e');
      return [];
    }
  }

  /// Delete a specific memory by its ID.
  Future<bool> deleteMemory(String id) async {
    if (_userId == null) return false;

    try {
      final client = SupabaseConfig.client;
      if (client == null) return false;

      await client.from('chat_memories').delete().eq('id', id).eq('user_id', _userId!);
      return true;
    } catch (e) {
      debugPrint('Error deleting memory: $e');
      return false;
    }
  }

  /// Extract discrete user facts from a conversation using AI.
  /// Returns a list of fact strings, e.g., ["User has a knee injury", "User is vegetarian"].
  Future<List<String>> extractFacts(List<Map<String, String>> conversationMessages) async {
    if (conversationMessages.length < 3) return []; // Need substance

    try {
      final messagesForAI = [
        {
          "role": "system",
          "content": """You are a fact extractor. Read the following health conversation and extract key PERMANENT facts about the user.
Rules:
- Extract only facts that would be useful to remember in FUTURE conversations.
- Focus on: health conditions, preferences, allergies, injuries, lifestyle habits, medications, goals.
- Do NOT extract transient things like "user said hello" or asked a question.
- Return a JSON array of strings. Each string is one fact.
- If no meaningful facts, return an empty array [].
- Maximum 5 facts per conversation.
Example output: ["User has Type 2 diabetes", "User is allergic to penicillin", "User prefers morning workouts"]"""
        },
        ...conversationMessages.map((m) => {
          "role": m['role'] == 'model' ? 'assistant' : m['role']!,
          "content": m['text']!,
        }),
      ];

      final response = await _aiService.callAzureAPI(
        messagesForAI.cast<Map<String, dynamic>>(),
        jsonMode: true,
      );

      if (response != null) {
        final decoded = jsonDecode(response);
        if (decoded is List) {
          return decoded.cast<String>();
        } else if (decoded is Map && decoded.containsKey('facts')) {
          return (decoded['facts'] as List).cast<String>();
        }
      }
    } catch (e) {
      debugPrint('Fact extraction error: $e');
    }
    return [];
  }

  /// High-level: Store both the summary and extracted facts from a conversation.
  Future<void> memorizeConversation({
    required String summary,
    required List<Map<String, String>> messages,
    required String sessionId,
  }) async {
    if (_userId == null) {
      debugPrint("RAG DEBUG: userId is null, cannot memorize.");
      return;
    }

    debugPrint("RAG DEBUG: Starting memorization for session $sessionId");

    final metadata = {
      'session_id': sessionId,
      'date': DateTime.now().toIso8601String(),
    };

    // 1. Store the conversation summary
    if (summary.isNotEmpty) {
      await storeMemory(
        content: summary,
        memoryType: 'conversation_summary',
        metadata: metadata,
      );
    }

    // 2. Extract and store individual facts (fire-and-forget)
    final facts = await extractFacts(messages);
    for (final fact in facts) {
      await storeMemory(
        content: fact,
        memoryType: 'user_fact',
        metadata: metadata,
      );
    }

    debugPrint('RAG DEBUG: Memorized conversation: summary + ${facts.length} facts');
  }

  /// ── ADAPTIVE EVOLUTION ENGINE ──
  /// Periodically sweep the habit profile and store high-level discoveries in long-term memory.
  Future<void> consolidateHabitInsights() async {
    try {
      final profile = await UserHabitService.generateProfile();
      final insights = <String>[];

      if (profile.weakestHabit != null) {
        insights.add("User struggles with ${profile.weakestHabit}");
      }
      if (profile.strongestHabit != null) {
        insights.add("User is very consistent with ${profile.strongestHabit}");
      }

      for (final e in profile.driftMinutesPerWeek.entries) {
        if (e.value.abs() > 15) {
          final direction = e.value > 0 ? 'later' : 'earlier';
          insights.add("User's ${e.key} time is drifting ${e.value.abs()} min $direction per week.");
        }
      }

      if (profile.sleepPerformanceCorrelation != null && profile.sleepPerformanceCorrelation!.abs() > 0.4) {
        final direction = profile.sleepPerformanceCorrelation! > 0 ? "positively" : "negatively";
        insights.add("User's sleep hours strongly $direction correlate with next-day protocol completion.");
      }

      for (final insight in insights) {
        await storeMemory(
          content: insight,
          memoryType: 'habit_insight',
          metadata: {'date': DateTime.now().toIso8601String()},
        );
      }
      debugPrint('RAG DEBUG: Consolidated ${insights.length} habit insights.');
    } catch (e) {
      debugPrint('Habit consolidation error: $e');
    }
  }
}

final memoryServiceProvider = Provider<MemoryService>((ref) {
  final aiService = AzureOpenAIService();
  return MemoryService(aiService);
});
