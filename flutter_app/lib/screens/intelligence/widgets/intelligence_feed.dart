import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../services/health_intelligence_service.dart';
import '../../../config/theme.dart';
import '../../../widgets/intelligence_glow_wrapper.dart';
import '../../../widgets/ask_intelligence_button.dart';
import '../../../providers/dynamic_insights_provider.dart';
import '../../wearables/widgets/dashboard_card_style.dart';

class IntelligenceFeed extends ConsumerWidget {
  final bool isImmersive;

  const IntelligenceFeed({super.key, required this.isImmersive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(dynamicInsightsProvider);

    return feedAsync.when(
      data: (insights) {
        if (insights.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(LucideIcons.activity, size: 48, color: BrandColors.slate300),
                  const SizedBox(height: 16),
                  const Text("We refer to this as the 'Quiet Zone'.", style: TextStyle(color: BrandColors.slate500)),
                  const Text("No immediate metabolic alerts.", style: TextStyle(color: BrandColors.slate400, fontSize: 13)),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: insights.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final insight = insights[index];
            if (insight.type == InsightType.summary) {
              return _buildSummaryCard(context, insight);
            }
            if (insight.type == InsightType.mission) {
              return _buildMissionCard(context, insight);
            }
            if (insight.type == InsightType.status) {
              return _buildStatusRibbon(context, insight);
            }
            if (insight.type == InsightType.energyForecast) {
              return _buildEnergyForecastCard(context, insight);
            }
            return _buildInsightCard(context, insight);
          },
        );
      },
      loading: () => const Center(child: Text("Preparing Insights...", style: TextStyle(color: BrandColors.slate400, fontSize: 13))),
      error: (e, st) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildMissionCard(BuildContext context, InsightCardData insight) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            insight.color,
            insight.color.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: insight.color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(insight.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'DAILY MISSION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight.title.replaceFirst('Daily Mission: ', ''),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            insight.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (insight.ctaLabel != null)
            GestureDetector(
              onTap: () {
                if (insight.ctaAction != null) context.push(insight.ctaAction!);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    insight.ctaLabel!,
                    style: TextStyle(
                      color: insight.color,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusRibbon(BuildContext context, InsightCardData insight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark Slate
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: insight.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: insight.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(insight.icon, color: insight.color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  insight.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, InsightCardData insight) {
    return IntelligenceGlowWrapper(
      borderRadius: 32,
      blurSigma: 20,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: insight.color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: insight.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(insight.icon, color: insight.color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: context.nc.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        _timeAgo(insight.timestamp),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.nc.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              insight.description,
              style: TextStyle(
                fontSize: 16,
                height: 1.6,
                color: context.nc.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            if (insight.suggestedQuestion != null)
              AskIntelligenceButton(
                onTap: () {
                  context.pushNamed('chat', queryParameters: {'initialMessage': insight.suggestedQuestion!});
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyForecastCard(BuildContext context, InsightCardData insight) {
    if (insight.graphData == null || insight.graphData!.isEmpty) return const SizedBox.shrink();
    
    final data = insight.graphData!;
    final now = DateTime.now();
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: DashboardCardStyle.decorationOf(context).copyWith(
        border: Border.all(color: BrandColors.slate200.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BrandColors.blue500.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.zap, color: BrandColors.blue500, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Energy Readiness',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: BrandColors.dark,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight.description,
            style: const TextStyle(
              fontSize: 14,
              color: BrandColors.slate500,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          // Enhanced Graph Widget
          SizedBox(
            height: 140,
            width: double.infinity,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: BrandColors.slate200.withOpacity(0.5),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 3, // Show title every 3 hours
                      getTitlesWidget: (value, meta) {
                        if (value % 3 != 0 || value >= data.length) return const SizedBox.shrink();
                        final time = now.add(Duration(hours: value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            value == 0 ? 'Now' : DateFormat('ha').format(time).toLowerCase(),
                            style: const TextStyle(
                              color: BrandColors.slate400,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: data.length.toDouble() - 1,
                minY: 0,
                maxY: 100,
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 80,
                      color: BrandColors.emerald500.withOpacity(0.4),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 5, bottom: 5),
                        style: const TextStyle(color: BrandColors.emerald500, fontSize: 10, fontWeight: FontWeight.bold),
                        labelResolver: (line) => 'Peak',
                      ),
                    ),
                    HorizontalLine(
                      y: 40,
                      color: BrandColors.orange500.withOpacity(0.4),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.bottomRight,
                        padding: const EdgeInsets.only(right: 5, top: 2),
                        style: const TextStyle(color: BrandColors.orange500, fontSize: 10, fontWeight: FontWeight.bold),
                        labelResolver: (line) => 'Dip',
                      ),
                    ),
                  ],
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                    isCurved: true,
                    color: BrandColors.blue500,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) => spot.x == 0,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: BrandColors.blue500,
                          strokeWidth: 2,
                          strokeColor: context.nc.cardSurface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          BrandColors.blue500.withOpacity(0.35),
                          BrandColors.blue500.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // AI Insight Bottom Strip
          if (insight.suggestedQuestion != null)
            AskIntelligenceButton(
              onTap: () {
                context.pushNamed('chat', queryParameters: {'initialMessage': insight.suggestedQuestion!});
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMiniGraph(List<double> data, Color color) {
    return Container(
      height: 80,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: data.length.toDouble() - 1,
          minY: data.reduce((a, b) => a < b ? a : b) - 5,
          maxY: data.reduce((a, b) => a > b ? a : b) + 5,
          lineBarsData: [
            LineChartBarData(
              spots: data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withOpacity(0.2),
                    color.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard(BuildContext context, InsightCardData insight) {
    final timeStr = _timeAgo(insight.timestamp);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: insight.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(insight.icon, size: 20, color: insight.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: BrandColors.dark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: BrandColors.slate400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight.description,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: BrandColors.slate700,
              height: 1.5,
              letterSpacing: -0.1,
            ),
          ),
          if (insight.type == InsightType.graph && insight.graphData != null) ...[
            const SizedBox(height: 16),
            _buildMiniGraph(insight.graphData!, insight.color),
          ],
          const SizedBox(height: 20),
          if (insight.suggestedQuestion != null || insight.ctaAction != null)
            Row(
              children: [
                if (insight.suggestedQuestion != null)
                  Expanded(
                    child: AskIntelligenceButton(
                      onTap: () {
                        context.pushNamed('chat', queryParameters: {'initialMessage': insight.suggestedQuestion!});
                      },
                    ),
                  ),
                if (insight.suggestedQuestion != null && insight.ctaAction != null)
                  const SizedBox(width: 12),
                if (insight.ctaAction != null)
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(insight.ctaAction!);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: insight.color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: insight.color.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.arrowRight, size: 14, color: insight.color),
                            const SizedBox(width: 8),
                            Text(
                              insight.ctaLabel ?? "View",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: insight.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
