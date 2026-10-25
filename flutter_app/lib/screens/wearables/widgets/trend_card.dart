import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../config/theme.dart';

import 'dashboard_card_style.dart';

class TrendCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final List<double>? dataPoints; // For sparkline
  final VoidCallback onTap;

  const TrendCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.dataPoints,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate trend (last vs avg, or just simple direction)
    bool isPositive = true; 
    if (dataPoints != null && dataPoints!.length >= 2) {
        isPositive = dataPoints!.last >= dataPoints!.first;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: DashboardCardStyle.padding,
        decoration: DashboardCardStyle.decorationOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: BrandColors.slate500,
                      letterSpacing: 0.2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 14, color: BrandColors.slate300),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Value
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: BrandColors.dark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: BrandColors.slate400,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),

            // Sparkline or Trend
            if (dataPoints != null && dataPoints!.isNotEmpty)
              SizedBox(
                height: 30,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: dataPoints!.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value);
                        }).toList(),
                        isCurved: true,
                        color: color,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
               Row(
                 children: [
                   Icon(
                     isPositive ? LucideIcons.trendingUp : LucideIcons.trendingDown,
                     size: 14,
                     color: isPositive ? BrandColors.emerald500 : BrandColors.red500,
                   ),
                   const SizedBox(width: 4),
                   Text(
                     "Last 7 days",
                     style: TextStyle(
                       fontSize: 10,
                       color: BrandColors.slate400,
                     ),
                   )
                 ],
               )
          ],
        ),
      ),
    );
  }
}
