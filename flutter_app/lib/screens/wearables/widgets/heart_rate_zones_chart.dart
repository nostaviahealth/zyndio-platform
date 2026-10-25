import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

class HeartRateZonesChart extends StatelessWidget {
  final List<Map<String, dynamic>> hrHistory;

  const HeartRateZonesChart({
    super.key,
    required this.hrHistory,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Bucket Data into Zones
    // Simplified Zones based on typical Max HR of 190 (Age 30)
    // Zone 1 (Rest): < 114
    // Zone 2 (Fat Burn): 114 - 133
    // Zone 3 (Cardio): 133 - 152
    // Zone 4 (Peak): > 152
    
    int restCount = 0;
    int fatBurnCount = 0;
    int cardioCount = 0;
    int peakCount = 0;
    
    for (var point in hrHistory) {
      int bpm = point['value'] as int;
      if (bpm < 114) {
        restCount++;
      } else if (bpm < 133) {
        fatBurnCount++;
      } else if (bpm < 152) {
        cardioCount++;
      } else {
        peakCount++;
      }
    }
    
    int total = restCount + fatBurnCount + cardioCount + peakCount;
    if (total == 0) return const SizedBox(); // No data

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Row(
            children: [
              // Pie Chart
              SizedBox(
                height: 140,
                width: 140,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: [
                      if (restCount > 0)
                        PieChartSectionData(
                          color: BrandColors.slate300,
                          value: restCount.toDouble(),
                          title: '${(restCount / total * 100).toInt()}%',
                          radius: 40,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (fatBurnCount > 0)
                        PieChartSectionData(
                          color: BrandColors.emerald500,
                          value: fatBurnCount.toDouble(),
                          title: '${(fatBurnCount / total * 100).toInt()}%',
                          radius: 45,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (cardioCount > 0)
                        PieChartSectionData(
                          color: BrandColors.orange500,
                          value: cardioCount.toDouble(),
                          title: '${(cardioCount / total * 100).toInt()}%',
                          radius: 50,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      if (peakCount > 0)
                         PieChartSectionData(
                          color: BrandColors.red500,
                          value: peakCount.toDouble(),
                          title: '${(peakCount / total * 100).toInt()}%',
                          radius: 55,
                          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem("Rest", "<114 bpm", BrandColors.slate300),
                    const SizedBox(height: 8),
                    _buildLegendItem("Fat Burn", "114-133", BrandColors.emerald500),
                    const SizedBox(height: 8),
                    _buildLegendItem("Cardio", "133-152", BrandColors.orange500),
                    const SizedBox(height: 8),
                    _buildLegendItem("Peak", ">152 bpm", BrandColors.red500),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildLegendItem(String label, String range, Color color) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: BrandColors.dark)),
            Text(range, style: const TextStyle(fontSize: 10, color: BrandColors.slate400)),
          ],
        )
      ],
    );
  }
}
