import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dashboard_card_style.dart';
import '../../../config/theme.dart';

/// Cardio Load card with sparkline chart. Matches WHOOP reference.
class CardioLoadCard extends StatelessWidget {
  final int cardioLoad; // e.g. 9
  final String status; // "Overtraining", "Optimal", "Detraining"
  final List<double> dataPoints;
  final VoidCallback? onTap;

  const CardioLoadCard({
    super.key,
    required this.cardioLoad,
    this.status = 'Optimal',
    this.dataPoints = const [],
    this.onTap,
  });

  Color get _statusColor {
    switch (status) {
      case 'Overtraining':
        return const Color(0xFFEF4444);
      case 'Detraining':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = cardioLoad > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: DashboardCardStyle.decorationOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(LucideIcons.heartPulse, size: 16, color: context.nc.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cardio Load',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.nc.textPrimary,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 18, color: const Color(0xFFCBD5E1)),
              ],
            ),
            const SizedBox(height: 16),
            // Value + sparkline row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasData ? '$cardioLoad' : '--',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: context.nc.textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      hasData ? status : (dataPoints.isNotEmpty ? 'Calibrating' : 'No data'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasData ? _statusColor : context.nc.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Sparkline chart
                if (dataPoints.isNotEmpty)
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: LineChart(
                        LineChartData(
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: dataPoints.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(), e.value);
                              }).toList(),
                              isCurved: true,
                              color: const Color(0xFF818CF8),
                              barWidth: 2.5,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  if (index == dataPoints.length - 1) {
                                    return FlDotCirclePainter(
                                      radius: 4,
                                      color: const Color(0xFFEC4899),
                                      strokeWidth: 2,
                                      strokeColor: Colors.white,
                                    );
                                  }
                                  return FlDotCirclePainter(
                                    radius: 0,
                                    color: Colors.transparent,
                                    strokeWidth: 0,
                                    strokeColor: Colors.transparent,
                                  );
                                },
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF818CF8).withOpacity(0.2),
                                    const Color(0xFF818CF8).withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      height: 60,
                      alignment: Alignment.center,
                      child: const Text(
                        'No chart data',
                        style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
