import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zyndio_patient/providers/rhythm_provider.dart';
import '../../services/health_intelligence_service.dart';
import 'metric_detail_screen.dart';
import '../../data/health_repository.dart';
import '../../widgets/intelligence_glow_wrapper.dart';
import '../../config/theme.dart';
import 'widgets/dashboard_card_style.dart';

/// Enum to determine the type of performance detail screen.
enum PerformanceType { strain, recovery, sleep, stress, activity, energy }

/// A refined performance detail screen matching the Health Monitor aesthetic.
/// Replaces the gauge with a structured hero section, trend chart, and insights.
class PerformanceDetailScreen extends ConsumerStatefulWidget {
  final PerformanceType type;

  // Value data
  final int gaugePercent;
  final String stat1Label;
  final String stat1Value;
  final String stat1Unit;
  final String stat2Label;
  final String stat2Value;
  final String stat2Unit;
  final String coachingText;

  // Extra data for wiring
  final double? hrv;
  final int? rhr;
  final int? exerciseMinutes;
  final double? activeEnergy;
  final double? sleepHours;
  final int? stressScore;
  final int? energyScore;
  // New fields for real trend data
  final double? respiratoryRate;
  final int? bloodOxygen;
  final double? skinTemperature;
  final int? heartRateAvg;
  final int? heartRateMin;
  final int? heartRateMax;

  // Personal baselines for accurate score computation
  final double? hrvBaseline;
  final int? rhrBaseline;

  // Real history data for trend sparklines and drill-downs
  final List<Map<String, dynamic>> hrvHistory;
  final List<Map<String, dynamic>> rhrHistory;
  final List<Map<String, dynamic>> rrHistory;
  final List<Map<String, dynamic>> spo2History;
  final List<Map<String, dynamic>> sleepHistory;
  final List<Map<String, dynamic>> activeEnergyHistory;
  final List<Map<String, dynamic>> skinTempHistory;
  final List<Map<String, dynamic>> hrHistory;
  final List<Map<String, dynamic>> weeklySteps;

  const PerformanceDetailScreen({
    super.key,
    required this.type,
    required this.gaugePercent,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat1Unit,
    required this.stat2Label,
    required this.stat2Value,
    required this.stat2Unit,
    required this.coachingText,
    this.hrv,
    this.rhr,
    this.exerciseMinutes,
    this.activeEnergy,
    this.sleepHours,
    this.stressScore,
    this.energyScore,
    this.respiratoryRate,
    this.bloodOxygen,
    this.skinTemperature,
    this.heartRateAvg,
    this.heartRateMin,
    this.heartRateMax,
    this.hrvBaseline,
    this.rhrBaseline,
    this.hrvHistory = const [],
    this.rhrHistory = const [],
    this.rrHistory = const [],
    this.spo2History = const [],
    this.sleepHistory = const [],
    this.activeEnergyHistory = const [],
    this.skinTempHistory = const [],
    this.hrHistory = const [],
    this.weeklySteps = const [],
  });

  @override
  ConsumerState<PerformanceDetailScreen> createState() => _PerformanceDetailScreenState();
}

class _PerformanceDetailScreenState extends ConsumerState<PerformanceDetailScreen> {
  int _selectedTimeRange = 2; // Default to 1M
  final List<String> _timeRangeLabels = ['1D', '1W', '1M', '3M', '6M', '1Y'];
  final List<int> _timeRangeDays = [1, 7, 30, 90, 180, 365];
  
  List<Map<String, dynamic>> _displayData = [];
  String _stat1Value = '';
  String _stat2Value = '';

  @override
  void initState() {
    super.initState();
    _updateDisplayData();
  }

  void _updateDisplayData() {
    final history = _getHistoryForChart();
    final days = _timeRangeDays[_selectedTimeRange];
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    setState(() {
      _displayData = history.where((d) {
        final date = d['date'] as DateTime;
        return date.isAfter(cutoffDate);
      }).toList();

      if (_displayData.isNotEmpty) {
        final values = _displayData.map((d) => (d['value'] as num).toDouble()).toList();
        final maxVal = values.reduce(math.max);
        final minVal = values.reduce(math.min);
        
        if (widget.type == PerformanceType.energy) {
          _stat1Value = maxVal.round().toString();
          _stat2Value = minVal.round().toString();
        } else {
          _stat1Value = widget.stat1Value;
          _stat2Value = widget.stat2Value;
        }
      } else {
        _stat1Value = widget.stat1Value;
        _stat2Value = widget.stat2Value;
      }
    });
  }

  List<Map<String, dynamic>> _getHistoryForChart() {
    final bool is1D = _selectedTimeRange == 0;
    switch (widget.type) {
      case PerformanceType.strain:
        return _calculateStrainScoreHistory();
      case PerformanceType.recovery:
        return _calculateRecoveryScoreHistory();
      case PerformanceType.sleep:
        return _calculateSleepScoreHistory();
      case PerformanceType.stress:
        return is1D ? _calculateIntradayStressHistory() : _calculateStressScoreHistory();
      case PerformanceType.energy:
        return is1D ? _calculateIntradayEnergyHistory() : _calculateEnergyScoreHistory();
      case PerformanceType.activity:
        return widget.activeEnergyHistory;
    }
  }

  List<Map<String, dynamic>> _calculateIntradayStressHistory() {
    if (widget.hrHistory.isEmpty) return _calculateStressScoreHistory();
    return widget.hrHistory.map((e) {
      final score = HealthIntelligenceService.calculateStressScore(
        hrv: widget.hrv,
        heartRate: (e['value'] as num).toInt(),
        restingHeartRate: widget.rhr,
        hrvBaseline: widget.hrvBaseline,
      );
      return {'date': e['date'], 'value': score.toDouble()};
    }).toList();
  }

  List<Map<String, dynamic>> _calculateIntradayEnergyHistory() {
    // Rise/Peaks inspired Circadian Rhythm modeling
    final wakeTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 7, 0); // Default wake
    final double morningBase = widget.energyScore?.toDouble() ?? 85.0;
    
    return HealthIntelligenceService.calculateCircadianEnergyTrend(
      wakeTime: wakeTime,
      baseEnergy: morningBase,
    );
  }

  /// Computes daily energy scores from history.
  List<Map<String, dynamic>> _calculateEnergyScoreHistory() {
    // Build daily maps for RHR and Steps to avoid O(N^2) firstWhere calls and improve accuracy
    final Map<DateTime, int> rhrMap = {};
    for (var e in widget.rhrHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        rhrMap[DateTime(date.year, date.month, date.day)] = val.round();
      }
    }

    final Map<DateTime, int> stepsMap = {};
    for (var e in widget.weeklySteps) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        stepsMap[DateTime(date.year, date.month, date.day)] = val.round();
      }
    }

    final Map<DateTime, double> hrvMap = {};
    for (var e in widget.hrvHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        hrvMap[DateTime(date.year, date.month, date.day)] = val.toDouble();
      }
    }

    final Map<DateTime, double> sleepMap = {};
    for (var e in widget.sleepHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        sleepMap[DateTime(date.year, date.month, date.day)] = val.toDouble() / 60.0;
      }
    }

    final dates = {...hrvMap.keys, ...sleepMap.keys, ...rhrMap.keys}.toList()..sort();
    
    return dates.map((date) {
      final score = HealthIntelligenceService.calculateEnergyScore(
        sleepHours: sleepMap[date] ?? 0.0,
        hrv: hrvMap[date],
        steps: stepsMap[date] ?? 0,
        restingHeartRate: rhrMap[date] ?? widget.rhr,
        hrvBaseline: widget.hrvBaseline,
        rhrBaseline: widget.rhrBaseline,
      );
      return <String, dynamic>{'date': date, 'value': score.toDouble()};
    }).toList();
  }

  /// Computes daily strain scores from active energy + exercise history.
  /// Uses the same algorithm as the dashboard hero value.
  List<Map<String, dynamic>> _calculateStrainScoreHistory() {
    // Build per-day active energy map
    final Map<DateTime, double> energyMap = {};
    for (var e in widget.activeEnergyHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        final day = DateTime(date.year, date.month, date.day);
        energyMap[day] = val.toDouble();
      }
    }

    // Build per-day RHR and steps map for strain calculation
    final Map<DateTime, int> rhrMap = {};
    for (var e in widget.rhrHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        final day = DateTime(date.year, date.month, date.day);
        rhrMap[day] = val.round();
      }
    }
    final Map<DateTime, int> stepsMap = {};
    for (var e in widget.weeklySteps) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        stepsMap[DateTime(date.year, date.month, date.day)] = val.round();
      }
    }

    final dates = energyMap.keys.toList()..sort();

    return dates.map((date) {
      final energy = energyMap[date] ?? 0;
      // Estimate exercise minutes from energy (rough: ~8 kcal/min moderate)
      final estExerciseMin = (energy / 8.0).round().clamp(0, 180);
      final score = HealthIntelligenceService.calculateStrainScore(
        exerciseMinutes: estExerciseMin,
        restingHeartRate: rhrMap[date] ?? widget.rhr,
        steps: stepsMap[date] ?? 0,
      );
      return {'date': date, 'value': score.toDouble()};
    }).toList();
  }

  List<Map<String, dynamic>> _calculateSleepScoreHistory() {
    return widget.sleepHistory.map((d) {
      final value = d['value'];
      final date = d['date'];
      if (value == null || date == null) return null;
      final hours = (value as num).toDouble() / 60.0;
      final score = HealthIntelligenceService.calculateSleepScore(sleepHours: hours);
      return {'date': date, 'value': score.toDouble()};
    }).whereType<Map<String, dynamic>>().toList();
  }

  List<Map<String, dynamic>> _calculateRecoveryScoreHistory() {
    final Map<DateTime, double> hrvMap = {};
    for (var e in widget.hrvHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        final day = DateTime(date.year, date.month, date.day);
        hrvMap[day] = val.toDouble();
      }
    }

    final Map<DateTime, double> rhrMap = {};
    for (var e in widget.rhrHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        final day = DateTime(date.year, date.month, date.day);
        rhrMap[day] = val.toDouble();
      }
    }

    final Map<DateTime, double> sleepMap = {};
    for (var e in widget.sleepHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        final day = DateTime(date.year, date.month, date.day);
        sleepMap[day] = val.toDouble() / 60.0;
      }
    }

    final dates = {...hrvMap.keys, ...rhrMap.keys, ...sleepMap.keys}.toList()..sort();
    
    return dates.map((date) {
      final score = HealthIntelligenceService.calculateRecoveryScore(
        hrv: hrvMap[date],
        restingHeartRate: rhrMap[date]?.round(),
        sleepHours: sleepMap[date] ?? 0.0,
        hrvBaseline: widget.hrvBaseline,
        rhrBaseline: widget.rhrBaseline,
      );
      return {'date': date, 'value': score.toDouble()};
    }).toList();
  }

  List<Map<String, dynamic>> _calculateStressScoreHistory() {
    final Map<DateTime, double> hrvMap = {};
    for (var e in widget.hrvHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        final day = DateTime(date.year, date.month, date.day);
        hrvMap[day] = val.toDouble();
      }
    }

    final Map<DateTime, double> rhrMap = {};
    for (var e in widget.rhrHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num) {
        final day = DateTime(date.year, date.month, date.day);
        rhrMap[day] = val.toDouble();
      }
    }

    // Build per-day average HR from intraday HR history for sympathetic component
    final Map<DateTime, int> hrAvgMap = {};
    final Map<DateTime, List<int>> hrDayBuckets = {};
    for (var e in widget.hrHistory) {
      final date = e['date'];
      final val = e['value'];
      if (date is DateTime && val is num && val > 0) {
        final day = DateTime(date.year, date.month, date.day);
        hrDayBuckets.putIfAbsent(day, () => []).add(val.round());
      }
    }
    for (var entry in hrDayBuckets.entries) {
      final values = entry.value;
      hrAvgMap[entry.key] = (values.reduce((a, b) => a + b) / values.length).round();
    }
    
    final dates = {...hrvMap.keys, ...rhrMap.keys, ...hrAvgMap.keys}.toList()..sort();
    
    return dates.map((date) {
      final score = HealthIntelligenceService.calculateStressScore(
        hrv: hrvMap[date],
        heartRate: hrAvgMap[date],
        restingHeartRate: rhrMap[date]?.round(),
        hrvBaseline: widget.hrvBaseline,
      );
      return {'date': date, 'value': score.toDouble()};
    }).toList();
  }

  String get _title {
    switch (widget.type) {
      case PerformanceType.strain: return 'Strain';
      case PerformanceType.recovery: return 'Recovery';
      case PerformanceType.sleep: return 'Sleep';
      case PerformanceType.stress: return 'Stress';
      case PerformanceType.activity: return 'Activity';
      case PerformanceType.energy: return 'Body Battery';
    }
  }

  String get _unit {
    switch (widget.type) {
      case PerformanceType.strain: return '%';
      case PerformanceType.recovery: return '%';
      case PerformanceType.sleep: return '%';
      case PerformanceType.stress: return '';
      case PerformanceType.activity: return 'kcal';
      case PerformanceType.energy: return '%';
    }
  }

  Color get _primaryColor {
    switch (widget.type) {
      case PerformanceType.strain: return const Color(0xFFF97316);
      case PerformanceType.recovery: return const Color(0xFF10B981);
      case PerformanceType.sleep: return const Color(0xFF6366F1);
      case PerformanceType.stress: return const Color(0xFFF59E0B);
      case PerformanceType.activity: return const Color(0xFFEF4444);
      case PerformanceType.energy: return const Color(0xFF22C55E);
    }
  }

  String get _statusText {
    final v = widget.gaugePercent;
    switch (widget.type) {
      case PerformanceType.strain:
        return v >= 20 ? 'Optimal' : 'Low Intensity';
      case PerformanceType.recovery:
        return v >= 60 ? 'Optimal' : 'Needs Recovery';
      case PerformanceType.sleep:
        return v >= 70 ? 'High Quality' : 'Needs Sleep';
      case PerformanceType.stress:
        return v <= 40 ? 'Low Stress' : 'High Stress';
      case PerformanceType.activity:
        return 'Active';
      case PerformanceType.energy:
        return v >= 70 ? 'High Energy' : (v >= 30 ? 'Moderate' : 'Low Battery');
    }
  }

  String get _targetRange {
    switch (widget.type) {
      case PerformanceType.strain: return '20 – 40 %';
      case PerformanceType.recovery: return '60 – 100 %';
      case PerformanceType.sleep: return '70 – 100 %';
      case PerformanceType.stress: return '0 – 40';
      case PerformanceType.activity: return '500+ kcal';
      case PerformanceType.energy: return '70 – 100 %';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${now.day} ${monthNames[now.month - 1]} ${now.year}';

    return Scaffold(
      backgroundColor: context.nc.isDark ? context.nc.scaffoldBg : const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Hero Section
                    Container(
                      color: context.nc.scaffoldBg,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildValueSection(dateStr),
                          const SizedBox(height: 24),
                          _buildChartSection(),
                          const SizedBox(height: 20),
                          _buildTimeRangeSelector(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Stats & Breakdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsGrid(),
                          const SizedBox(height: 24),
                          if (widget.coachingText.isNotEmpty) ...[
                            _buildCoachingCard(),
                            const SizedBox(height: 24),
                          ],
                          if (widget.type == PerformanceType.stress) ...[
                            _buildStressBreakdown(),
                            const SizedBox(height: 24),
                          ],
                          if (widget.type == PerformanceType.energy) ...[
                            _buildEnergyBreakdown(),
                            const SizedBox(height: 24),
                          ],
                          _buildTrendsSection(),
                          const SizedBox(height: 24),
                          _buildAboutSection(),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStressBreakdown() {
    // We compute a simulated breakdown based on the gauge value if we don't have real intraday data
    final v = widget.gaugePercent;
    // Map stress level to breakdown percentages
    double high = (v > 75 ? (v - 75) / 25.0 * 0.4 + 0.1 : 0.05).clamp(0.0, 1.0);
    double med = (v > 50 ? (v - 50) / 25.0 * 0.5 + 0.2 : (v > 25 ? (v - 25) / 25.0 * 0.3 : 0.1)).clamp(0.0, 1.0);
    double low = (v > 25 ? (100 - v) / 75.0 * 0.6 : 0.7).clamp(0.0, 1.0);
    double rest = (v < 25 ? (25 - v) / 25.0 * 0.8 + 0.1 : 0.05).clamp(0.0, 1.0);
    
    // Normalize to 1.0
    double sum = high + med + low + rest;
    high /= sum; med /= sum; low /= sum; rest /= sum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Stress Breakdown',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.nc.textPrimary),
        ),
        const SizedBox(height: 16),
        _buildBreakdownRow('High', high, const Color(0xFFEF4444)),
        const SizedBox(height: 12),
        _buildBreakdownRow('Medium', med, const Color(0xFFFBBF24)),
        const SizedBox(height: 12),
        _buildBreakdownRow('Low', low, const Color(0xFF34D399)),
        const SizedBox(height: 12),
        _buildBreakdownRow('Rest', rest, const Color(0xFF60A5FA)),
      ],
    );
  }

  Widget _buildEnergyBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Energy Status',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.nc.textPrimary),
        ),
        const SizedBox(height: 16),
        DashboardCard(
          child: Column(
            children: [
              Row(
                children: [
                  Icon(LucideIcons.batteryMedium, size: 20, color: _primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Body Battery',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.nc.textPrimary),
                    ),
                  ),
                  Text(
                    '${widget.gaugePercent}%',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.gaugePercent / 100.0,
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your energy levels are ${widget.gaugePercent >= 70 ? "high" : (widget.gaugePercent >= 30 ? "moderate" : "low")}. Plan your activities accordingly.',
                style: TextStyle(fontSize: 13, color: context.nc.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, double pct, Color color) {
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.nc.textPrimary))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: color.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${(pct * 100).round()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.nc.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: context.nc.scaffoldBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.nc.cardSurface,
                shape: BoxShape.circle,
                border: Border.all(color: context.nc.cardBorder, width: 1.5),
              ),
              child: Icon(Icons.close, size: 20, color: context.nc.textPrimary),
            ),
          ),
          Expanded(
            child: Text(
              _title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.nc.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  void _openMetricDetail(String title, String value, String unit, List<Map<String, dynamic>> history, Color color) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => MetricDetailScreen(
          title: title,
          currentValue: value,
          unit: unit,
          historyData: history,
          color: color,
          insight: '', 
          healthRepository: HealthRepository(),
        ),
      ),
    );
  }

  Widget _buildValueSection(String dateStr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${widget.gaugePercent}',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: context.nc.textPrimary,
                        letterSpacing: -1.5,
                      ),
                    ),
                    if (_unit.isNotEmpty)
                      TextSpan(
                        text: ' $_unit',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: context.nc.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 14,
                  color: context.nc.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _statusText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '',
                  style: TextStyle(
                    fontSize: 16,
                    color: context.nc.textTertiary,
                  ),
                ),
                Text(
                  _targetRange,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.nc.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    if (_displayData.isEmpty) {
      return SizedBox(
        height: 240, 
        child: Center(
          child: Text(
            "No historical data available",
            style: TextStyle(color: context.nc.textTertiary),
          )
        )
      );
    }

    final spots = _displayData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble());
    }).toList();

    double maxVal = 0;
    for (var d in _displayData) {
      final v = (d['value'] as num).toDouble();
      if (v > maxVal) maxVal = v;
    }
    if (maxVal == 0) maxVal = 100;
    final double yInterval = (maxVal / 5).ceilToDouble().clamp(1.0, 1000.0);

    return Container(
      height: 280,
      width: double.infinity,
      decoration: null, // Removed the box as requested
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 12),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.nc.divider.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(color: context.nc.textTertiary, fontSize: 11),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: _selectedTimeRange == 0 ? 12 : 30, // Show labels every 3 hours
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value >= _displayData.length) return const SizedBox.shrink();
                        final date = _displayData[value.toInt()]['date'] as DateTime;
                        
                        String label;
                        if (_selectedTimeRange == 0) {
                          // Show labels at clear intervals
                          if (value.toInt() % 12 != 0) return const SizedBox.shrink();
                          
                          final hour = date.hour;
                          final ampm = hour >= 12 ? 'PM' : 'AM';
                          final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                          label = '$displayHour$ampm';
                        } else {
                          final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                          label = '${date.day} ${months[date.month - 1]}';
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: TextStyle(color: context.nc.textTertiary, fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: _buildLineBars(spots),
                extraLinesData: ExtraLinesData(
                  verticalLines: [
                    if (widget.type == PerformanceType.energy && _selectedTimeRange == 0)
                      VerticalLine(
                        x: _findNowIndex().toDouble(),
                        color: Colors.white.withOpacity(0.3),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                      ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => context.nc.isDark ? const Color(0xFF1F2937) : Colors.black,
                    getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                      return LineTooltipItem(
                        '${s.y.round()}$_unit',
                        TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.bold),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          if (widget.type == PerformanceType.energy && _selectedTimeRange == 0)
            _buildTaskIconsOverlay(spots),
        ],
      ),
    );
  }

  Widget _buildTaskIconsOverlay(List<FlSpot> spots) {
    final rhythm = ref.watch(dailyRhythmProvider).rhythm.value;
    if (rhythm == null || rhythm.tasks.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth - 40; // Subtract title reservation
        final double height = constraints.maxHeight - 36; // Subtract bottom titles
        
        final List<Widget> iconWidgets = [];
        for (var task in rhythm.tasks) {
          final taskTime = _parseTime(task.time);
          if (taskTime == null) continue;

          // Find closest spot to this time
          int closestIdx = -1;
          Duration minDiff = const Duration(days: 1);
          for (int i = 0; i < _displayData.length; i++) {
            final diff = (_displayData[i]['date'] as DateTime).difference(taskTime).abs();
            if (diff < minDiff) {
              minDiff = diff;
              closestIdx = i;
            }
          }

          if (closestIdx != -1 && minDiff.inMinutes < 30) {
            final spot = spots[closestIdx];
            // Map spot index to X
            final x = (closestIdx / (_displayData.length - 1)) * width;
            // Map spot value to Y (normalized to maxVal)
            double maxVal = spots.map((s) => s.y).reduce(math.max);
            if (maxVal == 0) maxVal = 100;
            final y = height - (spot.y / maxVal) * (height - 40) - 40;

            iconWidgets.add(
              Positioned(
                left: x + 8, // Offset from left titles
                top: y,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _getTaskColor(task.category).withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, spreadRadius: 1),
                    ],
                  ),
                  child: Icon(task.icon, size: 14, color: Colors.white),
                ),
              ),
            );
          }
        }
        return Stack(children: iconWidgets);
      },
    );
  }

  DateTime? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    try {
      final now = DateTime.now();
      if (timeStr.toLowerCase().contains('am') || timeStr.toLowerCase().contains('pm')) {
        final parts = timeStr.split(RegExp(r'[:\s]'));
        int hour = int.parse(parts[0]);
        int minute = parts.length > 2 ? int.parse(parts[1]) : 0;
        if (timeStr.toLowerCase().contains('pm') && hour < 12) hour += 12;
        if (timeStr.toLowerCase().contains('am') && hour == 12) hour = 0;
        return DateTime(now.year, now.month, now.day, hour, minute);
      }
      // Fallback for named windows
      if (timeStr.contains('Morning')) return DateTime(now.year, now.month, now.day, 8, 0);
      if (timeStr.contains('Noon')) return DateTime(now.year, now.month, now.day, 13, 0);
      if (timeStr.contains('Evening')) return DateTime(now.year, now.month, now.day, 19, 0);
    } catch (_) {}
    return null;
  }

  Color _getTaskColor(String category) {
    switch (category.toLowerCase()) {
      case 'diet': return const Color(0xFF10B981);
      case 'fitness': return const Color(0xFFEF4444);
      case 'supplement': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF3B82F6);
    }
  }

  Widget _buildTimeRangeSelector() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.nc.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_timeRangeLabels.length, (index) {
          final isSelected = _selectedTimeRange == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTimeRange = index);
                _updateDisplayData();
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? context.nc.textPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  _timeRangeLabels[index],
                  style: TextStyle(
                    color: isSelected 
                        ? context.nc.scaffoldBg
                        : context.nc.textSecondary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(widget.stat1Label, _stat1Value, widget.stat1Unit)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(widget.stat2Label, _stat2Value, widget.stat2Unit)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, String unit) {
    IconData icon;
    if (label.toLowerCase().contains('hrv')) {
      icon = LucideIcons.activity;
    } else if (label.toLowerCase().contains('hr') || label.toLowerCase().contains('heart')) {
      icon = LucideIcons.heart;
    } else if (label.toLowerCase().contains('duration') || label.toLowerCase().contains('time')) {
      icon = LucideIcons.clock;
    } else if (label.toLowerCase().contains('energy') || label.toLowerCase().contains('cal')) {
      icon = LucideIcons.zap;
    } else if (label.toLowerCase().contains('bed')) {
      icon = LucideIcons.bedDouble;
    } else if (label.toLowerCase().contains('asleep')) {
      icon = LucideIcons.moon;
    } else {
      icon = LucideIcons.barChart2;
    }

    return DashboardCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: context.nc.textTertiary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.nc.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.nc.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.nc.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachingCard() {
    return IntelligenceGlowWrapper(
      child: DashboardCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/intelligence_logo_text.png',
              height: 16,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              widget.coachingText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.nc.textPrimary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsSection() {
    final List<_TrendCardData> trends = _getTrendCards();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trends',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.nc.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: trends.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final t = trends[index];
            return GestureDetector(
              onTap: () => _openMetricDetail(t.title, t.value, t.unit, t.history, t.color),
              child: DashboardCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            style: TextStyle(color: context.nc.textTertiary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: t.value,
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: context.nc.textPrimary),
                                ),
                                if (t.unit.isNotEmpty)
                                  TextSpan(
                                    text: ' ${t.unit}',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.nc.textTertiary),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildMiniSparkline(t.history, t.color),
                    const SizedBox(width: 12),
                    Icon(LucideIcons.chevronRight, size: 18, color: context.nc.textTertiary),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMiniSparkline(List<Map<String, dynamic>> history, Color color) {
    if (history.length < 2) return const SizedBox(width: 60, height: 30);
    final spots = history.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['value'] as num).toDouble())).toList();
    
    return SizedBox(
      width: 70,
      height: 35,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  List<_TrendCardData> _getTrendCards() {
    String fmt(double? v, {int decimals = 1}) =>
        v != null && v > 0 ? v.toStringAsFixed(decimals) : '--';

    switch (widget.type) {
      case PerformanceType.strain:
        return [
          _TrendCardData('Strain Score', '${widget.gaugePercent}', '%', widget.gaugePercent >= 20, _calculateStrainScoreHistory(), _primaryColor),
          _TrendCardData('Exercise Duration', '${widget.exerciseMinutes ?? 0}', 'min', true, const [], _primaryColor),
          _TrendCardData('Calories Burned', '${widget.activeEnergy?.round() ?? 0}', 'kcal', true, widget.activeEnergyHistory, _primaryColor),
          _TrendCardData('Avg Heart Rate', widget.heartRateAvg != null ? '${widget.heartRateAvg}' : '--', 'bpm', true, widget.hrHistory, _primaryColor),
        ];
      case PerformanceType.recovery:
        return [
          _TrendCardData('Recovery Score', '${widget.gaugePercent}', '%', widget.gaugePercent >= 60, _calculateRecoveryScoreHistory(), _primaryColor),
          _TrendCardData('Resting HRV', fmt(widget.hrv), 'ms', (widget.hrv ?? 0) >= 40, widget.hrvHistory, _primaryColor),
          _TrendCardData('Resting HR', widget.rhr != null ? '${widget.rhr}' : '--', 'bpm', (widget.rhr ?? 80) <= 70, widget.rhrHistory, _primaryColor),
          _TrendCardData('Respiratory Rate', fmt(widget.respiratoryRate), 'rpm', true, widget.rrHistory, _primaryColor),
        ];
      case PerformanceType.sleep:
        return [
          _TrendCardData('Sleep Score', '${widget.gaugePercent}', '%', widget.gaugePercent >= 70, _calculateSleepScoreHistory(), _primaryColor),
          _TrendCardData('Time Asleep', fmt(widget.sleepHours), 'hrs', (widget.sleepHours ?? 0) >= 7, _calculateSleepScoreHistory(), _primaryColor),
          _TrendCardData('Resting HRV', fmt(widget.hrv), 'ms', (widget.hrv ?? 0) >= 40, widget.hrvHistory, _primaryColor),
        ];
      case PerformanceType.stress:
        return [
          _TrendCardData('Stress Score', '${widget.gaugePercent}', '', widget.gaugePercent <= 40, _calculateStressScoreHistory(), _primaryColor),
          _TrendCardData('Energy Level', '${widget.energyScore ?? 0}', '%', (widget.energyScore ?? 50) >= 50, _calculateEnergyScoreHistory(), _primaryColor),
          _TrendCardData('HRV', fmt(widget.hrv), 'ms', (widget.hrv ?? 0) >= 40, widget.hrvHistory, _primaryColor),
        ];
      case PerformanceType.energy:
        return [
          _TrendCardData('Body Battery', '${widget.gaugePercent}', '%', widget.gaugePercent >= 60, _calculateEnergyScoreHistory(), _primaryColor),
          _TrendCardData('Sleep Score', '${widget.gaugePercent}', '%', widget.gaugePercent >= 70, _calculateSleepScoreHistory(), _primaryColor),
          _TrendCardData('Recovery', '${widget.energyScore ?? 0}', '%', true, _calculateRecoveryScoreHistory(), _primaryColor),
          _TrendCardData('Stress', '${widget.stressScore ?? 0}', '', false, _calculateStressScoreHistory(), _primaryColor),
        ];
      case PerformanceType.activity:
        return [
          _TrendCardData('Move', '${widget.activeEnergy?.round() ?? 0}', 'kcal', true, widget.activeEnergyHistory, _primaryColor),
          _TrendCardData('Training', '${widget.exerciseMinutes ?? 0}', 'min', true, const [], _primaryColor),
          _TrendCardData('Peak HR', widget.heartRateMax != null ? '${widget.heartRateMax}' : '--', 'bpm', true, widget.hrHistory, _primaryColor),
        ];
    }
  }

  List<LineChartBarData> _buildLineBars(List<FlSpot> spots) {
    if (widget.type != PerformanceType.energy || _selectedTimeRange != 0) {
      return [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: _primaryColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_primaryColor.withOpacity(0.2), _primaryColor.withOpacity(0)],
            ),
          ),
        ),
      ];
    }

    final nowIdx = _findNowIndex();
    final actualSpots = spots.sublist(0, math.min(nowIdx + 1, spots.length));
    final predictedSpots = spots.sublist(math.max(0, nowIdx), spots.length);

    return [
      // ACTUAL (Solid)
      LineChartBarData(
        spots: actualSpots,
        isCurved: true,
        curveSmoothness: 0.2,
        color: Colors.white,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF6366F1).withOpacity(0.3), const Color(0xFF6366F1).withOpacity(0)],
          ),
        ),
      ),
      // PREDICTED (Dashed)
      LineChartBarData(
        spots: predictedSpots,
        isCurved: true,
        curveSmoothness: 0.2,
        color: Colors.white.withOpacity(0.4),
        barWidth: 2,
        dashArray: [5, 5],
        dotData: const FlDotData(show: false),
      ),
    ];
  }

  int _findNowIndex() {
    if (_displayData.isEmpty) return 0;
    final now = DateTime.now();
    int closestIdx = 0;
    Duration minDiff = const Duration(days: 1);
    for (int i = 0; i < _displayData.length; i++) {
      final diff = (_displayData[i]['date'] as DateTime).difference(now).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  Widget _buildAboutSection() {
    String description = '';
    switch (widget.type) {
      case PerformanceType.strain:
        description = 'Strain measures your cardiovascular exertion. It tracks how hard your heart is working throughout the day based on intensity and duration.';
        break;
      case PerformanceType.recovery:
        description = 'Recovery measures how prepared your body is for stress. It is calculated using Heart Rate Variability (HRV), Resting Heart Rate (RHR), and sleep.';
        break;
      case PerformanceType.sleep:
        description = 'Sleep Score evaluates your sleep quality and duration. Quality sleep is essential for muscle repair, cognitive function, and health.';
        break;
      case PerformanceType.stress:
        description = 'Stress is calculated by analyzing heart rate variability (HRV) in real-time, representing the physiological load on your autonomic nervous system.';
        break;
      case PerformanceType.activity:
        description = 'Activity tracks daily movement including steps and calories. Consistent movement is key for longevity.';
        break;
      case PerformanceType.energy:
        description = 'Body Battery (Energy) tracks your energy reserves throughout the day. It is calculated by balancing sleep recovery against physical activity and stress.';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About $_title',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.nc.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        DashboardCard(
          padding: const EdgeInsets.all(20),
          child: Text(
            description,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.nc.textSecondary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrendCardData {
  final String title;
  final String value;
  final String unit;
  final bool isGood;
  final List<Map<String, dynamic>> history;
  final Color color;

  _TrendCardData(this.title, this.value, this.unit, this.isGood, this.history, this.color);
}
