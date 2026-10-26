import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

class RecoveryRadarChart extends StatelessWidget {
  final int steps;
  final double sleepHours;
  final double hrv;
  final int rhr;

  const RecoveryRadarChart({
    super.key,
    required this.steps,
    required this.sleepHours,
    required this.hrv,
    required this.rhr,
  });

  @override
  Widget build(BuildContext context) {
    // Check for complete lack of data
    final bool isEmpty = steps == 0 && sleepHours == 0.0 && hrv == 0.0 && rhr == 0;

    if (isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BrandColors.slate100,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.show_chart, color: BrandColors.slate400, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              "No Recovery Data",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: BrandColors.slate600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Wear your device to track sleep and activity for a complete recovery profile.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: BrandColors.slate400,
              ),
            ),
          ],
        ),
      );
    }

    // 1. Normalize Data (0.0 to 1.0 scale) based on "Ideal" goals
    // These goals could be dynamic based on user profile, but hardcoded for now as baseline.
    
    // Steps: Goal 10,000
    double stepsScore = (steps / 10000).clamp(0.0, 1.0);
    double visualSteps = steps == 0 ? 0.2 : stepsScore.clamp(0.2, 1.0);
    
    // Sleep: Goal 8 hours
    double sleepScore = (sleepHours / 8.0).clamp(0.0, 1.0);
    double visualSleep = sleepHours == 0 ? 0.2 : sleepScore.clamp(0.2, 1.0);
    
    // HRV: Higher is better. Let's assume 100ms is "Perfect" for general population (highly variable).
    // A better approach is usually vs baseline, but absolute for now.
    double hrvScore = (hrv / 100.0).clamp(0.0, 1.0);
    double visualHrv = hrv == 0 ? 0.2 : hrvScore.clamp(0.2, 1.0);
    
    // RHR: Lower is better. 
    // < 50 is elite (1.0). > 100 is poor (0.0).
    // Linear interpolation: 50 -> 1.0, 100 -> 0.0
    double rhrScore = 1.0 - ((rhr - 50) / 50.0).clamp(0.0, 1.0);
    double visualRhr = rhr == 0 ? 0.2 : rhrScore.clamp(0.2, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          AspectRatio(
            aspectRatio: 1.1, // Fixed squashed look
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor: BrandColors.indigo500.withOpacity(0.2),
                    borderColor: BrandColors.indigo500,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: visualSteps),
                      RadarEntry(value: visualSleep),
                      RadarEntry(value: visualHrv),
                      RadarEntry(value: visualRhr),
                    ],
                    borderWidth: 2,
                  ),
                ], // dataSets
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.transparent),
                titlePositionPercentageOffset: 0.1, // Pushed labels closer
                titleTextStyle: const TextStyle(
                  color: BrandColors.slate500, 
                  fontSize: 12, 
                  fontWeight: FontWeight.w600
                ),
                getTitle: (index, angle) {
                  switch (index) {
                    case 0:
                      return const RadarChartTitle(text: 'Activity');
                    case 1:
                      return const RadarChartTitle(text: 'Sleep');
                    case 2:
                      return const RadarChartTitle(text: 'HRV');
                    case 3:
                      return const RadarChartTitle(text: 'RHR');
                    default:
                      return const RadarChartTitle(text: '');
                  }
                },
                tickCount: 1,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                tickBorderData: const BorderSide(color: Colors.transparent),
                gridBorderData: BorderSide(color: BrandColors.slate200.withOpacity(0.5), width: 1),
              ),
              duration: const Duration(milliseconds: 400),
            ),
          ),
          const SizedBox(height: 4),
          // Legend / Values
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
               _buildLegendItem("Activity", steps == 0 ? "--%" : "${(stepsScore * 100).toInt()}%"),
               _buildLegendItem("Sleep", sleepHours == 0 ? "--h" : "${sleepHours}h"),
               _buildLegendItem("HRV", hrv == 0 ? "--ms" : "${hrv.toInt()}ms"),
               _buildLegendItem("RHR", rhr == 0 ? "--bpm" : "${rhr}bpm"),
            ],
          )
      ],
    );
  }

  Widget _buildLegendItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: BrandColors.dark,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: BrandColors.slate400,
          ),
        ),
      ],
    );
  }
}
