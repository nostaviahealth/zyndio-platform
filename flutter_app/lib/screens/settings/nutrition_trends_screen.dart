import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../models/food_log.dart';
import '../../models/food_analysis.dart';
import '../../providers/nutrition_goals_provider.dart';
import '../../providers/lens_provider.dart';
import '../../providers/navbar_provider.dart';
import '../../config/theme.dart';
import 'lens_history_screen.dart'; // For foodLogsProvider

class NutritionTrendsScreen extends ConsumerStatefulWidget {
  const NutritionTrendsScreen({super.key});

  @override
  ConsumerState<NutritionTrendsScreen> createState() => _NutritionTrendsScreenState();
}

class _NutritionTrendsScreenState extends ConsumerState<NutritionTrendsScreen> {
  int _selectedTab = 0; // 0=Calories, 1=Protein, 2=Carbs, 3=Fat
  final List<String> _tabs = ['Calories', 'Protein', 'Carbs', 'Fat'];

  @override
  void initState() {
    super.initState();
    // Hide navbar when entering this immersive screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navbarVisibleProvider.notifier).hide();
    });
  }

  @override
  void dispose() {
    // Immediate restoration to ensure it's visible when the parent builds
    ref.read(navbarVisibleProvider.notifier).show();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(foodLogsProvider);
    final goals = ref.watch(nutritionGoalsProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          ref.read(navbarVisibleProvider.notifier).show();
        }
      },
      child: Scaffold(
      backgroundColor: context.nc.isDark ? context.nc.scaffoldBg : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: context.nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nutrition Trends',
          style: TextStyle(
            color: context.nc.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: logsAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return Center(
              child: Text(
                'No food logs available to show trends.',
                style: TextStyle(color: context.nc.textSecondary),
              ),
            );
          }

          // Group by date
          final Map<DateTime, Map<String, double>> dailyTotals = {};
          
          for (final log in logs) {
            final date = DateTime(log.loggedAt.year, log.loggedAt.month, log.loggedAt.day);
            final analysis = FoodAnalysis.fromJson(log.analysis);
            
            if (!dailyTotals.containsKey(date)) {
              dailyTotals[date] = {'cal': 0, 'pro': 0, 'carb': 0, 'fat': 0};
            }
            
            dailyTotals[date]!['cal'] = dailyTotals[date]!['cal']! + analysis.calories;
            dailyTotals[date]!['pro'] = dailyTotals[date]!['pro']! + analysis.macros.protein.toDouble();
            dailyTotals[date]!['carb'] = dailyTotals[date]!['carb']! + analysis.macros.carbs.toDouble();
            dailyTotals[date]!['fat'] = dailyTotals[date]!['fat']! + analysis.macros.fat.toDouble();
          }

          // Sort dates
          final sortedDates = dailyTotals.keys.toList()..sort();
          
          // Take last 7 days
          final last7Days = sortedDates.length > 7 ? sortedDates.sublist(sortedDates.length - 7) : sortedDates;

          return Column(
            children: [
              _buildTabBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildChartCard(last7Days, dailyTotals, goals),
                      const SizedBox(height: 24),
                      _buildAverageStats(last7Days, dailyTotals, goals),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    ));
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 44,
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.nc.cardBorder),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isSelected ? context.nc.textPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    color: isSelected ? context.nc.scaffoldBg : context.nc.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChartCard(
    List<DateTime> dates,
    Map<DateTime, Map<String, double>> dailyTotals,
    NutritionGoals goals,
  ) {
    String metricKey;
    double target;
    Color barColor;
    String unit;

    switch (_selectedTab) {
      case 0:
        metricKey = 'cal';
        target = goals.calorieGoal;
        barColor = const Color(0xFFF59E0B); // Amber
        unit = 'kcal';
        break;
      case 1:
        metricKey = 'pro';
        target = goals.proteinGoal;
        barColor = const Color(0xFF10B981); // Emerald
        unit = 'g';
        break;
      case 2:
        metricKey = 'carb';
        target = goals.carbGoal;
        barColor = const Color(0xFF6366F1); // Indigo
        unit = 'g';
        break;
      case 3:
      default:
        metricKey = 'fat';
        target = goals.fatGoal;
        barColor = const Color(0xFFEF4444); // Red
        unit = 'g';
        break;
    }

    double maxY = target * 1.5;
    for (var date in dates) {
      if (dailyTotals[date]![metricKey]! > maxY) {
        maxY = dailyTotals[date]![metricKey]!;
      }
    }
    // Add 10% padding
    maxY *= 1.1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.nc.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily ${_tabs[_selectedTab]}',
                style: TextStyle(
                  color: context.nc.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: barColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Target: ${target.round()}$unit',
                  style: TextStyle(
                    color: barColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: target > 0 ? target / 2 : 100,
                  getDrawingHorizontalLine: (value) {
                    if (value == target) {
                      return FlLine(
                        color: barColor.withValues(alpha: 0.5),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      );
                    }
                    return FlLine(
                      color: context.nc.divider.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value == maxY || value == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            value.round().toString(),
                            style: TextStyle(color: context.nc.textTertiary, fontSize: 11),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dates.length) return const SizedBox.shrink();
                        final date = dates[index];
                        final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month;
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            isToday ? 'Today' : DateFormat('EEE').format(date),
                            style: TextStyle(
                              color: isToday ? context.nc.textPrimary : context.nc.textSecondary,
                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: dates.asMap().entries.map((e) {
                  final index = e.key;
                  final date = e.value;
                  final val = dailyTotals[date]![metricKey]!;
                  
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: val > target * 1.1 ? const Color(0xFFEF4444) : barColor, // Red if over 10% target
                        width: 16,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: context.nc.cardSurfaceElevated,
                        ),
                      ),
                    ],
                  );
                }).toList(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF1E293B),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.round()}$unit',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageStats(
    List<DateTime> dates,
    Map<DateTime, Map<String, double>> dailyTotals,
    NutritionGoals goals,
  ) {
    if (dates.isEmpty) return const SizedBox.shrink();

    String metricKey;
    double target;
    String unit;

    switch (_selectedTab) {
      case 0:
        metricKey = 'cal';
        target = goals.calorieGoal;
        unit = 'kcal';
        break;
      case 1:
        metricKey = 'pro';
        target = goals.proteinGoal;
        unit = 'g';
        break;
      case 2:
        metricKey = 'carb';
        target = goals.carbGoal;
        unit = 'g';
        break;
      case 3:
      default:
        metricKey = 'fat';
        target = goals.fatGoal;
        unit = 'g';
        break;
    }

    double sum = 0;
    for (var date in dates) {
      sum += dailyTotals[date]![metricKey]!;
    }
    final avg = sum / dates.length;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.nc.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.nc.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('7-Day Avg', style: TextStyle(color: context.nc.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '${avg.round()}$unit',
                  style: TextStyle(color: context.nc.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.nc.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.nc.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Target Diff', style: TextStyle(color: context.nc.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '${(avg - target) > 0 ? '+' : ''}${(avg - target).round()}$unit',
                  style: TextStyle(
                    color: (avg - target) > 0 && metricKey != 'pro' ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
