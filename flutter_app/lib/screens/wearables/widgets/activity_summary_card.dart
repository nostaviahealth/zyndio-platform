import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dashboard_card_style.dart';
import '../../../config/theme.dart';

/// Activity Summary card with time-range cumulative chart.
class ActivitySummaryCard extends StatelessWidget {
  final String totalTime; // e.g. "14h 49m"
  final String dateRange; // e.g. "26 Jan – 25 Feb 2026"
  final String previousTime; // e.g. "10h 21m"
  final List<double> activityData; // current 30 days cumulative
  final List<double> baselineData; // previous 30 days cumulative
  final List<String> dateLabels;
  final VoidCallback? onTap;

  const ActivitySummaryCard({
    super.key,
    required this.totalTime,
    required this.dateRange,
    this.previousTime = '',
    this.activityData = const [],
    this.baselineData = const [],
    this.dateLabels = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasChart = activityData.isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: DashboardCardStyle.decorationOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 20, color: context.nc.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Activity Summary',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.nc.textSecondary, 
                    ),
                  ),
                ),
                Icon(LucideIcons.arrowRight, size: 18, color: context.nc.textTertiary),
              ],
            ),
            const SizedBox(height: 12),
            // Total time
            Text(
              totalTime,
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: context.nc.textPrimary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            // Date range + previous comparison
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateRange,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.nc.textSecondary,
                    ),
                  ),
                ),
                if (previousTime.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: context.nc.textTertiary, // Grey circle
                          shape: BoxShape.circle,
                        ),
                        child: Icon(LucideIcons.arrowUp, size: 10, color: context.nc.textOnDark),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        previousTime,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.nc.textPrimary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),
            // Chart
            if (hasChart)
              SizedBox(
                height: 140,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true, // Show tick marks on x axis
                      getDrawingVerticalLine: (value) => FlLine(color: context.nc.divider.withOpacity(0.05), strokeWidth: 1.5, dashArray: [4, 4]),
                      horizontalInterval: _maxVal(activityData, baselineData) / 2 > 0 ? _maxVal(activityData, baselineData) / 2 : 10,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: context.nc.divider.withOpacity(0.05),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true, // Y axis on the right
                          reservedSize: 28,
                          interval: _maxVal(activityData, baselineData) / 2 > 0 ? _maxVal(activityData, baselineData) / 2 : 10,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '${value.toInt()}',
                              style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: dateLabels.isNotEmpty,
                          reservedSize: 24,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < dateLabels.length) {
                              // Show first, middle, last
                              if (idx == 0 || idx == dateLabels.length ~/ 2 || idx == dateLabels.length - 1) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    dateLabels[idx],
                                    style: TextStyle(fontSize: 12, color: context.nc.textTertiary, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          return touchedSpots.map((spot) {
                            // Only show tooltip for the activity line (index 1) or baseline if activity is empty (index 0)
                            if (baselineData.isNotEmpty && spot.barIndex != 1) return null;
                            
                            final idx = spot.x.toInt();
                            String dateStr = '';
                            if (idx >= 0 && idx < dateLabels.length) {
                              dateStr = dateLabels[idx];
                            }
                            
                            final h = spot.y.floor();
                            final m = ((spot.y - h) * 60).round();
                            final timeStr = '${h}h ${m}m';

                            return LineTooltipItem(
                              dateStr.isNotEmpty ? '$dateStr\n$timeStr' : timeStr,
                              TextStyle(color: context.nc.textOnDark, fontWeight: FontWeight.bold, fontSize: 12),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    lineBarsData: [
                      // Baseline line (grey) - drawn first so it's behind
                      if (baselineData.isNotEmpty)
                        LineChartBarData(
                          spots: baselineData.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), e.value);
                          }).toList(),
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: const Color(0xFFCBD5E1),
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) {
                              if (index == baselineData.length - 1) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: context.nc.isDark ? context.nc.divider : const Color(0xFFCBD5E1),
                                  strokeWidth: 0,
                                );
                              }
                              return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                            },
                          ),
                        ),
                      // Activity line (vibrant orange/red)
                      LineChartBarData(
                        spots: activityData.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value);
                        }).toList(),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: const Color(0xFFFF7E80), // Vibrant salmon/pink
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) {
                            return FlDotCirclePainter(
                              radius: 3,
                              color: context.nc.textOnDark,
                              strokeWidth: 2,
                              strokeColor: const Color(0xFFFF7E80),
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFFF7E80).withOpacity(0.15),
                              const Color(0xFFFF7E80).withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 140,
                alignment: Alignment.center,
                child: Text(
                  'Activity data will appear here',
                  style: TextStyle(fontSize: 12, color: context.nc.textTertiary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _maxVal(List<double> current, List<double> prev) {
    double mx = 0;
    if (current.isNotEmpty) mx = current.last;
    if (prev.isNotEmpty && prev.last > mx) mx = prev.last;
    if (mx <= 0) return 10; // Default max hours
    return mx * 1.25; // Provide headroom
  }
}

