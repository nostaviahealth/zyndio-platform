import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

class HealthChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final Color color;
  final bool isSteps;

  const HealthChart({
    super.key,
    required this.data,
    required this.title,
    required this.color,
    this.isSteps = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    // Find max Y for scaling
    double maxY = 0;
    for (var d in data) {
      final val = (d['value'] ?? d['steps'] ?? 0).toDouble();
      if (val > maxY) maxY = val;
    }
    // Add buffer
    maxY = maxY * 1.2;
    if (maxY == 0) maxY = 100;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: context.nc.shadowColor,
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: context.nc.shadowColor.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: context.nc.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.nc.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          AspectRatio(
            aspectRatio: 1.70,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: context.nc.divider,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < data.length) {
                          // Show only specific indices for clean look if many points
                          if (data.length > 7 && index % 2 != 0) return const SizedBox.shrink();
                          
                          String text = '';
                          if (isSteps) {
                             text = data[index]['day'] ?? '';
                          } else {
                             // Time logic for heart rate
                             final date = data[index]['time'] as DateTime;
                             text = "${date.hour}:00";
                          }
                          return Text(
                              text,
                              style: TextStyle(
                                color: context.nc.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: context.nc.textSecondary,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.left,
                        );
                      },
                      reservedSize: 42,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (data.length - 1).toDouble(),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                      final val = (e.value['value'] ?? e.value['steps'] ?? 0).toDouble();
                      return FlSpot(e.key.toDouble(), val);
                    }).toList(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.5)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
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
}
