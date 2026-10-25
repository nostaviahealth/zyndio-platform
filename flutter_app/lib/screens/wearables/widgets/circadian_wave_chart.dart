import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

class CircadianWaveChart extends StatelessWidget {
  final TimeOfDay wakeTime; // Expected wake time to anchor the rhythm

  const CircadianWaveChart({
    super.key,
    this.wakeTime = const TimeOfDay(hour: 7, minute: 0),
  });

  @override
  Widget build(BuildContext context) {
    // Generate data points for 24 hours
    List<FlSpot> spots = [];
    final double wakeHour = wakeTime.hour + wakeTime.minute / 60.0;
    
    // Model: Review of circadian rhythm literature suggests:
    // Peak 1: ~3-4 hours after wake
    // Dip (Post-lunch): ~7-8 hours after wake
    // Peak 2: ~10-11 hours after wake
    // Sleep Dip: ~16+ hours after wake
    
    for (double i = 0; i <= 24; i += 0.5) {
      double hoursAfterWake = (i - wakeHour);
      if (hoursAfterWake < 0) hoursAfterWake += 24;
      
      // Simple dual-sine approximation for visual purposes
      // Energy = sin(t) + minor adjustments
      // This is a simplified "conceptual" model for the UI
      double val = sin((hoursAfterWake - 4) * pi / 12) + 0.5 * sin((hoursAfterWake - 10) * pi / 6);
      
      // Normalize to 0-1 range roughly and smooth
      double normalized = (val + 1.5) / 3.0; 
      spots.add(FlSpot(i, normalized.clamp(0.0, 1.0)));
    }

    final now = TimeOfDay.now();
    final double currentHour = now.hour + now.minute / 60.0;

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minY: -0.1, // Added headroom
          maxY: 1.1,  // Added headroom
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 6,
                getTitlesWidget: (value, meta) {
                  int h = value.toInt();
                  if (h == 24) h = 0;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "$h:00",
                      style: const TextStyle(
                        color: BrandColors.slate400,
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF6366F1), // Indigo/Purple 500
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.2),
                    const Color(0xFF6366F1).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            verticalLines: [
              VerticalLine(
                x: currentHour,
                color: BrandColors.orange500,
                strokeWidth: 2,
                dashArray: [5, 5],
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, top: 40),
                  style: const TextStyle(color: BrandColors.orange500, fontWeight: FontWeight.bold, fontSize: 10),
                  labelResolver: (line) => "NOW",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
