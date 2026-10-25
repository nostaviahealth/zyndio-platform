import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';

class ChatRepository {
  static const String _storageKey = 'chat_history';

  // Fetch all saved sessions
  static Future<List<ChatSession>> fetchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final sessions = jsonList.map((j) => ChatSession.fromJson(j)).toList();
      
      // Sort by date descending (newest first)
      sessions.sort((a, b) => b.date.compareTo(a.date));
      return sessions;
    } catch (e) {
      print('Error parsing chat history: $e');
      return [];
    }
  }

  // Save or Update a session
  static Future<void> saveSession(ChatSession session) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await fetchHistory();

    // Remove existing if present (to update it)
    sessions.removeWhere((s) => s.id == session.id);
    
    // Add updated session
    sessions.add(session);

    // Save back to storage
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
  
  // Get a specific session
  static Future<ChatSession?> getSession(String id) async {
    final sessions = await fetchHistory();
    try {
      return sessions.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  // Delete a session
  static Future<void> deleteSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await fetchHistory();
    
    sessions.removeWhere((s) => s.id == id);
    
    final jsonList = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  // Fetch summaries of recent sessions (limit to 5)
  static Future<List<String>> fetchRecentSummaries(int limit) async {
    final sessions = await fetchHistory();
    // Filter sessions that have a summary, take top N
    return sessions
        .where((s) => s.summary != null && s.summary!.isNotEmpty)
        .take(limit)
        .map((s) => "Date: ${s.date.toString().substring(0, 10)} | Summary: ${s.summary}")
        .toList();
  }
}
