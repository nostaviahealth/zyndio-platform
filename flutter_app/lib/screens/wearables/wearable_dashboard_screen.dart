
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../data/health_repository.dart';
import '../../services/health_intelligence_service.dart';
import 'metric_detail_screen.dart';
import 'performance_detail_screen.dart';
import 'widgets/activity_ring_summary.dart';
import '../../providers/activity_goals_provider.dart';

import '../../providers/wearable_sync_provider.dart';
import '../../providers/navbar_provider.dart';
import 'widgets/dashboard_card_style.dart';

// New WHOOP-style widgets
import 'widgets/health_monitor_card.dart';
import 'widgets/strain_recovery_sleep_gauges.dart';
import 'widgets/stress_energy_card.dart';
import 'performance_detail/strain_performance_detail_screen.dart';
import 'performance_detail/cardio_load_detail_screen.dart';
import 'performance_detail/hrr_detail_screen.dart';
import 'widgets/cardio_load_card.dart';
import 'widgets/cardio_focus_card.dart';
import 'widgets/activity_summary_card.dart';
import 'widgets/activity_calendar_heatmap.dart';
import 'widgets/strain_performance_card.dart';
import 'widgets/vo2_max_card.dart';
import 'stress_detail_screen.dart';
import 'activity_summary_detail_screen.dart';

class WearableDashboardScreen extends ConsumerStatefulWidget {
  const WearableDashboardScreen({super.key});

  @override
  ConsumerState<WearableDashboardScreen> createState() => _WearableDashboardScreenState();
}

class _WearableDashboardScreenState extends ConsumerState<WearableDashboardScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  // UI State
  DateTime _selectedDate = DateTime.now();

  // Animation
  late AnimationController _syncAnimController;

  @override
  void initState() {
    super.initState();
    _syncAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _syncAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    return ref.read(wearableSyncProvider.notifier).sync(date: _selectedDate);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = context.nc.isDark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark 
                ? ColorScheme.dark(
                    primary: BrandColors.emerald500,
                    onPrimary: Colors.white,
                    surface: const Color(0xFF0F172A), // Solid background for readability
                    onSurface: context.nc.textPrimary,
                  )
                : ColorScheme.light(
                    primary: BrandColors.emerald500,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: context.nc.textPrimary,
                  ),
            dialogBackgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: BrandColors.emerald500,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      ref.read(wearableSyncProvider.notifier).sync(date: picked);
    }
  }

  // ═══════════════════════════════════════════════
  // DERIVED VALUES
  // ═══════════════════════════════════════════════

  String _formatSleepDuration(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String _formatMonthlyTotalTime(WearableSyncState state) {
    final currentData = state.cumulativeWorkoutData['current'] ?? [];
    if (currentData.isEmpty) return '0h 0m';
    final hoursDecimal = currentData.last;
    final h = hoursDecimal.floor();
    final m = ((hoursDecimal - h) * 60).round();
    return '${h}h ${m}m';
  }

  String _formatMonthlyDateRange(WearableSyncState state) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 29));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${start.day} ${months[start.month - 1]} – ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _formatDateRange(WearableSyncState state) {
    final now = DateTime.now();
    if (_selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day) {
      return 'Today';
    }
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  String _formatPreviousTotalTime(WearableSyncState state) {
    return '--';
  }

  Map<DateTime, int> _buildActivityDaysMap(WearableSyncState state) {
    Map<DateTime, int> map = {};
    for (var entry in state.activeEnergyHistory) {
      final date = entry['date'] as DateTime;
      final energy = (entry['value'] as num).toDouble();
      map[DateTime(date.year, date.month, date.day)] = energy > 1000 ? 3 : (energy > 500 ? 2 : 1);
    }
    if (state.snapshot != null && state.snapshot!.activeEnergy > 0) {
      final energy = state.snapshot!.activeEnergy;
      map[DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)] = energy > 1000 ? 3 : (energy > 500 ? 2 : 1);
    }
    return map;
  }

  void _openDetail(String title, String value, String unit, Color color, List<Map<String, dynamic>> history, String insight) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => MetricDetailScreen(
          title: title,
          currentValue: value,
          unit: unit,
          historyData: history,
          color: color,
          insight: insight,
          healthRepository: HealthRepository(),
        ),
      ),
    );
  }

  String _getCoachingInsight(int strain, int recovery, double sleep, int steps) {
    if (recovery > 70) return "You're well-recovered. Today is a great day for high intensity.";
    if (recovery < 40) return "Recovery is low. Consider a rest day or light activity.";
    return "Balanced state. Maintain your routine and listen to your body.";
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final syncStateAsync = ref.watch(wearableSyncProvider);
    final activityGoals = ref.watch(activityGoalsProvider);
    
    return syncStateAsync.when(
      loading: () => Scaffold(
        backgroundColor: context.nc.isDark ? Colors.transparent : context.nc.scaffoldBg,
        body: SafeArea(child: _buildLoadingState()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: context.nc.isDark ? Colors.transparent : context.nc.scaffoldBg,
        body: Center(child: Text('Error: $err')),
      ),
      data: (state) {
        final wearable = state.snapshot;
        final isSyncing = state.isSyncing;
        final isConnected = state.error != 'Not linked';

        if (!isConnected) {
          return _buildConnectState();
        }

        return Scaffold(
          backgroundColor: context.nc.isDark ? Colors.transparent : context.nc.scaffoldBg,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _fetchData,
              color: BrandColors.emerald500,
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollUpdateNotification) {
                    final double dy = notification.scrollDelta ?? 0.0;
                    if (dy > 3.0) {
                      ref.read(navbarVisibleProvider.notifier).hide();
                    } else if (dy < -3.0) {
                      ref.read(navbarVisibleProvider.notifier).show();
                    }
                  }
                  return false;
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                  // HEADER
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Live Tracking',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: context.nc.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                if (isSyncing) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Syncing data...',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: context.nc.textTertiary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _selectDate,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: context.nc.cardSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.nc.cardBorder.withOpacity(0.5),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.nc.isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              child: Icon(LucideIcons.calendarDays, size: 20, color: context.nc.textPrimary),
                            ),
                          ),
                          GestureDetector(
                            onTap: isSyncing ? null : _fetchData,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: context.nc.cardSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: context.nc.cardBorder.withOpacity(0.5),
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: context.nc.isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              child: AnimatedBuilder(
                                animation: _syncAnimController,
                                builder: (context, child) {
                                  if (isSyncing && !_syncAnimController.isAnimating) {
                                    _syncAnimController.repeat();
                                  } else if (!isSyncing && _syncAnimController.isAnimating) {
                                    _syncAnimController.stop();
                                  }
                                  return Transform.rotate(
                                    angle: isSyncing ? _syncAnimController.value * 6.28 : 0,
                                    child: Icon(
                                      LucideIcons.refreshCw,
                                      size: 20,
                                      color: isSyncing ? BrandColors.emerald500 : context.nc.textPrimary,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (state.lastSynced != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: BrandColors.emerald500, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text('Synced ${_formatLastSynced(state.lastSynced!)}', style: TextStyle(fontSize: 12, color: context.nc.textTertiary)),
                          ],
                        ),
                      ),
                    ),

                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 20),
                        _buildActivityRingsCard(activityGoals, state),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Performance', 'Daily strain & recovery'),
                        const SizedBox(height: 12),
                        PerformanceCoachingCard(
                          strainPercent: wearable?.strainScore ?? 0,
                          recoveryPercent: wearable?.recoveryScore ?? 0,
                          sleepPercent: wearable?.sleepScore ?? 0,
                          insight: _getCoachingInsight(
                            wearable?.strainScore ?? 0,
                            wearable?.recoveryScore ?? 0,
                            wearable?.sleepHours ?? 0.0,
                            wearable?.steps ?? 0
                          ),
                          onStrainTap: () => _openPerformanceDetail(PerformanceType.strain, state),
                          onRecoveryTap: () => _openPerformanceDetail(PerformanceType.recovery, state),
                          onSleepTap: () => _openDetail(
                            'Sleep Duration', 
                            (wearable?.sleepHours ?? 0) > 0 ? _formatSleepDuration(wearable!.sleepHours) : '--', 
                            '', 
                            const Color(0xFF818CF8), 
                            state.sleepHistoryDaily, 
                            'Aim for 7-9 hours of quality sleep each night.'
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Stress & Energy', 'Body battery & stress levels'),
                        const SizedBox(height: 12),
                        StressEnergyCard(
                          stressScore: wearable?.stressScore ?? 0,
                          energyScore: wearable?.energyScore ?? -1,
                          stressHigh: wearable?.stressHigh ?? 0,
                          stressLow: wearable?.stressLow ?? 0,
                          stressAvg: wearable?.stressAvg ?? 0,
                          onStressTap: () => _navigateToDetail(context, PerformanceType.stress, state),
                          onEnergyTap: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (context) => PerformanceDetailScreen(
                                  type: PerformanceType.energy,
                                  gaugePercent: wearable?.energyScore ?? 0,
                                  stat1Label: 'Daily High',
                                  stat1Value: '98',
                                  stat1Unit: '%',
                                  stat2Label: 'Daily Low',
                                  stat2Value: '12',
                                  stat2Unit: '%',
                                  coachingText: 'Your body battery is refilling optimally during sleep.',
                                  hrv: wearable?.hrv,
                                  rhr: wearable?.rhr,
                                  sleepHours: wearable?.sleepHours ?? 0,
                                  stressScore: wearable?.stressScore ?? 0,
                                  energyScore: wearable?.energyScore ?? 0,
                                  hrvHistory: state.hrvHistory,
                                  rhrHistory: state.rhrHistory,
                                  sleepHistory: state.sleepHistoryDaily,
                                  activeEnergyHistory: state.activeEnergyHistory,
                                  weeklySteps: state.weeklySteps,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Health Monitor', 'Key vitals at a glance'),
                        const SizedBox(height: 12),
                        _buildHealthMonitorGrid(state),
                        const SizedBox(height: 12),
                        _buildSectionHeader('Cardio', 'Cardiovascular performance'),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (context) => CardioLoadDetailScreen(
                                  healthRepository: HealthRepository(),
                                  currentLoad: _calculateCardioLoad(state).toDouble(),
                                  status: HealthIntelligenceService.getCardioLoadStatus(_calculateCardioLoad(state)),
                                ),
                              ),
                            );
                          },
                          child: CardioLoadCard(
                            cardioLoad: _calculateCardioLoad(state),
                            status: HealthIntelligenceService.getCardioLoadStatus(_calculateCardioLoad(state)),
                            dataPoints: state.hrHistory.isNotEmpty ? state.hrHistory.take(14).map((e) => (e['value'] as num).toDouble() / 10).toList() : [],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: CardioFocusCard(
                              focusType: HealthIntelligenceService.calculateCardioFocusType(
                                exerciseHrAvg: state.exerciseHrAvg ?? state.snapshot?.heartRateAvg ?? (state.snapshot?.rhr ?? 65) + 20, 
                                ageYears: state.userAge
                              ),
                              minutes: wearable?.exerciseMinutes ?? 0,
                              percent: (wearable?.exerciseMinutes ?? 0) > 0 ? (((wearable?.exerciseMinutes ?? 0) / activityGoals.exerciseGoal) * 100).round().clamp(0, 100) : 0,
                              onTap: () => _openDetail(
                                'Cardio Focus', 
                                '${wearable?.exerciseMinutes ?? 0}', 
                                'min', 
                                const Color(0xFF06B6D4), 
                                state.exerciseMinutesHistory, 
                                'Your cardio focus is currently based on your exercise duration and heart rate intensity.'
                              ),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: GestureDetector(
                              onTap: () {
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(builder: (context) => HrrDetailScreen(currentHrr: state.hrrBpm, status: state.hrrRange)),
                                );
                              },
                              child: HrrCard(value: state.hrrValue, range: state.hrrRange),
                            )),
                          ],
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _openDetail('VO₂ Max', state.vo2Max?.toStringAsFixed(1) ?? '--', 'ml/kg/min', const Color(0xFF10B981), state.vo2MaxHistory, 'VO₂ Max measures your maximum oxygen uptake during exercise.'),
                          child: Vo2MaxCard(
                            vo2Max: state.vo2Max, 
                            age: state.userAge,
                            isMale: state.isMale,
                            lastUpdated: state.vo2MaxDate ?? DateTime.now(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Fitness', 'Activity and performance trends'),
                        const SizedBox(height: 12),
                        ActivityCalendarHeatmap(activityDays: _buildActivityDaysMap(state)),
                        const SizedBox(height: 12),
                        ActivitySummaryCard(
                          totalTime: _formatMonthlyTotalTime(state),
                          dateRange: _formatMonthlyDateRange(state),
                          previousTime: _formatPreviousTotalTime(state),
                          activityData: state.cumulativeWorkoutData['current'] ?? [],
                          baselineData: state.cumulativeWorkoutData['previous'] ?? [],
                          dateLabels: state.activeEnergyHistory.length > 30 
                              ? state.activeEnergyHistory.sublist(state.activeEnergyHistory.length - 30).map((e) => '${(e['date'] as DateTime).day}/${(e['date'] as DateTime).month}').toList()
                              : state.activeEnergyHistory.map((e) => '${(e['date'] as DateTime).day}/${(e['date'] as DateTime).month}').toList(),
                          onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => ActivitySummaryDetailScreen(healthRepository: HealthRepository()))),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(builder: (context) => StrainPerformanceDetailScreen(healthRepository: HealthRepository(), currentStrain: wearable?.strainScore ?? 0, status: HealthIntelligenceService.getStrainPerformanceStatus(HealthIntelligenceService.calculateStrainPerformanceDelta(todayStrainScore: wearable?.strainScore ?? 0, last7DayStrainScores: state.weeklyStrains)), performanceDelta: HealthIntelligenceService.calculateStrainPerformanceDelta(todayStrainScore: wearable?.strainScore ?? 0, last7DayStrainScores: state.weeklyStrains).toDouble()))),
                          child: StrainPerformanceCard(performancePercent: HealthIntelligenceService.calculateStrainPerformanceDelta(todayStrainScore: wearable?.strainScore ?? 0, last7DayStrainScores: state.weeklyStrains), status: HealthIntelligenceService.getStrainPerformanceStatus(HealthIntelligenceService.calculateStrainPerformanceDelta(todayStrainScore: wearable?.strainScore ?? 0, last7DayStrainScores: state.weeklyStrains)), dataPoints: state.weeklyStrains.isNotEmpty ? state.weeklyStrains.map((s) => s.toDouble()).toList() : (state.weeklySteps.isNotEmpty ? state.weeklySteps.map((e) => (e['steps'] as num).toDouble() / 1000).toList() : [])),
                        ),
                        const SizedBox(height: 100),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    );
  }

  int _calculateCardioLoad(WearableSyncState state) {
    return HealthIntelligenceService.calculateCardioLoad(
      exerciseMinutes: state.snapshot?.exerciseMinutes ?? 0,
      exerciseHrAvg: state.exerciseHrAvg,
      allDayHrAvg: null, // Don't use stress as proxy
      restingHeartRate: state.snapshot?.rhr,
      ageYears: state.userAge,
    );
  }

  String _formatLastSynced(DateTime lastSynced) {
    final diff = DateTime.now().difference(lastSynced);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.nc.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: context.nc.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRingsCard(ActivityGoals goals, WearableSyncState state) {
    final wearable = state.snapshot;
    return DashboardCard(
      child: ActivityRingSummary(
        moveKcal: wearable?.activeEnergy ?? 0.0,
        moveGoal: goals.moveGoal,
        exerciseMin: wearable?.exerciseMinutes ?? 0,
        exerciseGoal: goals.exerciseGoal,
        standHrs: 0, 
        standGoal: 12,
        steps: wearable?.steps ?? 0,
        stepsGoal: goals.stepsGoal,
      ),
    );
  }

  Widget _buildHealthMonitorGrid(WearableSyncState state) {
    final wearable = state.snapshot;
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        HealthMonitorCard(
          icon: LucideIcons.wind,
          label: 'RR',
          valueStr: wearable?.respiratoryRate != null ? wearable!.respiratoryRate!.toStringAsFixed(1) : '--',
          unit: 'rpm',
          numericValue: wearable?.respiratoryRate,
          minBound: 8,
          maxBound: 25,
          normalMin: 12,
          normalMax: 20,
          higherColor: const Color(0xFFF97316),
          lowerColor: const Color(0xFF3B82F6),
          onTap: () => _openDetail('Respiratory Rate', wearable?.respiratoryRate?.toStringAsFixed(1) ?? '--', 'rpm', const Color(0xFF10B981), state.rrHistory, 'Normal resting respiratory rate is 12–20 breaths per minute.'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.heart,
          label: 'RHR',
          valueStr: wearable?.rhr != null ? '${wearable!.rhr}' : '--',
          unit: 'bpm',
          numericValue: wearable?.rhr?.toDouble(),
          minBound: 40,
          maxBound: 100,
          normalMin: 50,
          normalMax: 70,
          higherColor: const Color(0xFFF97316),
          lowerColor: const Color(0xFF10B981),
          onTap: () => _openDetail('Resting Heart Rate', '${wearable?.rhr ?? "--"}', 'bpm', const Color(0xFFEF4444), state.rhrHistory, 'A lower resting heart rate indicates better cardiovascular fitness.'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.activity,
          label: 'HRV',
          valueStr: wearable?.hrv != null ? wearable!.hrv!.round().toString() : '--',
          unit: 'ms',
          numericValue: wearable?.hrv,
          minBound: 10,
          maxBound: 120,
          normalMin: 30,
          normalMax: 80,
          higherColor: const Color(0xFF3B82F6),
          lowerColor: const Color(0xFFF97316),
          onTap: () => _openDetail('Heart Rate Variability', '${wearable?.hrv?.round() ?? "--"}', 'ms', const Color(0xFF10B981), state.hrvHistory, 'High HRV indicates good recovery and stress resilience.'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.droplets,
          label: 'SpO2',
          valueStr: wearable?.bloodOxygen != null ? '${(wearable!.bloodOxygen! <= 1.0 ? wearable.bloodOxygen! * 100 : wearable.bloodOxygen!).round()}' : '--',
          unit: '%',
          numericValue: wearable?.bloodOxygen?.toDouble(),
          minBound: 85,
          maxBound: 100,
          normalMin: 95,
          normalMax: 100,
          higherColor: const Color(0xFF10B981),
          lowerColor: const Color(0xFFEF4444),
          onTap: () => _openDetail('Blood Oxygen', '${wearable?.bloodOxygen != null ? (wearable!.bloodOxygen! <= 1.0 ? wearable.bloodOxygen! * 100 : wearable.bloodOxygen!).round() : "--"}', '%', Colors.blueAccent, state.spo2History, 'Optimal oxygen saturation levels detected.'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.flame,
          label: 'Active',
          valueStr: wearable?.activeEnergy != null && wearable!.activeEnergy > 0 ? wearable.activeEnergy.round().toString() : '--',
          unit: 'kcal',
          numericValue: wearable?.activeEnergy,
          minBound: 0,
          maxBound: 1000,
          normalMin: 200,
          normalMax: 600,
          higherColor: const Color(0xFFF97316),
          lowerColor: const Color(0xFF3B82F6),
          onTap: () => _openDetail('Active Energy', wearable?.activeEnergy != null && wearable!.activeEnergy > 0 ? wearable.activeEnergy.round().toString() : '--', 'kcal', const Color(0xFFF97316), state.activeEnergyHistory, 'Active energy burned throughout the day.'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.moon,
          label: 'Sleep',
          valueStr: (wearable?.sleepHours ?? 0) > 0 ? _formatSleepDuration(wearable!.sleepHours) : '--',
          unit: '',
          numericValue: (wearable?.sleepHours ?? 0) > 0 ? wearable!.sleepHours : null,
          minBound: 0,
          maxBound: 12,
          normalMin: 7,
          normalMax: 9,
          higherColor: const Color(0xFF3B82F6),
          lowerColor: const Color(0xFFF97316),
          onTap: () => _openDetail('Sleep Duration', (wearable?.sleepHours ?? 0) > 0 ? _formatSleepDuration(wearable!.sleepHours) : '--', '', const Color(0xFF818CF8), state.sleepHistoryDaily, 'Aim for 7-9 hours of quality sleep each night.'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.timer,
          label: 'Exercise',
          valueStr: wearable?.exerciseMinutes != null ? '${wearable!.exerciseMinutes}' : '--',
          unit: 'min',
          numericValue: wearable?.exerciseMinutes?.toDouble(),
          minBound: 0,
          maxBound: 90,
          normalMin: 30,
          normalMax: 60,
          higherColor: const Color(0xFF06B6D4),
          lowerColor: const Color(0xFF94A3B8),
          onTap: () => _openDetail('Exercise Minutes', '${wearable?.exerciseMinutes ?? "--"}', 'min', const Color(0xFF06B6D4), state.exerciseMinutesHistory, 'The American Heart Association recommends 150 minutes of moderate activity per week.'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.thermometer,
          label: 'Skin Temp',
          valueStr: wearable?.skinTemperature != null ? '${wearable!.skinTemperature!.toStringAsFixed(1)}°' : '--',
          unit: 'C',
          numericValue: wearable?.skinTemperature,
          minBound: 30,
          maxBound: 40,
          normalMin: 33,
          normalMax: 37,
          higherColor: const Color(0xFFEF4444),
          lowerColor: const Color(0xFF3B82F6),
          onTap: () => _openDetail('Skin Temperature', '${wearable?.skinTemperature?.toStringAsFixed(1) ?? "--"}', '°C', const Color(0xFFEF4444), state.skinTempHistory, 'Skin temperature variations can indicate circadian shifts or changes in health status.'),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(BrandColors.emerald500),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Syncing health data...',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.nc.textTertiary),
          ),
          const SizedBox(height: 8),
          Text('This may take a moment', style: TextStyle(fontSize: 13, color: context.nc.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildConnectState() {
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sync Health Data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: context.nc.textPrimary,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connect your wearable to unlock advanced longevity insights, stress analysis, and body battery scores.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.nc.textTertiary,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () async {
                    await context.pushNamed('connect_wearable');
                    if (!mounted) return;
                    _fetchData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.nc.textPrimary,
                    foregroundColor: context.nc.scaffoldBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Connect Device',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, PerformanceType type, WearableSyncState state) {
    if (type == PerformanceType.stress) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (context) => PerformanceDetailScreen(
            type: PerformanceType.stress,
            gaugePercent: state.snapshot?.stressScore ?? 0,
            stat1Label: 'Daily Avg',
            stat1Value: '${state.snapshot?.stressAvg ?? 0}',
            stat1Unit: '',
            stat2Label: 'Peak Stress',
            stat2Value: '${state.snapshot?.stressHigh ?? 0}',
            stat2Unit: '',
            coachingText: 'Your stress levels are balanced. Consider 5 min of breathwork.',
            hrv: state.snapshot?.hrv,
            rhr: state.snapshot?.rhr,
            stressScore: state.snapshot?.stressScore ?? 0,
            energyScore: state.snapshot?.energyScore ?? 0,
            hrvBaseline: state.hrvBaseline,
            rhrBaseline: state.rhrBaseline,
            hrvHistory: state.hrvHistory,
            rhrHistory: state.rhrHistory,
            hrHistory: state.hrHistory,
            activeEnergyHistory: state.activeEnergyHistory,
            weeklySteps: state.weeklySteps,
          ),
        ),
      );
      return;
    }
    _openPerformanceDetail(type, state);
  }

  void _openPerformanceDetail(PerformanceType type, WearableSyncState state) {
    final wearable = state.snapshot;
    final recoveryPercent = HealthIntelligenceService.calculateRecoveryScore(
      hrv: wearable?.hrv,
      restingHeartRate: wearable?.rhr,
      sleepHours: wearable?.sleepHours ?? 0.0,
      sleepEfficiency: wearable?.sleepEfficiency,
      hrvBaseline: state.hrvBaseline,
      rhrBaseline: state.rhrBaseline,
    );
    final sleepPercent = HealthIntelligenceService.calculateSleepScore(sleepHours: wearable?.sleepHours ?? 0, sleepEfficiency: wearable?.sleepEfficiency);

    // Compute HR min/max from intraday HR history (Fix #7)
    int? hrMin;
    int? hrMax;
    if (state.hrHistory.isNotEmpty) {
      for (var point in state.hrHistory) {
        final val = (point['value'] as num).toInt();
        if (val > 0) {
          if (hrMin == null || val < hrMin) hrMin = val;
          if (hrMax == null || val > hrMax) hrMax = val;
        }
      }
    }
    
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => PerformanceDetailScreen(
          type: type,
          gaugePercent: type == PerformanceType.recovery ? recoveryPercent : (type == PerformanceType.sleep ? sleepPercent : (type == PerformanceType.strain ? (wearable?.strainScore ?? 0) : 0)),
          stat1Label: type == PerformanceType.recovery ? 'Resting HRV' : (type == PerformanceType.sleep ? 'Time in Bed' : (type == PerformanceType.strain ? 'Active Energy' : '')),
          stat1Value: type == PerformanceType.recovery ? (wearable?.hrv?.toStringAsFixed(1) ?? "--") : (type == PerformanceType.sleep ? _formatSleepDuration((wearable?.sleepHours ?? 0) + 0.1) : (type == PerformanceType.strain ? '${wearable?.activeEnergy.round() ?? 0}' : '')),
          stat1Unit: type == PerformanceType.recovery ? 'ms' : (type == PerformanceType.strain ? 'kcal' : ''),
          stat2Label: type == PerformanceType.recovery ? 'Resting HR' : (type == PerformanceType.sleep ? 'Time Asleep' : (type == PerformanceType.strain ? 'Exercise' : '')),
          stat2Value: type == PerformanceType.recovery ? '${wearable?.rhr ?? "--"}' : (type == PerformanceType.sleep ? _formatSleepDuration(wearable?.sleepHours ?? 0) : (type == PerformanceType.strain ? '${wearable?.exerciseMinutes ?? 0}' : '')),
          stat2Unit: type == PerformanceType.recovery ? 'bpm' : (type == PerformanceType.strain ? 'min' : ''),
          coachingText: '',
          hrv: wearable?.hrv,
          rhr: wearable?.rhr,
          exerciseMinutes: wearable?.exerciseMinutes ?? 0,
          activeEnergy: wearable?.activeEnergy ?? 0,
          sleepHours: wearable?.sleepHours ?? 0,
          stressScore: wearable?.stressScore ?? 0,
          energyScore: wearable?.energyScore ?? 0,
          respiratoryRate: wearable?.respiratoryRate,
          bloodOxygen: wearable?.bloodOxygen?.round(),
          skinTemperature: wearable?.skinTemperature,  // Fix #6: pass null not 0
          heartRateAvg: wearable?.heartRateAvg,         // Fix #1: was stressScore
          heartRateMin: hrMin,                           // Fix #7: computed from hrHistory
          heartRateMax: hrMax,                           // Fix #7: computed from hrHistory
          hrvBaseline: state.hrvBaseline,                // Fix #2: personal baseline
          rhrBaseline: state.rhrBaseline,                // Fix #2: personal baseline
          hrvHistory: state.hrvHistory,
          rhrHistory: state.rhrHistory,
          rrHistory: state.rrHistory,
          spo2History: state.spo2History,
          sleepHistory: state.sleepHistoryDaily,
          activeEnergyHistory: state.activeEnergyHistory,
          skinTempHistory: state.skinTempHistory,
          hrHistory: state.hrHistory,                    // Fix #3: for stress sympathetic component
          weeklySteps: state.weeklySteps,
        ),
      ),
    );
  }
}
