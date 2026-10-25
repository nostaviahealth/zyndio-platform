import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dashboard_card_style.dart';
import '../../../config/theme.dart';

/// Strain Performance card with sparkline and percentage.
/// Matches the WHOOP reference showing strain performance vs target.
class StrainPerformanceCard extends StatelessWidget {
  final int performancePercent; // e.g. -36 (below) or 15 (above)
  final String status; // "Below target", "On target", "Above target"
  final List<double> dataPoints;
  final VoidCallback? onTap;

  const StrainPerformanceCard({
    super.key,
    this.performancePercent = 0,
    this.status = 'No data',
    this.dataPoints = const [],
    this.onTap,
  });

  Color get _statusColor {
    if (performancePercent < 0) return const Color(0xFF06B6D4);
    if (performancePercent > 10) return const Color(0xFF10B981);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = dataPoints.isNotEmpty;
    // Show "Rest Day" instead of a stark -100% if the calculation hit the absolute bottom
    final String valueStr = performancePercent <= -100 
      ? 'Restful' 
      : (performancePercent > 0 ? '+$performancePercent%' : '$performancePercent%');
    final String statusStr = performancePercent <= -100 ? 'Recovery complete' : status;

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
                Icon(LucideIcons.zap, size: 16, color: context.nc.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Strain Performance',
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasData ? valueStr : '--%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: context.nc.textPrimary,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      statusStr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasData ? _statusColor : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                if (hasData)
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: LineChart(
                        LineChartData(
                          minY: -5, // Add padding so the curve doesn't clip the bottom edge
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: dataPoints.asMap().entries.map((e) {
                                return FlSpot(e.key.toDouble(), e.value);
                              }).toList(),
                              isCurved: true,
                              color: const Color(0xFF06B6D4),
                              barWidth: 2,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) {
                                  if (index == dataPoints.length - 1) {
                                    return FlDotCirclePainter(
                                      radius: 4,
                                      color: const Color(0xFF3B82F6),
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
                                    const Color(0xFF06B6D4).withOpacity(0.15),
                                    const Color(0xFF06B6D4).withOpacity(0.0),
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
                      height: 50,
                      alignment: Alignment.center,
                      child: const Text(
                        'No data yet',
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
