import '../config/supabase_config.dart';

/// Aggregates the user's recent food log history into a structured text block
/// suitable for injection into the AI system prompt.
///
/// This gives the intelligence awareness of what the user has been eating,
/// including Zyndio Scores, macros, toxins, and bio-impact flags.
class FoodContextService {
  /// Builds a comprehensive food log context string (last 7 days).
  /// Returns an empty string if no food logs exist.
  static Future<String> buildContext() async {
    final client = SupabaseConfig.client;
    if (client == null) return '';

    final userId = SupabaseConfig.currentUser?.id;
    if (userId == null) return '';

    try {
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final response = await client
          .from('food_logs')
          .select()
          .eq('user_id', userId)
          .gte('logged_at', sevenDaysAgo.toIso8601String())
          .order('logged_at', ascending: false);

      final logs = response as List;
      if (logs.isEmpty) return '';

      final buf = StringBuffer();
      buf.writeln('=== NUTRITION LOG (LAST 7 DAYS) ===');
      buf.writeln('The following are real meals the user has eaten, logged via food scan.');
      buf.writeln('Use this data when discussing diet, glucose impact, energy, or meal recommendations.');
      buf.writeln('Cross-reference with wearable data to detect food → physiology patterns.');
      buf.writeln('');

      // Track daily totals for summary
      final Map<String, List<Map<String, dynamic>>> byDate = {};

      for (final log in logs) {
        final loggedAt = DateTime.parse(log['logged_at'] as String);
        final dateKey = '${loggedAt.year}-${loggedAt.month.toString().padLeft(2, '0')}-${loggedAt.day.toString().padLeft(2, '0')}';
        byDate.putIfAbsent(dateKey, () => []).add(log);
      }

      for (final entry in byDate.entries) {
        final date = entry.key;
        final dayLogs = entry.value;

        buf.writeln('── $date ──');

        int dayCalories = 0;
        int dayProtein = 0;
        int dayCarbs = 0;
        int dayFat = 0;

        for (final log in dayLogs) {
          final analysis = log['analysis_json'] as Map<String, dynamic>? ?? {};
          final time = DateTime.parse(log['logged_at'] as String);
          final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

          final foodName = analysis['food_name'] ?? 'Unknown Meal';
          final calories = _toInt(analysis['calories']);
          final score = _toInt(analysis['score']);
          final macros = analysis['macros'] as Map<String, dynamic>? ?? {};
          final protein = _toInt(macros['protein']);
          final carbs = _toInt(macros['carbs']);
          final fat = _toInt(macros['fat']);
          final fiber = _toInt(macros['fiber']);
          final sugar = _toInt(macros['sugar']);

          dayCalories += calories;
          dayProtein += protein;
          dayCarbs += carbs;
          dayFat += fat;

          buf.write('  $timeStr — $foodName | ${calories}kcal');
          if (score > 0) buf.write(' | Score: $score/100');
          buf.write(' | P:${protein}g C:${carbs}g F:${fat}g Fiber:${fiber}g Sugar:${sugar}g');
          buf.writeln('');

          // Flag toxins if present
          final toxins = analysis['toxins'] as List?;
          if (toxins != null && toxins.isNotEmpty) {
            final highToxins = toxins.where((t) {
              final sev = (t['severity'] ?? '').toString().toLowerCase();
              return sev == 'high' || sev == 'warning' || sev == 'medium';
            }).toList();
            if (highToxins.isNotEmpty) {
              final names = highToxins.map((t) => t['name'] ?? 'Unknown').join(', ');
              buf.writeln('    ⚠ Toxins flagged: $names');
            }
          }

          // Flag negative bio-impacts if present
          final bioImpact = analysis['bio_impact'] as List?;
          if (bioImpact != null && bioImpact.isNotEmpty) {
            final negatives = bioImpact.where((b) =>
              (b['impact'] ?? '').toString().toLowerCase() == 'negative'
            ).toList();
            if (negatives.isNotEmpty) {
              final titles = negatives.map((b) => b['title'] ?? b['category'] ?? '').join(', ');
              buf.writeln('    ⚠ Negative bio-impact: $titles');
            }
          }
        }

        buf.writeln('  Daily Total: ${dayCalories}kcal | P:${dayProtein}g C:${dayCarbs}g F:${dayFat}g');
        buf.writeln('');
      }

      // Compute average Zyndio Score across all meals
      int totalScore = 0;
      int scoredMeals = 0;
      for (final log in logs) {
        final analysis = log['analysis_json'] as Map<String, dynamic>? ?? {};
        final score = _toInt(analysis['score']);
        if (score > 0) {
          totalScore += score;
          scoredMeals++;
        }
      }
      if (scoredMeals > 0) {
        buf.writeln('Average Zyndio Food Score: ${(totalScore / scoredMeals).round()}/100 (across $scoredMeals meals)');
      }
      buf.writeln('Total meals logged: ${logs.length}');
      buf.writeln('=== END NUTRITION LOG ===');

      return buf.toString();
    } catch (e) {
      print('FoodContextService error: $e');
      return '';
    }
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString()) ?? 0;
  }
}
