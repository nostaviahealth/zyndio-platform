import '../config/supabase_config.dart';

class MeditationRepository {
  static Future<List<Map<String, dynamic>>> fetchMeditationHistory({int limit = 14}) async {
    try {
      final client = SupabaseConfig.client;
      final userId = SupabaseConfig.currentUser?.id;
      
      if (client == null || userId == null) return [];

      final response = await client
          .from('meditation_sessions')
          .select('*')
          .eq('user_id', userId)
          .order('date', ascending: false)
          .limit(limit);

      return (response as List).map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      print('MeditationRepository: Failed to fetch history: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getMeditationStats() async {
    try {
      final client = SupabaseConfig.client;
      final userId = SupabaseConfig.currentUser?.id;
      
      if (client == null || userId == null) return {};

      final response = await client
          .from('meditation_sessions')
          .select('minutes')
          .eq('user_id', userId);

      final sessions = response as List;
      if (sessions.isEmpty) return {'totalMinutes': 0, 'sessionCount': 0};

      int totalMinutes = 0;
      for (var s in sessions) {
        totalMinutes += (s['minutes'] as num).toInt();
      }

      return {
        'totalMinutes': totalMinutes,
        'sessionCount': sessions.length,
      };
    } catch (e) {
      print('MeditationRepository: Failed to fetch stats: $e');
      return {};
    }
  }
}
