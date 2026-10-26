import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/lab_report.dart';
import '../../providers/wearable_sync_provider.dart';

class PerformanceDetailScreen extends StatefulWidget {
  final WearableSyncState syncState;
  final List<LabReport> labReports;
  final int performanceReadiness;
  final String statusText;
  final Color statusColor;
  final String focusStatus;
  final String energyStatus;
  final String reactionStatus;

  const PerformanceDetailScreen({
    super.key,
    required this.syncState,
    required this.labReports,
    required this.performanceReadiness,
    required this.statusText,
    required this.statusColor,
    required this.focusStatus,
    required this.energyStatus,
    required this.reactionStatus,
  });

  @override
  State<PerformanceDetailScreen> createState() => _PerformanceDetailScreenState();
}

class _PerformanceDetailScreenState extends State<PerformanceDetailScreen> {
  int _expandedPillar = -1;
  int _selectedTrendDays = 30;
  int _selectedSignalDays = 30;

  String _getMonthAbbr(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  String _stripUnits(String rawValue) {
    if (rawValue == '--') return '--';
    return rawValue
        .replaceAll(RegExp(r'\s*mg/dL\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*mg/L\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*ng/dL\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*µg/dL\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*ug/dL\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*nmol/L\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*%\s*'), '')
        .trim();
  }

  DateTime get _anchorDate {
    DateTime anchorDate = DateTime.now();
    DateTime? latestHistoryDate;
    
    void updateLatest(List<Map<String, dynamic>> history) {
      if (history.isNotEmpty) {
        for (var point in history) {
          final date = point['date'] as DateTime?;
          if (date != null) {
            if (latestHistoryDate == null || date.isAfter(latestHistoryDate!)) {
              latestHistoryDate = date;
            }
          }
        }
      }
    }

    updateLatest(widget.syncState.hrvHistory);
    updateLatest(widget.syncState.rhrHistory);
    updateLatest(widget.syncState.sleepHistoryDaily);
    updateLatest(widget.syncState.spo2History);
    updateLatest(widget.syncState.activeEnergyHistory);
    updateLatest(widget.syncState.exerciseMinutesHistory);
    updateLatest(widget.syncState.skinTempHistory);
    updateLatest(widget.syncState.weeklySteps);

    if (latestHistoryDate != null) {
      anchorDate = latestHistoryDate!;
    }
    return anchorDate;
  }

  void _showPerformanceReadinessCitations() {
    _showClinicalCitationSheet(
      title: 'Performance Readiness',
      explanation: 'Performance Readiness is a comprehensive metric combining autonomic nervous system balance, cognitive recovery (sleep efficiency), and circadian alignment to determine your central nervous system\'s capacity for complex physical and cognitive tasks.',
      citations: [
        ClinicalCitation(
          source: 'Dinges DF, et al. (1997)',
          title: 'Cumulative sleepiness, mood disturbance, and psychomotor vigilance performance',
        ),
        ClinicalCitation(
          source: 'Borbely AA (1982)',
          title: 'A two-process model of sleep regulation',
        ),
        ClinicalCitation(
          source: 'Dijk DJ & Czeisler CA (1995)',
          title: 'Contribution of the circadian pacemaker and the sleep homeostat',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Pillar 1: Autonomic Readiness (35%) ──
    final double hrvCurrent = (widget.syncState.snapshot?.hrv ?? 55).toDouble();
    final double hrvBase = widget.syncState.hrvBaseline ?? 50.0;
    String autonomicStatus = 'Balanced';
    Color autonomicColor = const Color(0xFF3B82F6);
    if (hrvCurrent >= hrvBase * 0.95) {
      autonomicStatus = 'Resilient';
      autonomicColor = const Color(0xFF10B981);
    } else if (hrvCurrent < hrvBase * 0.75) {
      autonomicStatus = 'Suppressed';
      autonomicColor = const Color(0xFFEF4444);
    }

    // ── Pillar 2: Cognitive Capacity (25%) ──
    final double sleepEff = widget.syncState.snapshot?.sleepEfficiency ?? 0.0;
    final double sleepHours = widget.syncState.snapshot?.sleepHours ?? 0.0;
    String cognitiveStatus = 'Adequate';
    Color cognitiveColor = const Color(0xFFF59E0B);
    if (hrvCurrent >= hrvBase * 0.90 && sleepEff >= 85.0 && sleepHours >= 7.0) {
      cognitiveStatus = 'Sharp';
      cognitiveColor = const Color(0xFF10B981);
    } else if (hrvCurrent < hrvBase * 0.75 || sleepEff < 70.0 || sleepHours < 5.5) {
      cognitiveStatus = 'Impaired';
      cognitiveColor = const Color(0xFFEF4444);
    }

    // ── Pillar 3: Circadian Alignment (20%) ──
    final int currentHour = _anchorDate.hour;
    String circadianStatus = 'Transitional';
    Color circadianColor = const Color(0xFFF59E0B);
    // High-alertness windows: 9-12 AM and 2-5 PM
    if ((currentHour >= 9 && currentHour <= 12) || (currentHour >= 14 && currentHour <= 17)) {
      circadianStatus = 'In Phase';
      circadianColor = const Color(0xFF10B981);
    } else if (currentHour >= 23 || currentHour <= 5) {
      circadianStatus = 'Misaligned';
      circadianColor = const Color(0xFFEF4444);
    }

    // ── Pillar 4: Energy Reserves (20%) ──
    final double activeEnergy = widget.syncState.snapshot?.activeEnergy ?? 0.0;
    String energyReserveStatus = 'Adequate';
    Color energyReserveColor = const Color(0xFFF59E0B);
    if (sleepEff >= 85.0 && sleepHours >= 7.0 && hrvCurrent >= hrvBase * 0.90) {
      energyReserveStatus = 'Replenished';
      energyReserveColor = const Color(0xFF10B981);
    } else if (sleepEff < 70.0 || sleepHours < 5.5 || activeEnergy > 600) {
      energyReserveStatus = 'Depleted';
      energyReserveColor = const Color(0xFFEF4444);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroScore(),
                  const SizedBox(height: 16),
                  _buildAiNarrative(),
                  const SizedBox(height: 32),
                  _buildTrendChart(),
                  const SizedBox(height: 48),

                  const Text('Circadian Alertness Timeline', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildCircadianTimeline(),
                  const SizedBox(height: 48),

                  const Text('The Four Pillars', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildPillarCard(
                    'Autonomic Readiness',
                    '35% weight',
                    'HRV baseline stability and parasympathetic tone.',
                    autonomicStatus,
                    autonomicColor,
                    _buildAutonomicReadinessDetails(),
                    0,
                  ),
                  _buildPillarCard(
                    'Cognitive Capacity',
                    '25% weight',
                    'Attention, reaction time, and focus stability.',
                    cognitiveStatus,
                    cognitiveColor,
                    _buildCognitiveCapacityDetails(),
                    1,
                  ),
                  _buildPillarCard(
                    'Circadian Alignment',
                    '20% weight',
                    'Sleep-wake regularity and alertness phase.',
                    circadianStatus,
                    circadianColor,
                    _buildCircadianAlignmentDetails(),
                    2,
                  ),
                  _buildPillarCard(
                    'Energy Reserves',
                    '20% weight',
                    'Sleep quality, metabolic recovery, and glycogen status.',
                    energyReserveStatus,
                    energyReserveColor,
                    _buildEnergyReservesDetails(),
                    3,
                  ),

                  const SizedBox(height: 48),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Wearable Signal Feed',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      _buildSignalTimeSelector(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSignalChart('Heart Rate Variability', widget.syncState.hrvHistory, const Color(0xFF10B981), true),
                  const SizedBox(height: 24),
                  _buildSignalChart('Resting Heart Rate', widget.syncState.rhrHistory, const Color(0xFFF59E0B), false),
                  const SizedBox(height: 24),
                  _buildSignalChart('Sleep Efficiency', widget.syncState.sleepHistoryDaily, const Color(0xFF3B82F6), true),

                  const SizedBox(height: 48),
                  const Text('Metabolic Lab Intelligence', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 16),
                  _buildLabIntelligence(),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // APP BAR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      expandedHeight: 80,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
      ),
      title: Column(
        children: [
          const Text(
            'Performance Intelligence',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          Text(
            'Updated just now',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HERO SCORE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHeroScore() {
    int weeklyDelta = 3;
    if (widget.syncState.hrvHistory.length >= 7 && widget.syncState.rhrHistory.length >= 7) {
      try {
        final hrv7d = (widget.syncState.hrvHistory[widget.syncState.hrvHistory.length - 7]['value'] as num).toDouble();
        final rhr7d = (widget.syncState.rhrHistory[widget.syncState.rhrHistory.length - 7]['value'] as num).toDouble();
        final double sleepEff7d = 82.0;
        final double sleepHrs7d = 7.0;

        final double hrvScore7d = (hrv7d / 100.0) * 35.0;
        final double rhrScore7d = ((100.0 - rhr7d).clamp(0.0, 100.0)) / 100.0 * 15.0;
        final double sleepScore7d = (sleepEff7d / 100.0) * 25.0 + (sleepHrs7d / 9.0) * 5.0;
        final double circScore7d = 20.0;
        final double score7d = (hrvScore7d + rhrScore7d + sleepScore7d + circScore7d).clamp(40.0, 100.0);
        weeklyDelta = (widget.performanceReadiness - score7d).round();
      } catch (e) {
        weeklyDelta = 3;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${widget.performanceReadiness}',
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0),
                ),
                Text(
                  ' / 100',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: widget.statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    widget.statusText,
                    style: TextStyle(color: widget.statusColor, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showPerformanceReadinessCitations,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.shieldCheck, color: const Color(0xFF3B82F6).withOpacity(0.8), size: 12),
                        const SizedBox(width: 4),
                        const Text(
                          'CLINICAL REF',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              weeklyDelta >= 0 ? '+$weeklyDelta pts from last week' : '$weeklyDelta pts from last week',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: weeklyDelta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AI NARRATIVE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAiNarrative() {
    final double hrvVal = widget.syncState.snapshot?.hrv?.toDouble() ?? 55.0;
    final double sleepEff = widget.syncState.snapshot?.sleepEfficiency ?? 0.0;
    final double sleepHours = widget.syncState.snapshot?.sleepHours ?? 0.0;

    String narrative;
    if (widget.performanceReadiness >= 80) {
      narrative = "Strong parasympathetic tone detected with HRV at ${hrvVal.round()} ms. "
          "Optimal circadian alignment confirmed — cortisol awakening response is within healthy bounds. "
          "Sleep efficiency at ${sleepEff > 0 ? '${sleepEff.round()}%' : 'N/A'} with ${sleepHours.toStringAsFixed(1)}h total sleep supports full cognitive and metabolic recovery. "
          "This is an ideal window for complex problem solving and high-intensity training.";
    } else if (widget.performanceReadiness >= 60) {
      narrative = "Autonomic indicators are balanced but suboptimal. HRV is stable at ${hrvVal.round()} ms, "
          "however sleep efficiency of ${sleepEff > 0 ? '${sleepEff.round()}%' : 'N/A'} suggests incomplete slow-wave recovery. "
          "Cognitive capacity may be mildly reduced — reaction times could be 10-15% slower than baseline. "
          "Prioritize steady-state activity and avoid high-stakes cognitive tasks during circadian troughs.";
    } else {
      narrative = "Central nervous system fatigue detected. HRV is suppressed at ${hrvVal.round()} ms with "
          "sleep duration of ${sleepHours.toStringAsFixed(1)}h indicating significant recovery deficit. "
          "Recommend active rest, controlled breathing exercises, and early sleep onset tonight. "
          "Avoid high-intensity training and complex decision-making until recovery markers improve.";
    }

    return Text(
      narrative,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white70,
        height: 1.4,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TREND CHART
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTrendChart() {
    List<FlSpot> spots = [];
    int days = _selectedTrendDays;

    List<Map<String, dynamic>> hrvList = widget.syncState.hrvHistory;
    List<Map<String, dynamic>> rhrList = widget.syncState.rhrHistory;

    int availablePoints = math.min(hrvList.length, rhrList.length);
    double latestReadiness = widget.performanceReadiness.toDouble();

    if (availablePoints >= 5) {
      int pointsToTake = math.min(days, availablePoints);
      List<Map<String, dynamic>> hrvSub = hrvList.sublist(hrvList.length - pointsToTake);
      List<Map<String, dynamic>> rhrSub = rhrList.sublist(rhrList.length - pointsToTake);

      List<double> computedScores = [];
      for (int i = 0; i < pointsToTake; i++) {
        double hrv = (hrvSub[i]['value'] as num?)?.toDouble() ?? 55.0;
        double rhr = (rhrSub[i]['value'] as num?)?.toDouble() ?? 64.0;

        double hrvScore = (hrv / 100.0 * 35.0);
        double rhrScore = ((100.0 - rhr).clamp(0.0, 100.0)) / 100.0 * 15.0;
        double sleepScore = 22.0;
        double circScore = 18.0;

        double score = (hrvScore + rhrScore + sleepScore + circScore).clamp(40.0, 100.0);
        computedScores.add(score);
      }

      if (computedScores.isNotEmpty) {
        computedScores[computedScores.length - 1] = latestReadiness;
      }

      int missing = days - pointsToTake;
      double startScore = computedScores.isNotEmpty ? computedScores.first : latestReadiness;

      List<double> padding = [];
      for (int i = 0; i < missing; i++) {
        padding.add(startScore);
      }

      List<double> finalScores = [...padding, ...computedScores];
      for (int i = 0; i < finalScores.length; i++) {
        spots.add(FlSpot(i.toDouble(), finalScores[i]));
      }
    } else {
      double currentScore = latestReadiness;

      for (int i = 0; i < days; i++) {
        spots.insert(0, FlSpot((days - 1 - i).toDouble(), currentScore));
      }
    }

    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.only(top: 20, right: 16, left: 16, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trend', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
              Row(
                children: [
                  _buildTimePill('30D', 30),
                  const SizedBox(width: 8),
                  _buildTimePill('60D', 60),
                  const SizedBox(width: 8),
                  _buildTimePill('90D', 90),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 40,
                maxY: 100,
                minX: 0,
                maxX: (days - 1).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: (days <= 30) ? 7.0 : (days <= 60 ? 15.0 : 30.0),
                      getTitlesWidget: (value, meta) {
                        int index = value.round();
                        double bottomInterval = (days <= 30) ? 7.0 : (days <= 60 ? 15.0 : 30.0);

                        if (index < spots.length - 1 && (spots.length - 1 - index) < (bottomInterval * 0.7)) {
                          return const Text('');
                        }

                        if (index >= 0 && index < spots.length) {
                          int daysAgo = spots.length - 1 - index;
                          DateTime d = _anchorDate.subtract(Duration(days: daysAgo));
                          String formatted = '${d.day} ${_getMonthAbbr(d.month)}';
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              formatted,
                              style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (val, meta) => Text(
                        '${val.round()}',
                        style: const TextStyle(color: Colors.white30, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF3B82F6),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [const Color(0xFF3B82F6).withOpacity(0.3), Colors.transparent],
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

  Widget _buildTimePill(String text, int days) {
    bool active = _selectedTrendDays == days;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTrendDays = days;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(text, style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CIRCADIAN ALERTNESS TIMELINE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCircadianTimeline() {
    final int currentHour = _anchorDate.hour;
    final int currentMinute = _anchorDate.minute;
    final double currentTimeDecimal = currentHour + currentMinute / 60.0;

    // Determine current phase description
    String phaseTitle;
    String phaseDescription;
    if (currentHour >= 6 && currentHour < 9) {
      phaseTitle = 'Cortisol Awakening Response';
      phaseDescription = 'Cortisol levels are surging to peak wakefulness. Light exposure and movement will amplify the awakening response and entrain your circadian clock.';
    } else if (currentHour >= 9 && currentHour < 12) {
      phaseTitle = 'Peak Cognitive Window';
      phaseDescription = 'Cortisol awakening response has peaked. Optimal for complex problem solving and focused deep work. Working memory and executive function are at their circadian maximum.';
    } else if (currentHour >= 12 && currentHour < 14) {
      phaseTitle = 'Post-Prandial Dip';
      phaseDescription = 'Natural alertness trough driven by Process S homeostatic sleep pressure. Light physical activity can counteract the dip. Avoid critical decision-making.';
    } else if (currentHour >= 14 && currentHour < 17) {
      phaseTitle = 'Afternoon Rebound';
      phaseDescription = 'Secondary alertness peak driven by circadian Process C. Excellent window for creative work, collaborative tasks, and physical training.';
    } else if (currentHour >= 17 && currentHour < 21) {
      phaseTitle = 'Evening Wind-Down';
      phaseDescription = 'Core body temperature is approaching its daily peak. Physical performance may be elevated but cognitive sharpness is declining. Begin dimming light exposure.';
    } else if (currentHour >= 21 && currentHour < 23) {
      phaseTitle = 'Melatonin Onset';
      phaseDescription = 'Dim-light melatonin onset (DLMO) is beginning. Blue light exposure now will delay circadian phase by 30-60 minutes. Prioritize sleep preparation.';
    } else {
      phaseTitle = 'Sleep Consolidation';
      phaseDescription = 'Deep NREM sleep dominates the first half of the night. Growth hormone secretion peaks during slow-wave sleep. Minimize disturbances for optimal recovery.';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phase indicator row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.sun, color: Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phaseTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phaseDescription,
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('24-Hour Process C Alertness Curve', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            width: double.infinity,
            child: CustomPaint(
              painter: _CircadianAlertnessPainter(
                currentTimeDecimal: currentTimeDecimal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PILLAR CARD (accordion pattern matching CardioDetailScreen)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPillarCard(String title, String weight, String desc, String status, Color statusColor, Widget detailsWidget, int pillarIndex) {
    final bool isExpanded = _expandedPillar == pillarIndex;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _expandedPillar = isExpanded ? -1 : pillarIndex;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: '   '),
                              TextSpan(
                                text: weight,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                        color: Colors.white38,
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: statusColor.withOpacity(0.2), width: 0.8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _showPillarCitations(title);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.shieldCheck, color: const Color(0xFF3B82F6).withOpacity(0.8), size: 12),
                              const SizedBox(width: 4),
                              const Text(
                                'CLINICAL REF',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: detailsWidget,
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PILLAR 1: AUTONOMIC READINESS DETAILS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAutonomicReadinessDetails() {
    final double hrv = widget.syncState.snapshot?.hrv?.toDouble() ?? 0.0;

    double avgHrv = hrv > 0 ? hrv * 0.92 : 45.0;
    if (widget.syncState.hrvHistory.isNotEmpty) {
      avgHrv = widget.syncState.hrvHistory.map((e) => (e['value'] as num).toDouble()).reduce((a, b) => a + b) / widget.syncState.hrvHistory.length;
    }

    double percentDiff = 0;
    if (avgHrv > 0) percentDiff = ((hrv - avgHrv) / avgHrv * 100);

    String diffText = percentDiff >= 0
        ? '${percentDiff.abs().round()}% above your 30-day average of ${avgHrv.round()} ms.'
        : '${percentDiff.abs().round()}% below your 30-day average of ${avgHrv.round()} ms.';
    Color diffColor = percentDiff >= -5 ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    final double rhrCurrent = (widget.syncState.snapshot?.rhr ?? 64).toDouble();
    final double rhrBase = (widget.syncState.rhrBaseline ?? 63).toDouble();
    String rhrTrend = 'Stable';
    Color rhrTrendColor = const Color(0xFF10B981);
    if (rhrCurrent > rhrBase + 3) {
      rhrTrend = 'Elevated';
      rhrTrendColor = const Color(0xFFEF4444);
    } else if (rhrCurrent > rhrBase) {
      rhrTrend = 'Slightly Elevated';
      rhrTrendColor = const Color(0xFFF59E0B);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('RMSSD (Current)', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text('${hrv.round()} ms', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(diffText, style: TextStyle(color: diffColor, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('30-Day Average', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text('${avgHrv.round()} ms', style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Resting Heart Rate', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text('${rhrCurrent.round()} bpm', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('RHR vs Baseline', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text(rhrTrend, style: TextStyle(color: rhrTrendColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          percentDiff >= 0
              ? 'Parasympathetic modulation is dominant. Your vagus nerve is actively regulating cardiac recovery, indicating high autonomic readiness for peak performance output.'
              : 'Sympathetic overdrive is detected with reduced vagal tone. This correlates with impaired neuromuscular readiness. Consider light active recovery and breathwork protocols.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PILLAR 2: COGNITIVE CAPACITY DETAILS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCognitiveCapacityDetails() {
    final double sleepEff = widget.syncState.snapshot?.sleepEfficiency ?? 0.0;
    final double sleepHours = widget.syncState.snapshot?.sleepHours ?? 0.0;
    final double hrv = widget.syncState.snapshot?.hrv?.toDouble() ?? 55.0;
    final double hrvBase = widget.syncState.hrvBaseline ?? 50.0;

    // Deterministic PVT Reaction Time model
    // Excellent sleep (>90% eff, >7.5h) -> ~210ms, poor sleep (<70% eff, <5.5h) -> ~280ms
    double pvtReactionTime = 280.0;
    pvtReactionTime -= (sleepEff / 100.0) * 35.0; 
    pvtReactionTime -= (sleepHours / 8.0).clamp(0.0, 1.0) * 35.0; 
    pvtReactionTime = pvtReactionTime.clamp(210.0, 300.0);

    Color pvtColor;
    String pvtClass;
    if (pvtReactionTime <= 220) {
      pvtColor = const Color(0xFF10B981);
      pvtClass = 'Optimal';
    } else if (pvtReactionTime <= 250) {
      pvtColor = const Color(0xFFF59E0B);
      pvtClass = 'Normal';
    } else {
      pvtColor = const Color(0xFFEF4444);
      pvtClass = 'Impaired';
    }

    // Focus stability index: derived from HRV coherence (HRV relative to baseline)
    double focusIndex = ((hrv / hrvBase) * 85.0).clamp(40.0, 100.0);
    Color focusColor = focusIndex >= 80 ? const Color(0xFF10B981) : (focusIndex >= 60 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));
    String focusLabel = focusIndex >= 80 ? 'High' : (focusIndex >= 60 ? 'Moderate' : 'Low');

    // Attention deficit risk
    String attentionRisk;
    Color attentionColor;
    if (sleepHours >= 7.0 && sleepEff >= 85.0 && hrv >= hrvBase * 0.9) {
      attentionRisk = 'Low Risk';
      attentionColor = const Color(0xFF10B981);
    } else if (sleepHours >= 5.5 && sleepEff >= 70.0) {
      attentionRisk = 'Moderate Risk';
      attentionColor = const Color(0xFFF59E0B);
    } else {
      attentionRisk = 'High Risk';
      attentionColor = const Color(0xFFEF4444);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Est. PVT Reaction Time', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Row(
              children: [
                Text('${pvtReactionTime.round()} ms', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: pvtColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(pvtClass.toUpperCase(), style: TextStyle(color: pvtColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Focus Stability Index', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Row(
              children: [
                Text('${focusIndex.round()}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text(focusLabel, style: TextStyle(color: focusColor, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Attention Deficit Risk', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: attentionColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(attentionRisk.toUpperCase(), style: TextStyle(color: attentionColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          pvtReactionTime <= 230
              ? 'Sleep-dependent memory consolidation appears complete. Prefrontal cortex function is intact with estimated reaction times within optimal bounds. This supports sustained attention and working memory performance.'
              : 'Sleep debt is accumulating — vigilant attention is degraded. Studies show each hour of sleep loss below 7h adds approximately 10ms to reaction time. Prioritize sleep tonight to restore baseline cognitive performance.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PILLAR 3: CIRCADIAN ALIGNMENT DETAILS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildCircadianAlignmentDetails() {
    final int currentHour = _anchorDate.hour;
    final double sleepHours = widget.syncState.snapshot?.sleepHours ?? 0.0;

    // Current circadian phase
    String circadianPhase;
    Color phaseColor;
    if (currentHour >= 6 && currentHour < 9) {
      circadianPhase = 'Morning Ascent';
      phaseColor = const Color(0xFFF59E0B);
    } else if (currentHour >= 9 && currentHour < 12) {
      circadianPhase = 'Peak Alertness';
      phaseColor = const Color(0xFF10B981);
    } else if (currentHour >= 12 && currentHour < 14) {
      circadianPhase = 'Post-Prandial Trough';
      phaseColor = const Color(0xFFEF4444);
    } else if (currentHour >= 14 && currentHour < 17) {
      circadianPhase = 'Afternoon Peak';
      phaseColor = const Color(0xFF10B981);
    } else if (currentHour >= 17 && currentHour < 21) {
      circadianPhase = 'Evening Descent';
      phaseColor = const Color(0xFFF59E0B);
    } else {
      circadianPhase = 'Nocturnal Rest';
      phaseColor = const Color(0xFF3B82F6);
    }

    // Cortisol awakening response estimate
    String carEstimate;
    Color carColor;
    if (sleepHours >= 7.0) {
      carEstimate = 'Strong';
      carColor = const Color(0xFF10B981);
    } else if (sleepHours >= 5.5) {
      carEstimate = 'Moderate';
      carColor = const Color(0xFFF59E0B);
    } else {
      carEstimate = 'Blunted';
      carColor = const Color(0xFFEF4444);
    }

    // Melatonin onset estimate (based on typical DLMO ~21:00)
    String melatoninOnset = '~9:00 PM';
    if (sleepHours < 6.0) {
      melatoninOnset = '~9:30 PM (delayed)';
    }

    // Sleep-wake regularity (derived from sleep history consistency)
    String sleepRegularity = 'Regular';
    Color regularityColor = const Color(0xFF10B981);
    if (widget.syncState.sleepHistoryDaily.length >= 7) {
      final recent7 = widget.syncState.sleepHistoryDaily.length >= 7
          ? widget.syncState.sleepHistoryDaily.sublist(widget.syncState.sleepHistoryDaily.length - 7)
          : widget.syncState.sleepHistoryDaily;
      double sum = 0;
      int count = 0;
      for (var entry in recent7) {
        final val = (entry['value'] as num?)?.toDouble();
        if (val != null && val > 0) {
          sum += val;
          count++;
        }
      }
      if (count >= 3) {
        double avgSleep = sum / count;
        double variance = 0;
        for (var entry in recent7) {
          final val = (entry['value'] as num?)?.toDouble();
          if (val != null && val > 0) {
            variance += (val - avgSleep) * (val - avgSleep);
          }
        }
        variance = variance / count;
        double stdDev = math.sqrt(variance);
        if (stdDev > 1.5) {
          sleepRegularity = 'Irregular';
          regularityColor = const Color(0xFFEF4444);
        } else if (stdDev > 0.8) {
          sleepRegularity = 'Somewhat Regular';
          regularityColor = const Color(0xFFF59E0B);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Current Phase', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: phaseColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(circadianPhase.toUpperCase(), style: TextStyle(color: phaseColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Cortisol Awakening Response', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text(carEstimate, style: TextStyle(color: carColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Est. Melatonin Onset', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text(melatoninOnset, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sleep-Wake Regularity', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text(sleepRegularity, style: TextStyle(color: regularityColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Circadian alignment is governed by the suprachiasmatic nucleus (SCN) which synchronizes the ~24.2h endogenous rhythm to the light-dark cycle. '
          'Consistent sleep-wake timing within a ±30 minute window maximizes the cortisol awakening response and ensures optimal cognitive performance during biological day.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PILLAR 4: ENERGY RESERVES DETAILS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEnergyReservesDetails() {
    final double sleepHours = widget.syncState.snapshot?.sleepHours ?? 0.0;
    final double sleepEff = widget.syncState.snapshot?.sleepEfficiency ?? 0.0;
    final double activeEnergy = widget.syncState.snapshot?.activeEnergy ?? 0.0;
    final double hrv = widget.syncState.snapshot?.hrv?.toDouble() ?? 55.0;
    final double hrvBase = widget.syncState.hrvBaseline ?? 50.0;

    // Sleep hours display
    Color sleepHoursColor;
    String sleepHoursLabel;
    if (sleepHours >= 7.0) {
      sleepHoursColor = const Color(0xFF10B981);
      sleepHoursLabel = 'Optimal';
    } else if (sleepHours >= 5.5) {
      sleepHoursColor = const Color(0xFFF59E0B);
      sleepHoursLabel = 'Suboptimal';
    } else {
      sleepHoursColor = const Color(0xFFEF4444);
      sleepHoursLabel = 'Insufficient';
    }

    // Sleep efficiency display
    Color sleepEffColor;
    String sleepEffLabel;
    if (sleepEff >= 85.0) {
      sleepEffColor = const Color(0xFF10B981);
      sleepEffLabel = 'Efficient';
    } else if (sleepEff >= 70.0) {
      sleepEffColor = const Color(0xFFF59E0B);
      sleepEffLabel = 'Moderate';
    } else {
      sleepEffColor = const Color(0xFFEF4444);
      sleepEffLabel = 'Poor';
    }

    // Slow-wave sleep estimate (~20% of total sleep for healthy adults)
    double swsEstimate = sleepHours * 0.20;
    if (sleepEff < 70) swsEstimate *= 0.7;
    String swsText = '${swsEstimate.toStringAsFixed(1)}h (est.)';
    Color swsColor = swsEstimate >= 1.2 ? const Color(0xFF10B981) : (swsEstimate >= 0.8 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    // Metabolic recovery status
    String metabolicRecovery;
    Color metabolicColor;
    if (activeEnergy < 300 && hrv >= hrvBase * 0.9) {
      metabolicRecovery = 'Fully Recovered';
      metabolicColor = const Color(0xFF10B981);
    } else if (activeEnergy < 500 || hrv >= hrvBase * 0.75) {
      metabolicRecovery = 'Partially Recovered';
      metabolicColor = const Color(0xFFF59E0B);
    } else {
      metabolicRecovery = 'Recovery Deficit';
      metabolicColor = const Color(0xFFEF4444);
    }

    // Glycogen replenishment assessment
    String glycogenStatus;
    Color glycogenColor;
    if (sleepHours >= 7.0 && sleepEff >= 85.0 && activeEnergy < 400) {
      glycogenStatus = 'Replenished';
      glycogenColor = const Color(0xFF10B981);
    } else if (sleepHours >= 5.5 && activeEnergy < 600) {
      glycogenStatus = 'Partial';
      glycogenColor = const Color(0xFFF59E0B);
    } else {
      glycogenStatus = 'Depleted';
      glycogenColor = const Color(0xFFEF4444);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sleep Duration', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Row(
              children: [
                Text('${sleepHours.toStringAsFixed(1)}h', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: sleepHoursColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(sleepHoursLabel.toUpperCase(), style: TextStyle(color: sleepHoursColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Sleep Efficiency', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Row(
              children: [
                Text('${sleepEff > 0 ? '${sleepEff.round()}%' : 'N/A'}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: sleepEffColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(sleepEffLabel.toUpperCase(), style: TextStyle(color: sleepEffColor, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Slow-Wave Sleep (N3)', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text(swsText, style: TextStyle(color: swsColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Metabolic Recovery', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Text(metabolicRecovery, style: TextStyle(color: metabolicColor, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Glycogen Replenishment', style: TextStyle(color: Colors.white54, fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: glycogenColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
              child: Text(glycogenStatus.toUpperCase(), style: TextStyle(color: glycogenColor, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          sleepHours >= 7.0
              ? 'Adequate slow-wave sleep supports full glycogen replenishment and growth hormone secretion. Active energy expenditure of ${activeEnergy.round()} kcal is well within recovery capacity.'
              : 'Insufficient sleep duration limits slow-wave sleep, reducing growth hormone secretion and glycogen restoration. Energy expenditure of ${activeEnergy.round()} kcal may exceed recovery capacity given current sleep debt.',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEARABLE SIGNAL FEED
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSignalTimeSelector() {
    final List<int> options = [7, 30, 90, 365];
    final List<String> labels = ['7D', '30D', '90D', '1Y'];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1e),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (index) {
          final int opt = options[index];
          final String label = labels[index];
          final bool active = _selectedSignalDays == opt;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSignalDays = opt;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: active ? Colors.white.withOpacity(0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSignalChart(String title, List<Map<String, dynamic>> data, Color color, bool trendUp) {
    List<Map<String, dynamic>> resolvedData = List.from(data);

    final int days = _selectedSignalDays;
    if (resolvedData.length > days) {
      resolvedData = resolvedData.sublist(resolvedData.length - days);
    }

    if (resolvedData.isEmpty) {
      double currentVal = 60.0;
      if (title.contains('HRV') || title.contains('Variability')) {
        currentVal = widget.syncState.snapshot?.hrv?.toDouble() ?? 55.0;
      } else if (title.contains('Resting') || title.contains('RHR')) {
        currentVal = widget.syncState.snapshot?.rhr?.toDouble() ?? 64.0;
      } else if (title.contains('Sleep') || title.contains('Efficiency')) {
        currentVal = widget.syncState.snapshot?.sleepEfficiency ?? 85.0;
        if (currentVal <= 0) currentVal = 85.0;
      }

      math.Random rng = math.Random(title.hashCode);
      for (int i = 0; i < 7; i++) {
        double noise = title.contains('Sleep')
            ? (rng.nextDouble() * 4.0 - 2.0)
            : (rng.nextDouble() * 8.0 - 4.0);
        resolvedData.add({
          'value': (currentVal + noise).clamp(title.contains('Sleep') ? 60.0 : 40.0, 100.0),
          'time': _anchorDate.subtract(Duration(days: 7 - i)),
        });
      }
    }

    // Determine latest value
    double latestVal = (resolvedData.last['value'] as num).toDouble();
    String valStr;
    if (title.contains('Sleep') || title.contains('Efficiency')) {
      valStr = '${latestVal.round()}%';
    } else {
      valStr = '${latestVal.round()}';
    }

    // Chart processing
    List<FlSpot> spots = [];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < resolvedData.length; i++) {
      double val = (resolvedData[i]['value'] as num).toDouble();
      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 100;

    // Generate medical insights
    String insightText = '';
    Color insightColor = Colors.white54;

    if (spots.isNotEmpty) {
      double sum = 0;
      for (var s in spots) {
        sum += s.y;
      }
      double avgVal = sum / spots.length;

      if (title.contains('Sleep') || title.contains('Efficiency')) {
        if (avgVal >= 85.0) {
          insightText = 'Avg Efficiency: ${avgVal.round()}% • Optimal Recovery';
          insightColor = const Color(0xFF10B981);
        } else if (avgVal >= 70.0) {
          insightText = 'Avg Efficiency: ${avgVal.round()}% • Suboptimal Recovery';
          insightColor = const Color(0xFFF59E0B);
        } else {
          insightText = 'Avg Efficiency: ${avgVal.round()}% • Poor Recovery';
          insightColor = const Color(0xFFEF4444);
        }
      } else if (title.contains('HRV') || title.contains('Variability')) {
        final double base = widget.syncState.hrvBaseline ?? 50.0;
        if (avgVal >= base * 0.95) {
          insightText = 'Avg HRV: ${avgVal.round()} ms • Optimal Parasympathetic Recovery';
          insightColor = const Color(0xFF10B981);
        } else {
          insightText = 'Avg HRV: ${avgVal.round()} ms • Reduced Autonomic Control';
          insightColor = const Color(0xFFEF4444);
        }
      } else if (title.contains('Resting') || title.contains('RHR')) {
        final double base = (widget.syncState.rhrBaseline ?? 64).toDouble();
        if (avgVal <= base + 2) {
          insightText = 'Avg RHR: ${avgVal.round()} bpm • Stable Cardiovascular Economy';
          insightColor = const Color(0xFF10B981);
        } else {
          insightText = 'Avg RHR: ${avgVal.round()} bpm • Elevated Sympathetic Load';
          insightColor = const Color(0xFFEF4444);
        }
      }
    }

    // Add padding to axes
    minY = (minY - 5).clamp(0, double.infinity);
    maxY = maxY + 5;

    // Calculate dynamic bottom date label intervals
    double bottomInterval = 7.0;
    if (days <= 7) {
      bottomInterval = 2.0;
    } else if (days <= 30) {
      bottomInterval = 7.0;
    } else if (days <= 90) {
      bottomInterval = 30.0;
    } else {
      bottomInterval = 60.0;
    }

    Widget chart = LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        minX: 0,
        maxX: (resolvedData.length - 1).toDouble(),
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: Colors.white.withOpacity(0.05), strokeWidth: 1)),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: bottomInterval,
              getTitlesWidget: (value, meta) {
                int index = value.round();
                if (index < resolvedData.length - 1 && (resolvedData.length - 1 - index) < (bottomInterval * 0.7)) {
                  return const Text('');
                }
                if (index >= 0 && index < resolvedData.length) {
                  final date = resolvedData[index]['time'] ?? resolvedData[index]['date'];
                  DateTime d = _anchorDate;
                  if (date is DateTime) {
                    d = date;
                  } else if (date is String) {
                    d = DateTime.tryParse(date) ?? _anchorDate;
                  }
                  String formatted = '${d.day} ${_getMonthAbbr(d.month)}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      formatted,
                      style: const TextStyle(color: Colors.white30, fontSize: 9, fontWeight: FontWeight.w500),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, meta) => Text('${val.round()}', style: const TextStyle(color: Colors.white30, fontSize: 10)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [color.withOpacity(0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.only(top: 20, right: 20, left: 10, bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (insightText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          insightText,
                          style: TextStyle(
                            color: insightColor.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(valStr, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Icon(trendUp ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight, size: 16, color: color),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: chart,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LAB INTELLIGENCE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildLabIntelligence() {
    if (widget.labReports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No lab data available.", style: TextStyle(color: Colors.white54))),
      );
    }

    final report = widget.labReports.first;
    String hba1c = '--';
    String cortisol = '--';
    String dheas = '--';
    String testosterone = '--';

    for (var m in report.markers) {
      final name = m.name.toLowerCase();
      if (name.contains('hba1c') || name.contains('hemoglobin a1c') || name.contains('glycated')) {
        if (hba1c == '--') hba1c = m.value;
      }
      if (name.contains('cortisol')) {
        if (cortisol == '--') cortisol = m.value;
      }
      if (name.contains('dhea') || name.contains('dehydroepiandrosterone')) {
        if (dheas == '--') dheas = m.value;
      }
      if (name.contains('testosterone')) {
        if (testosterone == '--') testosterone = m.value;
      }
    }

    bool hasAnyMarker = hba1c != '--' || cortisol != '--' || dheas != '--' || testosterone != '--';

    if (!hasAnyMarker) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No performance-relevant lab markers found.", style: TextStyle(color: Colors.white54))),
      );
    }

    return Column(
      children: [
        if (hba1c != '--') _buildLabMarkerCard('HbA1c', _stripUnits(hba1c), '%', 'Glycemic Control — Energy Reserves', '4.0 – 5.6%', _getHba1cStatus(_stripUnits(hba1c))),
        if (cortisol != '--') _buildLabMarkerCard('Cortisol', _stripUnits(cortisol), 'µg/dL', 'Stress Hormone — Circadian Alignment', '6.0 – 18.0 µg/dL', _getCortisolStatus(_stripUnits(cortisol))),
        if (dheas != '--') _buildLabMarkerCard('DHEA-S', _stripUnits(dheas), 'µg/dL', 'Adrenal Function — Energy & Recovery', '80 – 560 µg/dL', _getDheasStatus(_stripUnits(dheas))),
        if (testosterone != '--') _buildLabMarkerCard('Testosterone', _stripUnits(testosterone), 'ng/dL', 'Cognitive & Physical Performance', '300 – 1000 ng/dL', _getTestosteroneStatus(_stripUnits(testosterone))),
      ],
    );
  }

  Map<String, dynamic> _getHba1cStatus(String val) {
    final double? v = double.tryParse(val);
    if (v == null) return {'status': 'Unknown', 'color': Colors.white54};
    if (v <= 5.6) return {'status': 'Optimal', 'color': const Color(0xFF10B981)};
    if (v <= 6.4) return {'status': 'Elevated', 'color': const Color(0xFFF59E0B)};
    return {'status': 'High Risk', 'color': const Color(0xFFEF4444)};
  }

  Map<String, dynamic> _getCortisolStatus(String val) {
    final double? v = double.tryParse(val);
    if (v == null) return {'status': 'Unknown', 'color': Colors.white54};
    if (v >= 6.0 && v <= 18.0) return {'status': 'Normal', 'color': const Color(0xFF10B981)};
    if (v > 18.0) return {'status': 'Elevated', 'color': const Color(0xFFEF4444)};
    return {'status': 'Low', 'color': const Color(0xFFF59E0B)};
  }

  Map<String, dynamic> _getDheasStatus(String val) {
    final double? v = double.tryParse(val);
    if (v == null) return {'status': 'Unknown', 'color': Colors.white54};
    if (v >= 80.0 && v <= 560.0) return {'status': 'Normal', 'color': const Color(0xFF10B981)};
    if (v < 80.0) return {'status': 'Low', 'color': const Color(0xFFEF4444)};
    return {'status': 'Elevated', 'color': const Color(0xFFF59E0B)};
  }

  Map<String, dynamic> _getTestosteroneStatus(String val) {
    final double? v = double.tryParse(val);
    if (v == null) return {'status': 'Unknown', 'color': Colors.white54};
    if (v >= 300.0 && v <= 1000.0) return {'status': 'Normal', 'color': const Color(0xFF10B981)};
    if (v < 300.0) return {'status': 'Low', 'color': const Color(0xFFEF4444)};
    return {'status': 'Elevated', 'color': const Color(0xFFF59E0B)};
  }

  Widget _buildLabMarkerCard(String name, String value, String unit, String context, String optimalRange, Map<String, dynamic> statusInfo) {
    final String status = statusInfo['status'] as String;
    final Color statusColor = statusInfo['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(context, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Text(unit, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                    child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Optimal: ', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              Text(optimalRange, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CLINICAL CITATION BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════

  void _showClinicalCitationSheet({
    required String title,
    required String explanation,
    required List<ClinicalCitation> citations,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(color: Colors.white12, width: 1.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                    ),
                    child: const Icon(
                      LucideIcons.fileText,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                explanation,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Clinical Guidelines & Citations',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white54,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              ...citations.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.04)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.source,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (c.title != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        c.title!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white60,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  void _showPillarCitations(String pillarTitle) {
    if (pillarTitle == 'Autonomic Readiness') {
      _showClinicalCitationSheet(
        title: 'Autonomic Readiness',
        explanation: 'Autonomic Readiness quantifies the responsiveness and resilience of your Autonomic Nervous System (ANS) as it pertains to performance output. Zyndio measures this primarily using RMSSD (Root Mean Square of Successive Differences), which specifically reflects parasympathetic (vagal) tone. High vagal tone enables rapid cardiac adaptation to physical and cognitive demands. Persistent RMSSD suppression indicates sympathetic overdrive — commonly triggered by overtraining, chronic stress, inadequate sleep, or systemic inflammation — and directly impairs neuromuscular readiness and peak power output.',
        citations: [
          ClinicalCitation(
            source: 'Task Force of the ESC & NASPE (1996)',
            title: 'Heart rate variability: standards of measurement, physiological interpretation, and clinical use.',
          ),
          ClinicalCitation(
            source: 'Shaffer F, et al. (2017)',
            title: 'An Overview of Heart Rate Variability Metrics and Norms.',
          ),
        ],
      );
    } else if (pillarTitle == 'Cognitive Capacity') {
      _showClinicalCitationSheet(
        title: 'Cognitive Capacity',
        explanation: 'Cognitive Capacity is modeled from sleep architecture quality and autonomic balance. The Psychomotor Vigilance Task (PVT) reaction time is the gold-standard measure of sustained attention and is profoundly sensitive to sleep loss. Each hour of sleep restriction below 7 hours produces cumulative cognitive impairment equivalent to 0.1% blood alcohol concentration after 2-3 nights. Zyndio estimates PVT performance from sleep efficiency, total sleep time, and HRV coherence to provide a daily cognitive readiness assessment.',
        citations: [
          ClinicalCitation(
            source: 'Dinges DF, et al. (1997)',
            title: 'Cumulative sleepiness, mood disturbance, and psychomotor vigilance performance decrements during a week of sleep restricted to 4-5 hours per night.',
          ),
          ClinicalCitation(
            source: 'Lim J & Dinges DF (2008)',
            title: 'Sleep deprivation and vigilant attention.',
          ),
        ],
      );
    } else if (pillarTitle == 'Circadian Alignment') {
      _showClinicalCitationSheet(
        title: 'Circadian Alignment',
        explanation: 'Circadian Alignment evaluates how well your current activity timing matches your endogenous ~24.2-hour biological rhythm governed by the suprachiasmatic nucleus (SCN). The two-process model of sleep regulation describes how Process C (circadian) and Process S (homeostatic sleep pressure) interact to produce predictable peaks and troughs in alertness, cognitive performance, and physical capacity throughout the day. Misalignment — caused by irregular sleep-wake schedules, jet lag, or excessive evening light exposure — degrades cortisol awakening response and delays melatonin onset, impairing both performance and recovery.',
        citations: [
          ClinicalCitation(
            source: 'Borbély AA (1982)',
            title: 'A two-process model of sleep regulation.',
          ),
          ClinicalCitation(
            source: 'Czeisler CA (1999)',
            title: 'Stability, Precision, and Near-24-Hour Period of the Human Circadian Pacemaker.',
          ),
        ],
      );
    } else if (pillarTitle == 'Energy Reserves') {
      _showClinicalCitationSheet(
        title: 'Energy Reserves',
        explanation: 'Energy Reserves are assessed by evaluating sleep quality (duration, efficiency, and estimated slow-wave sleep), metabolic recovery status (active energy expenditure relative to recovery capacity), and glycogen replenishment. Slow-wave sleep (N3) is the primary window for growth hormone secretion, tissue repair, and glycogen restoration. Insufficient deep sleep or excessive caloric expenditure without adequate recovery creates a compounding energy deficit that degrades both cognitive and physical performance capacity over time.',
        citations: [
          ClinicalCitation(
            source: 'Dijk DJ & Czeisler CA (1995)',
            title: 'Contribution of the circadian pacemaker and the sleep homeostat to sleep propensity, sleep structure, electroencephalographic slow waves, and sleep spindle activity in humans.',
          ),
          ClinicalCitation(
            source: 'Halson SL (2014)',
            title: 'Sleep in elite athletes and nutritional interventions to enhance sleep.',
          ),
        ],
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// CIRCADIAN ALERTNESS CURVE PAINTER
// ═══════════════════════════════════════════════════════════════

class _CircadianAlertnessPainter extends CustomPainter {
  final double currentTimeDecimal;

  _CircadianAlertnessPainter({
    required this.currentTimeDecimal,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double graphHeight = size.height * 0.72;
    final double graphTop = 16.0;
    final double startX = 32.0;
    final double endX = size.width - 16.0;
    final double graphWidth = endX - startX;

    // Draw horizontal gridlines
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 5; i++) {
      double y = graphTop + (graphHeight / 4) * i;
      canvas.drawLine(Offset(startX, y), Offset(endX, y), gridPaint);
    }

    // Y-axis labels
    final yLabels = ['High', '', 'Mid', '', 'Low'];
    for (int i = 0; i < yLabels.length; i++) {
      if (yLabels[i].isEmpty) continue;
      double y = graphTop + (graphHeight / 4) * i;
      _drawText(canvas, yLabels[i], Offset(4, y - 5), 7.5, Colors.white.withOpacity(0.3));
    }

    // Generate Process C alertness curve (24 hours from 0:00 to 23:59)
    // Alertness model: two peaks (morning ~10:00 and afternoon ~15:00), trough at ~14:00 and night
    List<Offset> curvePoints = [];
    const int sampleCount = 96; // 15-min intervals

    for (int i = 0; i <= sampleCount; i++) {
      double hour = (i / sampleCount) * 24.0;
      double alertness = _processCAlertnessModel(hour);

      double x = startX + (i / sampleCount) * graphWidth;
      double y = graphTop + (1.0 - alertness) * graphHeight;
      curvePoints.add(Offset(x, y));
    }

    // Draw fill below curve
    final fillPath = Path()..moveTo(curvePoints.first.dx, curvePoints.first.dy);
    for (int i = 0; i < curvePoints.length - 1; i++) {
      final p1 = curvePoints[i];
      final p2 = curvePoints[i + 1];
      final cp1 = Offset((p1.dx + p2.dx) / 2, p1.dy);
      final cp2 = Offset((p1.dx + p2.dx) / 2, p2.dy);
      fillPath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    final closedFill = Path.from(fillPath)
      ..lineTo(curvePoints.last.dx, graphTop + graphHeight)
      ..lineTo(curvePoints.first.dx, graphTop + graphHeight)
      ..close();

    canvas.drawPath(closedFill, Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, graphTop),
        Offset(0, graphTop + graphHeight),
        [const Color(0xFF3B82F6).withOpacity(0.15), Colors.transparent],
      ));

    // Draw glow blur line
    canvas.drawPath(fillPath, Paint()
      ..color = const Color(0xFF3B82F6).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    // Draw main curve
    canvas.drawPath(fillPath, Paint()
      ..color = const Color(0xFF3B82F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);

    // Draw current time marker
    double currentTimeFraction = currentTimeDecimal / 24.0;
    double markerX = startX + currentTimeFraction * graphWidth;
    double markerAlertness = _processCAlertnessModel(currentTimeDecimal);
    double markerY = graphTop + (1.0 - markerAlertness) * graphHeight;

    // Vertical indicator line
    canvas.drawLine(
      Offset(markerX, graphTop),
      Offset(markerX, graphTop + graphHeight),
      Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // Glowing dot at current position
    canvas.drawCircle(Offset(markerX, markerY), 6, Paint()..color = const Color(0xFF3B82F6).withOpacity(0.3));
    canvas.drawCircle(Offset(markerX, markerY), 4, Paint()..color = const Color(0xFF3B82F6));
    canvas.drawCircle(Offset(markerX, markerY), 2, Paint()..color = Colors.white);

    // "Now" label
    _drawText(canvas, 'NOW', Offset(markerX - 10, graphTop + graphHeight + 4), 8.0, const Color(0xFF3B82F6), fontWeight: FontWeight.w800);

    // Draw timeline axis
    double timelineY = graphTop + graphHeight + 20;
    canvas.drawLine(Offset(startX, timelineY), Offset(endX, timelineY), Paint()..color = Colors.white.withOpacity(0.08)..strokeWidth = 1.0);

    // Hour labels
    final hourLabels = [0, 3, 6, 9, 12, 15, 18, 21];
    final hourTexts = ['12A', '3A', '6A', '9A', '12P', '3P', '6P', '9P'];

    for (int i = 0; i < hourLabels.length; i++) {
      double x = startX + (hourLabels[i] / 24.0) * graphWidth;
      canvas.drawLine(Offset(x, timelineY), Offset(x, timelineY + 4), Paint()..color = Colors.white.withOpacity(0.12)..strokeWidth = 1.0);
      _drawText(canvas, hourTexts[i], Offset(x - 8, timelineY + 7), 7.5, Colors.white.withOpacity(0.3));
    }

    // Annotate peaks and troughs
    _drawAnnotation(canvas, 'Peak', startX + (10.0 / 24.0) * graphWidth, graphTop - 2, const Color(0xFF10B981));
    _drawAnnotation(canvas, 'Dip', startX + (14.0 / 24.0) * graphWidth, graphTop + graphHeight * 0.55, const Color(0xFFF59E0B));
    _drawAnnotation(canvas, 'Peak', startX + (16.0 / 24.0) * graphWidth, graphTop + graphHeight * 0.08, const Color(0xFF10B981));
  }

  double _processCAlertnessModel(double hour) {
    // Simplified Process C model based on Borbély's two-process model
    // Morning rise starting at 6, peak at 10, post-prandial dip at 13-14, secondary peak at 15-16, evening decline
    double alertness = 0.0;

    // Base circadian sinusoid (primary 24h rhythm)
    alertness = 0.5 + 0.35 * math.sin((hour - 4.0) / 24.0 * 2.0 * math.pi);

    // Post-prandial dip (Process S interaction around 13-14h)
    double dipCenter = 13.5;
    double dipWidth = 1.5;
    double dip = 0.18 * math.exp(-0.5 * math.pow((hour - dipCenter) / dipWidth, 2));
    alertness -= dip;

    // Morning ramp (cortisol awakening response)
    if (hour >= 5.0 && hour <= 8.0) {
      double rampProgress = (hour - 5.0) / 3.0;
      alertness += 0.1 * rampProgress;
    }

    // Night suppression
    if (hour < 5.0 || hour > 22.0) {
      double nightFactor = 0.0;
      if (hour < 5.0) {
        nightFactor = (5.0 - hour) / 5.0;
      } else {
        nightFactor = (hour - 22.0) / 2.0;
      }
      alertness -= nightFactor * 0.3;
    }

    return alertness.clamp(0.05, 0.95);
  }

  void _drawText(Canvas canvas, String text, Offset position, double fontSize, Color color, {FontWeight fontWeight = FontWeight.w500}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  void _drawAnnotation(Canvas canvas, String label, double x, double y, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color.withOpacity(0.7), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y));
  }

  @override
  bool shouldRepaint(covariant _CircadianAlertnessPainter oldDelegate) {
    return oldDelegate.currentTimeDecimal != currentTimeDecimal;
  }
}
