import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../config/supabase_config.dart';
import '../../widgets/app_card.dart';

/// Meditation stats record model
class MeditationStatsRecord {
  final String id;
  final DateTime date;
  final int minutes;
  final String mode;

  MeditationStatsRecord({
    required this.id,
    required this.date,
    required this.minutes,
    required this.mode,
  });

  factory MeditationStatsRecord.fromJson(Map<String, dynamic> json) {
    return MeditationStatsRecord(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      minutes: json['minutes'] as int,
      mode: json['mode'] as String? ?? 'void',
    );
  }
}

/// Meditation habits model
class SpaceHabits {
  final int dailyGoal;
  final bool spaceTheme;

  SpaceHabits({
    required this.dailyGoal,
    required this.spaceTheme,
  });

  factory SpaceHabits.fromJson(Map<String, dynamic> json) {
    return SpaceHabits(
      dailyGoal: json['daily_goal'] as int? ?? 10,
      spaceTheme: json['space_theme'] as bool? ?? false,
    );
  }
}

/// Provider for meditation stats
final meditationStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = SupabaseConfig.client;
  if (client == null) return {};

  final userId = SupabaseConfig.currentUser?.id;
  if (userId == null) return {};

  // Fetch sessions (last 30 days)
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
  final sessionsResponse = await client
      .from('meditation_sessions')
      .select()
      .eq('user_id', userId)
      .gte('date', thirtyDaysAgo.toIso8601String().split('T').first)
      .order('date', ascending: false);

  // Fetch habits
  final habitsResponse = await client
      .from('user_habits')
      .select()
      .eq('user_id', userId)
      .maybeSingle();

  final sessions = (sessionsResponse as List)
      .map((e) => MeditationStatsRecord.fromJson(e))
      .toList();

  final habits = habitsResponse != null
      ? SpaceHabits.fromJson(habitsResponse)
      : SpaceHabits(dailyGoal: 10, spaceTheme: false);

  // Calculate stats
  final today = DateTime.now();
  final todayStr = today.toIso8601String().split('T').first;
  final todayMinutes = sessions
      .where((s) => s.date.toIso8601String().split('T').first == todayStr)
      .fold<int>(0, (sum, s) => sum + s.minutes);

  final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.minutes);
  final totalSessions = sessions.length;

  // Calculate streak - logic fixed to count backward from today ensuring consecutive days
  int streak = 0;
  // If we meditated today, streak starts from today. If not, check yesterday.
  // Actually standard streak logic: if opened today and not done, streak is from yesterday.
  // If done today, streak includes today.
  // But for "current streak", if I missed yesterday, it's 0 (or 1 if I did it today).
  
  final uniqueDates = sessions.map((s) => s.date.toIso8601String().split('T').first).toSet();
  
  // Check if we have a session today
  bool doneToday = uniqueDates.contains(todayStr);
  if (doneToday) streak++;
  
  // Count backwards from yesterday
  DateTime cursor = today.subtract(const Duration(days: 1));
  while (true) {
    final dateStr = cursor.toIso8601String().split('T').first;
    if (uniqueDates.contains(dateStr)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    } else {
      break;
    }
  }

  // Weekly data for chart
  final weeklyData = <int>[];
  for (int i = 6; i >= 0; i--) {
    final day = today.subtract(Duration(days: i));
    final dayStr = day.toIso8601String().split('T').first;
    final dayMinutes = sessions
        .where((s) => s.date.toIso8601String().split('T').first == dayStr)
        .fold<int>(0, (sum, s) => sum + s.minutes);
    weeklyData.add(dayMinutes);
  }

  return {
    'sessions': sessions,
    'habits': habits,
    'todayMinutes': todayMinutes,
    'totalMinutes': totalMinutes,
    'totalSessions': totalSessions,
    'streak': streak,
    'weeklyData': weeklyData,
  };
});

/// Meditation Stats Screen
class MeditationStatsScreen extends ConsumerWidget {
  const MeditationStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(meditationStatsProvider);

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: Text('Meditation Stats', style: TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: context.nc.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: context.nc.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(meditationStatsProvider),
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: context.nc.textPrimary))),
          data: (stats) {
            if (stats.isEmpty) {
              return ListView.builder(
                itemCount: 2,
                itemBuilder: (context, index) {
                  if (index == 0) return const SizedBox(height: 100);
                  return Center(child: Text('No meditation data yet', style: TextStyle(color: context.nc.textSecondary)));
                },
              );
            }

            final habits = stats['habits'] as SpaceHabits;
            final todayMinutes = stats['todayMinutes'] as int;
            final totalMinutes = stats['totalMinutes'] as int;
            final totalSessions = stats['totalSessions'] as int;
            final streak = stats['streak'] as int;
            final weeklyData = stats['weeklyData'] as List<int>;
            final sessions = stats['sessions'] as List<MeditationStatsRecord>;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(), // Ensure refreshable even if content is short
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Today's Progress
                  _buildTodayProgress(context, todayMinutes, habits.dailyGoal),
                  const SizedBox(height: 24),
                  
                  // Stats Row
                  Row(
                    children: [
                      Expanded(child: _buildStatCard(context, 'Streak', '$streak', 'days', LucideIcons.flame, BrandColors.orange500)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(context, 'Total', '$totalMinutes', 'min', LucideIcons.clock, BrandColors.indigo500)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard(context, 'Sessions', '$totalSessions', '', LucideIcons.activity, BrandColors.emerald500)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Weekly Chart
                  Text(
                    'LAST 7 DAYS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.nc.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildWeeklyChart(context, weeklyData, habits.dailyGoal),
                  const SizedBox(height: 24),

                  // Recent Sessions
                  Text(
                    'RECENT SESSIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.nc.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (sessions.isEmpty)
                    Padding(
                       padding: const EdgeInsets.symmetric(vertical: 20),
                       child: Center(child: Text('No recent sessions', style: TextStyle(color: context.nc.textSecondary))),
                    )
                  else
                    ...sessions.take(10).map((s) => _buildSessionTile(context, s)),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTodayProgress(BuildContext context, int minutes, int goal) {
    final progress = (minutes / goal).clamp(0.0, 1.0);
    final isComplete = minutes >= goal;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Goal",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.nc.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete ? BrandColors.emerald500.withOpacity(0.1) : context.nc.inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isComplete ? '✓ Complete' : '$minutes / $goal min',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isComplete ? BrandColors.emerald500 : context.nc.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: context.nc.inputFill,
              valueColor: AlwaysStoppedAnimation(
                isComplete ? BrandColors.emerald500 : BrandColors.indigo500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, String unit, IconData icon, Color color) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.nc.textPrimary,
            ),
          ),
          Text(
            unit.isEmpty ? label : '$label ($unit)',
            style: TextStyle(
              fontSize: 10,
              color: context.nc.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, List<int> data, int goal) {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday; // 1 = Monday
    
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: (goal * 1.5).toDouble(),
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final dayIndex = (today - 7 + value.toInt()) % 7;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        days[dayIndex],
                        style: TextStyle(
                          fontSize: 10,
                          color: context.nc.textTertiary,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: data.asMap().entries.map((entry) {
              final isToday = entry.key == 6;
              return BarChartGroupData(
                x: entry.key,
                barRods: [
                  BarChartRodData(
                    toY: entry.value.toDouble(),
                    color: isToday ? BrandColors.indigo500 : context.nc.textTertiary.withOpacity(0.2),
                    width: 24,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionTile(BuildContext context, MeditationStatsRecord session) {
    final modeIcons = {
      'void': LucideIcons.moon,
      'flow': LucideIcons.wind,
      'focus': LucideIcons.target,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: BrandColors.indigo500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                modeIcons[session.mode] ?? LucideIcons.moon,
                size: 18,
                color: BrandColors.indigo500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${session.minutes} minutes',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.nc.textPrimary,
                    ),
                  ),
                  Text(
                    session.mode.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.nc.textTertiary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatDate(session.date),
              style: TextStyle(
                fontSize: 12,
                color: context.nc.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(date.year, date.month, date.day);
    
    if (sessionDay == today) return 'Today';
    if (sessionDay == today.subtract(const Duration(days: 1))) return 'Yesterday';
    
    return '${date.day}/${date.month}';
  }
}
