import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/daily_rhythm.dart';
import '../models/protocol_blueprint.dart';

/// Bottom sheet that shows a read-only review of a past day's actual
/// performance compared against the blueprint plan.
class DailyReviewSheet extends StatelessWidget {
  final BlueprintDay? blueprintDay;
  final DailyRhythm? actualRhythm;
  final int dayNumber;
  final DateTime date;

  const DailyReviewSheet({
    super.key,
    this.blueprintDay,
    this.actualRhythm,
    required this.dayNumber,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = '${_dayName(date.weekday)}, '
        '${_monthName(date.month)} ${date.day}';

    final tasks = actualRhythm?.tasks ?? blueprintDay?.tasks ?? [];
    final completedCount = tasks.where((t) => t.isCompleted).length;
    final totalCount = tasks.length;
    final completionRate = totalCount > 0 ? completedCount / totalCount : 0.0;

    final hasActualData = actualRhythm != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'Day $dayNumber',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Completion badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasActualData
                            ? _completionColor(completionRate).withOpacity(0.1)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasActualData
                                ? _completionIcon(completionRate)
                                : LucideIcons.minusCircle,
                            size: 12,
                            color: hasActualData
                                ? _completionColor(completionRate)
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasActualData
                                ? '${(completionRate * 100).round()}% Done'
                                : 'No Data',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasActualData
                                  ? _completionColor(completionRate)
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  dateStr,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                // Summary
                if (actualRhythm?.summary != null &&
                    actualRhythm!.summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      actualRhythm!.summary,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF064E3B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                // Progress bar
                if (hasActualData && totalCount > 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: completionRate,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _completionColor(completionRate),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$completedCount/$totalCount',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Task list
          Flexible(
            child: tasks.isEmpty
                ? _buildEmptyState(hasActualData)
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                    child: Column(
                      children: [
                        ...tasks.map((task) => _buildTaskTile(task)),
                        const SizedBox(height: 16),
                        // Info banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.info,
                                  size: 16, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasActualData
                                      ? 'This is your recorded activity for this day. Historical data is read-only.'
                                      : 'No rhythm was recorded for this day. This shows the planned blueprint.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool hasActualData) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasActualData ? LucideIcons.clipboardList : LucideIcons.calendar,
            size: 40,
            color: const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 12),
          Text(
            hasActualData
                ? 'No tasks were recorded for this day.'
                : 'No blueprint data available for this day.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTile(RhythmTask task) {
    final categoryColor = _categoryColor(task.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Completion indicator
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: task.isCompleted
                  ? categoryColor.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: task.isCompleted
                    ? categoryColor
                    : const Color(0xFFCBD5E1),
                width: 1.5,
              ),
            ),
            child: task.isCompleted
                ? Icon(LucideIcons.check, size: 14, color: categoryColor)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: task.isCompleted
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF0F172A),
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.detail != null && task.detail!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      task.detail!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (task.time != null && task.time!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                task.time!,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _completionColor(double rate) {
    if (rate >= 0.8) return const Color(0xFF10B981);
    if (rate >= 0.5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  IconData _completionIcon(double rate) {
    if (rate >= 0.8) return LucideIcons.checkCircle;
    if (rate >= 0.5) return LucideIcons.alertCircle;
    return LucideIcons.xCircle;
  }

  Color _categoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'diet':
        return const Color(0xFF6366F1);
      case 'fitness':
        return const Color(0xFFEF4444);
      case 'supplement':
        return const Color(0xFF10B981);
      case 'lifestyle':
      default:
        return const Color(0xFFA855F7);
    }
  }

  String _dayName(int weekday) {
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return days[(weekday - 1) % 7];
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[(month - 1) % 12];
  }
}
