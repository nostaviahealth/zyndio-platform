import 'package:flutter/material.dart';
import 'dashboard_card_style.dart';
import '../../../config/theme.dart';

/// Activity Calendar Heatmap showing months of activity data.
/// Matches the WHOOP Fitness reference with green squares for activity days.
class ActivityCalendarHeatmap extends StatelessWidget {
  final Map<DateTime, int> activityDays; // date → activity count (1, 2, 3+)
  final DateTime? startDate;
  final DateTime? endDate;

  const ActivityCalendarHeatmap({
    super.key,
    this.activityDays = const {},
    this.startDate,
    this.endDate,
  });

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  Color _cellColor(int count, bool isDark) {
    if (count <= 0) return isDark ? const Color(0x1AFFFFFF) : const Color(0xFFF1F5F9);
    if (count == 1) return const Color(0xFF86EFAC); // light green
    if (count == 2) return const Color(0xFF22C55E); // medium green  
    return const Color(0xFF15803D); // dark green (3+)
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month1 = DateTime(now.year, now.month - 1, 1);
    final month2 = DateTime(now.year, now.month, 1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Two months side by side
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildMonth(context, month1)),
              const SizedBox(width: 16),
              Expanded(child: _buildMonth(context, month2)),
            ],
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendItem(context, 1, '1 activity'),
              const SizedBox(width: 16),
              _legendItem(context, 2, '2 activities'),
              const SizedBox(width: 16),
              _legendItem(context, 3, '3+ activities'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonth(BuildContext context, DateTime month) {
    final monthName = '${_monthNames[month.month - 1]} ${month.year}';
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = DateTime(month.year, month.month, 1).weekday % 7; // 0=Sun
    final isDark = context.nc.isDark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          monthName,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.nc.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        // Day headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _dayNames.map((d) => SizedBox(
            width: 18,
            child: Center(
              child: Text(
                d,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: context.nc.textSecondary,
                ),
              ),
            ),
          )).toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        ...List.generate(_weeksInMonth(daysInMonth, firstWeekday), (weekIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (dayIndex) {
                final dayNum = weekIndex * 7 + dayIndex - firstWeekday + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox(width: 18, height: 18);
                }
                final date = DateTime(month.year, month.month, dayNum);
                final count = activityDays[DateTime(date.year, date.month, date.day)] ?? 0;
                final isToday = date.year == DateTime.now().year && 
                                date.month == DateTime.now().month && 
                                date.day == DateTime.now().day;

                return Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _cellColor(count, isDark),
                    borderRadius: BorderRadius.circular(3),
                    border: isToday ? Border.all(color: const Color(0xFF3B82F6), width: 1.5) : null,
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  int _weeksInMonth(int daysInMonth, int firstWeekday) {
    return ((daysInMonth + firstWeekday + 6) / 7).floor();
  }

  Widget _legendItem(BuildContext context, int count, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _cellColor(count, context.nc.isDark),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.nc.textSecondary,
          ),
        ),
      ],
    );
  }
}
