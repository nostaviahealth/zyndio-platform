import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../config/theme.dart';
import '../../../config/supabase_config.dart';
import '../../wearables/widgets/dashboard_card_style.dart';

/// Provides a simulated metabolic energy curve based on today's food logs, and a bool if real data is present.
final sparklineDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = SupabaseConfig.client;
  final userId = SupabaseConfig.currentUser?.id;
  if (client == null || userId == null) return {'spots': _generateDefaultCurve(), 'hasData': false};

  try {
    final todayStart = DateTime.now().toUtc().subtract(const Duration(hours: 24));
    final response = await client
        .from('food_logs')
        .select()
        .eq('patient_id', userId)
        .gte('logged_at', todayStart.toIso8601String());

    final logs = response as List;
    if (logs.isEmpty) return {'spots': _generateDefaultCurve(), 'hasData': false};

    List<FlSpot> spots = [];
    final now = DateTime.now().toUtc();

    // Generate curve from -4 hours to +4 hours
    for (int i = -4; i <= 4; i++) {
      double timeOffset = i.toDouble();
      
      // Base circadian energy mimicking a daytime plateau
      double baseEnergy = 60.0;
      
      // Calculate food impacts
      for (var log in logs) {
        final loggedAt = DateTime.parse(log['logged_at'] as String);
        final diffHours = loggedAt.difference(now).inMinutes / 60.0;
        
        // Glucose/Energy peak is ~1 hour after eating
        final peakTime = diffHours + 1.0;
        final distToPeak = (timeOffset - peakTime).abs();
        
        if (distToPeak < 2.5) {
          final analysis = log['analysis'] ?? log['analysis_json'] ?? {};
          final macros = analysis['macros'] ?? {};
          final carbs = int.tryParse(macros['carbs']?.toString() ?? '30') ?? 30;
          final protein = int.tryParse(macros['protein']?.toString() ?? '15') ?? 15;
          
          // Carbs cause higher spike, protein flattens it
          double spikeMagnitude = (carbs / 50.0) * 35.0; // Max ~35 pts
          double dampening = (protein / 30.0) * 10.0; // Subtract up to 10 pts
          
          double bump = (spikeMagnitude - dampening).clamp(10.0, 40.0);
          
          // ease-in-out shape for the bump
          double multiplier = 1.0 - (distToPeak / 2.5);
          baseEnergy += (bump * multiplier);
        }
      }

      spots.add(FlSpot(timeOffset, baseEnergy.clamp(20, 100)));
    }
    return {'spots': spots, 'hasData': true};
  } catch (e) {
    print('Sparkline Error: $e');
    return {'spots': _generateDefaultCurve(), 'hasData': false};
  }
});

List<FlSpot> _generateDefaultCurve() {
  return [
    const FlSpot(-4, 45),
    const FlSpot(-3, 55),
    const FlSpot(-2, 65),
    const FlSpot(-1, 80),
    const FlSpot(0, 75),
    const FlSpot(1, 65),
    const FlSpot(2, 55),
    const FlSpot(3, 45),
    const FlSpot(4, 40),
  ];
}

class MetabolicSparkline extends ConsumerWidget {
  final bool isImmersive;

  const MetabolicSparkline({super.key, required this.isImmersive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spotsAsync = ref.watch(sparklineDataProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          spotsAsync.when(
            data: (data) {
              final spots = data['spots'] as List<FlSpot>;
              final hasData = data['hasData'] as bool;
              
              // Determine current status
              final currentEnergy = spots.firstWhere((s) => s.x == 0).y;
              final futureEnergy = spots.last.y;
              final isCrashing = hasData ? (futureEnergy < currentEnergy - 15) : false;
              final statusColor = hasData 
                  ? (isCrashing ? const Color(0xFFF97316) : const Color(0xFF10B981))
                  : const Color(0xFFCBD5E1);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Glucose Stability',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: context.nc.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.nc.inputFill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '4hr Forecast',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  const Text(
                    'Real-time glucose & energy predictions',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Chart Area ──
                  if (hasData)
                    Column(
                      children: [
                        SizedBox(
                          height: 120,
                          child: LineChart(
                            LineChartData(
                              minX: -4,
                              maxX: 4,
                              minY: 0,
                              maxY: 100,
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineTouchData: const LineTouchData(enabled: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: spots,
                                  isCurved: true,
                                  color: statusColor,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: FlDotData(
                                    show: true,
                                    checkToShowDot: (spot, barData) => spot.x == 0,
                                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                      radius: 4,
                                      color: context.nc.cardSurface,
                                      strokeWidth: 2,
                                      strokeColor: statusColor,
                                    ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        statusColor.withOpacity(0.15),
                                        statusColor.withOpacity(0.0),
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
                                    x: 0,
                                    color: context.nc.divider,
                                    strokeWidth: 1,
                                    dashArray: [4, 4],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('-4h', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            Text('Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                            Text('+4h', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ],
                    )
                  else
                    // Empty state for chart
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: context.nc.scaffoldBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.nc.cardBorder),
                      ),
                      child: Center(
                        child: Text(
                          'Awaiting metabolic input...',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  // ── Insight box ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: hasData 
                          ? statusColor.withOpacity(0.05)
                          : context.nc.scaffoldBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.nc.cardBorder),
                    ),
                    child: Text(
                      hasData 
                          ? (isCrashing 
                              ? 'Post-meal crash predicted. Consider a 10-minute walk to stabilize insulin.'
                              : 'Energy levels expected to remain stable. Good time for focused work.')
                          : 'Log your meals to see real-time glucose and energy predictions.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: hasData ? context.nc.textPrimary : context.nc.textTertiary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('Error: $err'),
          ),
        ],
      ),
    );
  }
}
