import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../providers/nutrition_goals_provider.dart';
import '../../providers/lens_provider.dart';
import '../../providers/navbar_provider.dart';
import '../../models/food_log.dart';
import '../../models/food_analysis.dart';
import '../settings/lens_history_screen.dart';
import 'package:intl/intl.dart';

class FoodIntelligenceScreen extends ConsumerStatefulWidget {
  const FoodIntelligenceScreen({super.key});

  @override
  ConsumerState<FoodIntelligenceScreen> createState() => _FoodIntelligenceScreenState();
}

class _FoodIntelligenceScreenState extends ConsumerState<FoodIntelligenceScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Calories', 'Protein', 'Carbs', 'Fat'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(navbarVisibleProvider.notifier).hide();
      }
    });
  }

  @override
  void dispose() {
    ref.read(navbarVisibleProvider.notifier).show();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(foodLogsProvider);

    return PopScope(
      onPopInvoked: (didPop) {
        if (didPop) {
          ref.read(navbarVisibleProvider.notifier).show();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft, color: Colors.white),
            onPressed: () {
              ref.read(navbarVisibleProvider.notifier).show();
              context.pop();
            },
          ),
          title: const Text(
            'Nutrition Trends',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
          ),
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.5],
              colors: [
                const Color(0xFF064E3B).withOpacity(0.3),
                const Color(0xFF020617),
              ],
            ),
          ),
          child: logsAsync.when(
            data: (logs) {
              final dailyData = _processLogs(logs);
              final sortedDates = dailyData.keys.toList()..sort();
              final last7Days = sortedDates.length > 7 ? sortedDates.sublist(sortedDates.length - 7) : sortedDates;
              
              final String metricKey = ['cal', 'pro', 'carb', 'fat'][_selectedTab];
              final nutritionGoals = ref.watch(nutritionGoalsProvider);

              double totalForSelectedTab = 0;
              for (var date in last7Days) {
                totalForSelectedTab += dailyData[date]![metricKey] ?? 0;
              }
              final avg = last7Days.isEmpty ? 0.0 : totalForSelectedTab / last7Days.length;

              double target = 2000;
              String unit = 'KCAL';
              if (metricKey == 'cal') {
                target = nutritionGoals.calorieGoal;
                unit = 'KCAL';
              } else if (metricKey == 'pro') {
                target = nutritionGoals.proteinGoal;
                unit = 'G';
              } else if (metricKey == 'carb') {
                target = nutritionGoals.carbGoal;
                unit = 'G';
              } else if (metricKey == 'fat') {
                target = nutritionGoals.fatGoal;
                unit = 'G';
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 100),
                    _buildTabBar(),
                    const SizedBox(height: 24),
                    _buildMainChartCard(last7Days, dailyData, target, unit, metricKey),
                    const SizedBox(height: 16),
                    _buildSummaryRow(avg, target, unit, metricKey),
                    const SizedBox(height: 44),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Meal History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildMealHistory(logs),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            ref.read(lensScanProvider.notifier).reset();
            context.push('/lens');
          },
          backgroundColor: Colors.white,
          shape: const StadiumBorder(),
          label: const Text('LOG MEAL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 1)),
          icon: const Icon(LucideIcons.plus, color: Colors.black),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Map<DateTime, Map<String, double>> _processLogs(List<FoodLog> logs) {
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
    return dailyTotals;
  }

  Widget _buildTabBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(21),
                ),
                alignment: Alignment.center,
                child: Text(
                  _tabs[index],
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white.withOpacity(0.4),
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

  Widget _buildMainChartCard(List<DateTime> dates, Map<DateTime, Map<String, double>> dailyData, double target, String unit, String metricKey) {
    double maxVal = 0;
    for (var date in dates) {
      if (dailyData[date]![metricKey]! > maxVal) maxVal = dailyData[date]![metricKey]!;
    }
    if (metricKey == 'cal') {
      maxVal = maxVal < 1000 ? 2500 : maxVal * 1.2;
    } else {
      maxVal = maxVal < 50 ? 150 : maxVal * 1.2;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily ${_tabs[_selectedTab]}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                ),
                child: Text(
                  'TARGET: ${target.round()}$unit',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                maxY: maxVal,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal / 5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.03),
                    strokeWidth: 1,
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: target,
                      color: const Color(0xFF10B981).withOpacity(0.3),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    ),
                  ],
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) => Text(
                        value.round().toString(),
                        style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dates.length) return const SizedBox();
                        final date = dates[index];
                        final isToday = DateTime.now().day == date.day && DateTime.now().month == date.month;
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            isToday ? 'Today' : DateFormat('EEE').format(date),
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(dates.length, (index) {
                  final date = dates[index];
                  final val = dailyData[date]![metricKey]!;
                  final isCal = metricKey == 'cal';
                  final color = isCal 
                      ? (val > target ? const Color(0xFFEF4444) : const Color(0xFF10B981))
                      : const Color(0xFF10B981);
                  return _makeGroup(index, val, color, maxVal);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeGroup(int x, double y, Color color, double max) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 16,
          borderRadius: BorderRadius.circular(100),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: max,
            color: Colors.white.withOpacity(0.05),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(double avg, double target, String unit, String metricKey) {
    final diff = avg - target;
    final diffSign = diff > 0 ? '+' : '';
    
    Color diffColor;
    if (metricKey == 'cal' || metricKey == 'carb' || metricKey == 'fat') {
      diffColor = diff > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    } else {
      diffColor = diff >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    }

    return Row(
      children: [
        _buildSummaryCard('7-Day Avg', '${avg.round()}${unit.toLowerCase()}', Colors.white),
        const SizedBox(width: 16),
        _buildSummaryCard('Target Diff', '$diffSign${diff.round()}${unit.toLowerCase()}', diffColor),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealHistory(List<FoodLog> logs) {
    if (logs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('No meals logged yet', style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    final grouped = _groupByDate(logs);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 32, bottom: 16),
              child: Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            ...entry.value.map((log) {
              final analysis = FoodAnalysis.fromJson(log.analysis);
              return _buildMealItem(log, analysis);
            }),
          ],
        );
      }).toList(),
    );
  }

  Map<String, List<FoodLog>> _groupByDate(List<FoodLog> logs) {
    final Map<String, List<FoodLog>> grouped = {};
    for (final log in logs) {
      final key = _formatDateHeader(log.loggedAt);
      grouped.putIfAbsent(key, () => []).add(log);
    }
    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final logDay = DateTime(date.year, date.month, date.day);

    if (logDay == today) return 'Today';
    if (logDay == yesterday) return 'Yesterday';
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Widget _buildMealItem(FoodLog log, FoodAnalysis analysis) {
    final score = analysis.score;
    Color scoreColor = const Color(0xFF10B981); // Default amber
    if (score >= 80) scoreColor = const Color(0xFF10B981); // Emerald
    if (score < 50) scoreColor = const Color(0xFFEF4444); // Red

    return GestureDetector(
      onTap: () => context.push('/meal-detail', extra: log),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: scoreColor.withOpacity(0.2), width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                '$score',
                style: TextStyle(
                  color: scoreColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analysis.foodName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${analysis.calories} kcal • ${DateFormat('h:mm a').format(log.loggedAt)}',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: Colors.white.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }
}
