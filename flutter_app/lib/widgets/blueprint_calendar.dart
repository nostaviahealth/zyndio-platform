import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import '../config/theme.dart';
import '../models/daily_rhythm.dart';
import '../models/protocol_blueprint.dart';
import '../providers/blueprint_provider.dart';
import '../providers/consistency_provider.dart';
import '../providers/patient_provider.dart';
import 'blueprint_day_preview_sheet.dart';
import 'daily_review_sheet.dart';

/// Horizontal scrolling calendar showing the protocol blueprint timeline.
/// Past days show completion, today is highlighted, future days show blueprint preview.
class BlueprintCalendar extends ConsumerStatefulWidget {
  const BlueprintCalendar({super.key});

  @override
  ConsumerState<BlueprintCalendar> createState() => _BlueprintCalendarState();
}

class _BlueprintCalendarState extends ConsumerState<BlueprintCalendar> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToToday = false;

  /// Cloud-backed completion rates for the full protocol duration.
  /// Key: dayNumber (1-indexed), Value: completion rate (0.0–1.0).
  final Map<int, double> _completionRates = {};
  bool _isLoadingHistory = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll to today's position — only on first build or protocol change.
  void _scrollToToday(ProtocolBlueprint blueprint) {
    if (_hasScrolledToToday) return;

    final todayNum = blueprint.todayDayNumber;
    if (todayNum == null) return;

    // Each day cell is ~56px wide + 8px gap = 64px per slot
    final screenWidth = MediaQuery.of(context).size.width;
    final offset = (todayNum - 1) * 64.0 - (screenWidth / 2) + 28;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          offset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
        _hasScrolledToToday = true;
      }
    });
  }

  /// Load historical completion data from Supabase (cloud) and local cache.
  /// This ensures the timeline shows accurate checkmarks even for Week 1
  /// when the user is in Week 12.
  Future<void> _loadHistoricalCompletions(ProtocolBlueprint blueprint) async {
    if (_isLoadingHistory) return;
    _isLoadingHistory = true;

    try {
      final client = SupabaseConfig.client;
      if (client != null && client.auth.currentUser != null) {
        final userId = client.auth.currentUser!.id;
        final startStr =
            '${blueprint.startDate.year}-${blueprint.startDate.month.toString().padLeft(2, '0')}-${blueprint.startDate.day.toString().padLeft(2, '0')}';
        final now = DateTime.now();
        final endStr =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        final rows = await client
            .from('daily_rhythms')
            .select('date, tasks')
            .eq('user_id', userId)
            .gte('date', startStr)
            .lte('date', endStr);

        for (final row in rows) {
          final dateStr = row['date'] as String?;
          final tasks = row['tasks'] as List<dynamic>?;
          if (dateStr == null || tasks == null || tasks.isEmpty) continue;

          final date = DateTime.parse(dateStr);
          final dayNum = blueprint.dayNumberForDate(date);
          if (dayNum == null) continue;

          final completed =
              tasks.where((t) => t is Map && t['isCompleted'] == true).length;
          final rate = completed / tasks.length;

          _completionRates[dayNum] = rate;
        }
      }
    } catch (e) {
      debugPrint('BlueprintCalendar: Cloud history fetch failed: $e');
    }

    // Merge local SharedPreferences data for today and recent days
    // (more up-to-date than cloud for the current session)
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = ref.read(patientProfileProvider).value;
      final profileId = profile?.id ?? 'guest';

      final todayNum = blueprint.todayDayNumber ?? 0;
      // Check local cache for last 14 days or up to today
      final lookback = todayNum.clamp(0, 14);
      for (int i = 0; i < lookback; i++) {
        final dayNum = todayNum - i;
        if (dayNum < 1) break;

        final dayDate = blueprint.startDate.add(Duration(days: dayNum - 1));
        final key =
            'daily_rhythm_v2_${profileId}_${dayDate.year}-${dayDate.month}-${dayDate.day}';
        final jsonStr = prefs.getString(key);
        if (jsonStr != null) {
          try {
            final rhythm = DailyRhythm.fromJson(jsonDecode(jsonStr));
            final completed =
                rhythm.tasks.where((t) => t.isCompleted).length;
            final total = rhythm.tasks.length;
            if (total > 0) {
              _completionRates[dayNum] = completed / total;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('BlueprintCalendar: Local history merge failed: $e');
    }

    _isLoadingHistory = false;
    if (mounted) setState(() {});
  }

  /// Fetch the actual DailyRhythm for a past day to show in the review sheet.
  Future<DailyRhythm?> _fetchRhythmForDate(DateTime date) async {
    // Try local first
    try {
      final prefs = await SharedPreferences.getInstance();
      final profile = ref.read(patientProfileProvider).value;
      final profileId = profile?.id ?? 'guest';
      final key =
          'daily_rhythm_v2_${profileId}_${date.year}-${date.month}-${date.day}';
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        return DailyRhythm.fromJson(jsonDecode(jsonStr));
      }
    } catch (_) {}

    // Fallback to cloud
    try {
      final client = SupabaseConfig.client;
      if (client != null && client.auth.currentUser != null) {
        final userId = client.auth.currentUser!.id;
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        final response = await client
            .from('daily_rhythms')
            .select()
            .eq('user_id', userId)
            .eq('date', dateStr)
            .maybeSingle();

        if (response != null) {
          return DailyRhythm.fromJson({
            'id': response['id'],
            'date': response['date'],
            'summary': response['summary'],
            'tasks': response['tasks'],
          });
        }
      }
    } catch (_) {}

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bpState = ref.watch(blueprintProvider);
    final blueprint = bpState.blueprint;
    final consistency = ref.watch(consistencyProvider);

    if (blueprint == null) return const SizedBox.shrink();

    // Load cloud-backed history once
    if (_completionRates.isEmpty && !_isLoadingHistory) {
      Future.microtask(() => _loadHistoricalCompletions(blueprint));
    }

    // Scroll to today on first build
    _scrollToToday(blueprint);

    final todayNum = blueprint.todayDayNumber;
    final totalDays = blueprint.totalDays;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: context.nc.isDark ? 20 : 0,
            sigmaY: context.nc.isDark ? 20 : 0,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROTOCOL TIMELINE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.85),
                          letterSpacing: 2,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      todayNum != null
                          ? 'Day $todayNum of $totalDays'
                          : '$totalDays days planned',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Generation status badge
              _buildStatusBadge(bpState, blueprint),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Calendar Scroll
          SizedBox(
            height: 80,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: totalDays,
              itemBuilder: (context, index) {
                final dayNumber = index + 1;
                final dayDate = blueprint.startDate.add(Duration(days: index));
                final isToday = dayNumber == todayNum;
                final isPast = todayNum != null && dayNumber < todayNum;
                final isFuture = todayNum != null && dayNumber > todayNum;
                final blueprintDay = blueprint.getDayByNumber(dayNumber);
                final isGenerated = blueprintDay != null;

                // Week separator
                final isWeekStart = (dayNumber - 1) % 7 == 0;
                final weekNumber = ((dayNumber - 1) / 7).floor() + 1;

                // Completion rate: prefer cloud-backed data, fallback to consistency
                double completionRate = 0.0;
                if (isPast || isToday) {
                  if (_completionRates.containsKey(dayNumber)) {
                    completionRate = _completionRates[dayNumber]!;
                  } else {
                    // Fallback to local consistency data (last 7 days)
                    final dayData = consistency.weekHistory.firstWhere(
                      (d) =>
                          d.date.year == dayDate.year &&
                          d.date.month == dayDate.month &&
                          d.date.day == dayDate.day,
                      orElse: () => DayCompletion(date: dayDate),
                    );
                    completionRate = dayData.rate;
                  }
                }

                return Row(
                  children: [
                    // Week divider
                    if (isWeekStart && dayNumber > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 4, left: 4),
                        child: Container(
                          width: 2,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onTap: () => _handleDayTap(
                        context,
                        dayNumber: dayNumber,
                        dayDate: dayDate,
                        isToday: isToday,
                        isPast: isPast,
                        isFuture: isFuture,
                        isGenerated: isGenerated,
                        blueprintDay: blueprintDay,
                        blueprint: blueprint,
                      ),
                      child: Container(
                        width: 56,
                        margin: const EdgeInsets.only(right: 8),
                        child: Column(
                          children: [
                            // Week number (only on first day of week)
                            if (isWeekStart)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  'W$weekNumber',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.5),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              )
                            else
                              const SizedBox(height: 17),

                            // Day circle
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getDayColor(
                                    isToday, isPast, isFuture, completionRate, isGenerated),
                                shape: BoxShape.circle,
                                border: isToday
                                    ? Border.all(color: Colors.white, width: 1.5)
                                    : isFuture && isGenerated
                                        ? Border.all(
                                            color: Colors.white.withOpacity(0.1), width: 1)
                                        : isPast && completionRate > 0
                                            ? Border.all(
                                                color: _completionBorderColor(completionRate)
                                                    .withOpacity(0.3),
                                                width: 1)
                                            : null,
                                boxShadow: isToday
                                    ? [
                                        BoxShadow(
                                          color: Colors.white.withOpacity(0.35),
                                          blurRadius: 16,
                                          spreadRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: _getDayContent(
                                    isToday, isPast, isFuture, completionRate, dayNumber, isGenerated),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // Day label
                            Text(
                              isToday
                                  ? 'Today'
                                  : '${dayDate.day}/${dayDate.month}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                color: Colors.white.withOpacity(isToday ? 0.9 : 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Streak & Consistency Footer
          if (consistency.isLoaded && consistency.streakDays > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white.withOpacity(0.1), height: 1),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  const Icon(LucideIcons.flame, color: Color(0xFFF97316), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    '${consistency.streakDays} Day Streak',
                    style: TextStyle(
                      color: const Color(0xFFF97316),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Weekly Consistency: ${(consistency.weekConsistency * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
    ),
  ),
);
}

  /// Build the status badge (Syncing / Failed / Complete)
  Widget _buildStatusBadge(BlueprintState bpState, ProtocolBlueprint blueprint) {
    if (blueprint.status == BlueprintStatus.generating &&
        blueprint.weeksGenerated < blueprint.durationWeeks) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withOpacity(0.15),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                bpState.syncProgress ?? 'Syncing...',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8B5CF6),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (blueprint.status == BlueprintStatus.failed &&
        blueprint.weeksGenerated < blueprint.durationWeeks) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(blueprintProvider.notifier).retryGeneration();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.15),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(LucideIcons.refreshCw, color: Color(0xFFEF4444), size: 12),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Tap to retry',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (blueprint.isFullyGenerated) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5CF6).withOpacity(0.15),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.checkCircle,
                size: 12, color: const Color(0xFFA78BFA).withOpacity(0.8)),
            const SizedBox(width: 4),
            Text(
              'Complete',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFA78BFA).withOpacity(0.9),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// Handle tapping a day in the timeline.
  void _handleDayTap(
    BuildContext context, {
    required int dayNumber,
    required DateTime dayDate,
    required bool isToday,
    required bool isPast,
    required bool isFuture,
    required bool isGenerated,
    BlueprintDay? blueprintDay,
    required ProtocolBlueprint blueprint,
  }) async {
    HapticFeedback.lightImpact();

    if (isFuture && isGenerated) {
      // Future day with blueprint data → show preview sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlueprintDayPreviewSheet(blueprintDay: blueprintDay!),
      );
    } else if (isPast || isToday) {
      // Past day or today → show daily review sheet with actual data
      final rhythm = await _fetchRhythmForDate(dayDate);
      if (!context.mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DailyReviewSheet(
          blueprintDay: blueprintDay,
          actualRhythm: rhythm,
          dayNumber: dayNumber,
          date: dayDate,
        ),
      );
    } else if (isFuture && !isGenerated) {
      // Future day not yet generated → show a snackbar
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Day $dayNumber is still being generated. Check back soon!',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Color _getDayColor(bool isToday, bool isPast, bool isFuture, double rate, bool isGenerated) {
    if (isToday) return Colors.white;
    if (isPast) {
      if (rate >= 0.8) return const Color(0xFF10B981);
      if (rate >= 0.5) return const Color(0xFFF59E0B).withOpacity(0.40);
      if (rate > 0) return const Color(0xFFEF4444).withOpacity(0.35);
      return Colors.white.withOpacity(0.12);
    }
    // Future
    if (isGenerated) return Colors.white.withOpacity(0.20);
    return Colors.white.withOpacity(0.12);
  }

  Color _completionBorderColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF10B981);
    if (rate >= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _getDayContent(
      bool isToday, bool isPast, bool isFuture, double rate, int dayNumber, bool isGenerated) {
    if (isToday) {
      return Text(
        '$dayNumber',
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Color(0xFF4C1D95), // Deep violet text on white background
        ),
      );
    }
    if (isPast && rate >= 0.8) {
      return const Icon(LucideIcons.check,
          size: 16, color: Colors.white); // White check on solid green background
    }
    if (isPast && rate >= 0.5) {
      return Text(
        '${(rate * 100).round()}',
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFFF59E0B)),
      );
    }
    if (isPast && rate > 0) {
      return Text(
        '${(rate * 100).round()}',
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFFEF4444)),
      );
    }
    // Future or no data
    return Text(
      '$dayNumber',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white.withOpacity(isGenerated ? 0.9 : 0.5),
      ),
    );
  }
}
