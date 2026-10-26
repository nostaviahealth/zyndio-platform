import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../data/fixtures.dart';

/// C30 Trend chart: 358x176, range band + line + points, one accessibility
/// element (role image) whose label states every point as text so a screen
/// reader never needs the pixels (APP-06). The line never changes colour for
/// an above-range point — colour is carried by the badge/banner only.
class TrendChart extends StatelessWidget {
  const TrendChart(
      {super.key, required this.points, required this.rangeCeiling});

  final List<HbA1cPoint> points;
  final double rangeCeiling;

  String get accessibilityLabel {
    final parts = [
      for (final p in points)
        '${DateFormat('MMM d').format(p.date)} ${p.percent}%',
    ];
    return 'HbA1c chart: ${parts.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final values = points.map((p) => p.percent).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 0.5).floorToDouble();
    final maxY = (values.reduce((a, b) => a > b ? a : b) + 0.5).ceilToDouble();

    return Semantics(
      label: accessibilityLabel,
      image: true,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 358,
          height: ZyndioSize.chartHeight,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              minX: 0,
              // Half a point of blank room past the last point so its dot
              // and x-axis label sit inside the chart instead of clipping
              // at the right edge (~ZyndioSpace.s16 of visual clearance).
              maxX: (points.length - 1) + 0.5,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: 0.5,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: colors.borderSubtle, strokeWidth: 1),
              ),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  HorizontalRangeAnnotation(
                      y1: minY, y2: rangeCeiling, color: colors.chartRange),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 0.5,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) => Text(
                      value.toStringAsFixed(1),
                      style: ZyndioType.caption.copyWith(
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w400),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    // One tick per data point — without an explicit interval
                    // fl_chart picks its own (e.g. 0.5), which rounds two
                    // different x values to the same point index and repeats
                    // its label.
                    interval: 1,
                    // Enough room for the caption line plus descenders
                    // (e.g. "Apr 2"'s p) so labels never clip at the bottom.
                    reservedSize: ZyndioSpace.s32,
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= points.length) {
                        return const SizedBox.shrink();
                      }
                      // SideTitleWidget keeps edge labels (e.g. the last
                      // point's) shifted inward instead of overflowing the
                      // chart's own bounds.
                      return SideTitleWidget(
                        meta: meta,
                        child: Padding(
                          padding: const EdgeInsets.only(top: ZyndioSpace.s4),
                          child: Text(
                            DateFormat('MMM d').format(points[i].date),
                            style: ZyndioType.caption.copyWith(
                                color: colors.textTertiary,
                                fontWeight: FontWeight.w400),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < points.length; i++)
                      FlSpot(i.toDouble(), points[i].percent)
                  ],
                  isCurved: false,
                  color: colors.chartLine,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    getDotPainter: (spot, percent, bar, index) {
                      final isLatest = index == points.length - 1;
                      return FlDotCirclePainter(
                        radius: isLatest ? 6 : 4,
                        color: isLatest ? colors.chartLine : colors.bgSurface,
                        strokeWidth: 2.5,
                        strokeColor: colors.chartLine,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
