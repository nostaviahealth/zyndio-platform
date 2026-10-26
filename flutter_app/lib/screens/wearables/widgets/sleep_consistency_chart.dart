import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

class SleepConsistencyChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklySleep;
  final double goalHours;

  const SleepConsistencyChart({
    super.key,
    required this.weeklySleep,
    this.goalHours = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 14, // Increased from 12 for headroom
          gridData: FlGridData(
            show: true, 
            drawVerticalLine: false,
            horizontalInterval: 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: BrandColors.slate100, 
              strokeWidth: 1
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < weeklySleep.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        weeklySleep[value.toInt()]['day'],
                        style: const TextStyle(
                          color: BrandColors.slate400, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: weeklySleep.asMap().entries.map((e) {
            final index = e.key;
            final data = e.value;
            double hours = (data['hours'] as num).toDouble();
            
            // Color logic: < 6h red, 6-7h orange, >7h green
            Color barColor = hours >= 7.0 
                ? BrandColors.emerald500 
                : (hours >= 6.0 ? BrandColors.orange500 : BrandColors.red500);

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: hours,
                  color: barColor,
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 10, // Background height
                    color: BrandColors.slate100.withOpacity(0.5),
                  ),
                ),
              ],
              showingTooltipIndicators: [0], 
            );
          }).toList(),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.transparent,
              tooltipPadding: EdgeInsets.zero,
              tooltipMargin: 4,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  rod.toY.toStringAsFixed(1),
                  const TextStyle(
                    color: BrandColors.slate500,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
           // Goal Line
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goalHours,
                color: BrandColors.indigo500.withOpacity(0.5),
                strokeWidth: 1,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                   show: true,
                   labelResolver: (line) => "Goal (${goalHours.toInt()}h)",
                   style: const TextStyle(
                     color: BrandColors.indigo500, 
                     fontSize: 10, 
                     fontWeight: FontWeight.bold
                   ),
                   alignment: Alignment.topRight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
