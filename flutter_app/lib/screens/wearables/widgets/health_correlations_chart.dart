import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../config/theme.dart';

class HealthCorrelationsChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklySteps;
  final List<Map<String, dynamic>> weeklySleep;

  const HealthCorrelationsChart({
    super.key,
    required this.weeklySteps,
    required this.weeklySleep,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Correlate Data by Date
    // Format: (Steps, Sleep Hours)
    List<ScatterSpot> spots = [];
    
    // Create a map for quick lookup
    Map<String, double> sleepMap = {};
    for (var s in weeklySleep) {
      // Key: "2023-10-27" (simplified)
      final date = s['date'] as DateTime;
      final key = "${date.year}-${date.month}-${date.day}";
      sleepMap[key] = (s['hours'] as num).toDouble();
    }
    
    for (int i = 0; i < weeklySteps.length; i++) {
        final stepData = weeklySteps[i];
        final date = stepData['date'] as DateTime;
        final key = "${date.year}-${date.month}-${date.day}";
        
        final steps = (stepData['steps'] as num).toDouble();
        final sleep = sleepMap[key];
        
        if (sleep != null && sleep > 0 && steps > 0) {
            // Plot: X = Steps, Y = Sleep
            // To make visual nicer, scale X.
            spots.add(ScatterSpot(
                steps, 
                sleep,
                dotPainter: FlDotCirclePainter(
                    radius: 6,
                    color: BrandColors.indigo500,
                    strokeColor: Colors.white,
                    strokeWidth: 2,
                ),
            ));
        }
    }

    if (spots.isEmpty) return const SizedBox();

    // Determine Axis ranges dynamically
    double minX = 0;
    double maxX = 15000;
    double minY = 4;
    double maxY = 12;

    if (spots.isNotEmpty) {
        var xValues = spots.map((e) => e.x);
        var yValues = spots.map((e) => e.y);
        
        // Add some padding
        minX = (xValues.reduce((curr, next) => curr < next ? curr : next) - 1000).clamp(0, double.infinity);
        maxX = (xValues.reduce((curr, next) => curr > next ? curr : next) + 1000);
        minY = (yValues.reduce((curr, next) => curr < next ? curr : next) - 1).clamp(0, double.infinity);
        maxY = (yValues.reduce((curr, next) => curr > next ? curr : next) + 1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: ScatterChart(
              ScatterChartData(
                scatterSpots: spots,
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  verticalInterval: 2000,
                  getDrawingHorizontalLine: (value) => FlLine(color: BrandColors.slate100),
                  getDrawingVerticalLine: (value) => FlLine(color: BrandColors.slate100),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    axisNameWidget: const Text("Daily Steps", style: TextStyle(fontSize: 10, color: BrandColors.slate400)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                          if (value % 2000 == 0) {
                              return Text("${(value/1000).toInt()}k", style: const TextStyle(fontSize: 10, color: BrandColors.slate400));
                          }
                          return const SizedBox();
                      },
                    ),
                  ),
                   leftTitles: AxisTitles(
                    axisNameWidget: const Text("Sleep (h)", style: TextStyle(fontSize: 10, color: BrandColors.slate400)),
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                          return Text("${value.toInt()}h", style: const TextStyle(fontSize: 10, color: BrandColors.slate400));
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                scatterTouchData: ScatterTouchData(
                    touchTooltipData: ScatterTouchTooltipData(
                        getTooltipColor: (_) => BrandColors.dark,
                        getTooltipItems: (ScatterSpot spot) {
                            return ScatterTooltipItem(
                                "Steps: ${spot.x.toInt()}\nSleep: ${spot.y.toStringAsFixed(1)}h",
                                textStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                bottomMargin: 10,
                            );
                        }
                    ),
                ),
              ),
            ),
          ),
           const SizedBox(height: 16),
           Container(
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: BrandColors.indigo100,
               borderRadius: BorderRadius.circular(12),
             ),
             child: const Row(
               children: [
                 Icon(LucideIcons.lightbulb, size: 16, color: BrandColors.indigo500),
                 SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     "More steps generally correlate with longer, deeper sleep.",
                     style: TextStyle(fontSize: 12, color: BrandColors.indigo500, fontWeight: FontWeight.w600),
                   ),
                 )
               ],
             ),
           )
      ],
    );
  }
}
