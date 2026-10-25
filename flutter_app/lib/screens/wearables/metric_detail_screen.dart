import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/health_repository.dart';
import '../../config/theme.dart';

/// Defines the data model for a metric that can be displayed in the detail screen.
class MetricInfo {
  final String title;
  final String emoji;
  final String normalRange;
  final String description;
  final double? normalLow;
  final double? normalHigh;

  const MetricInfo({
    required this.title,
    required this.emoji,
    required this.normalRange,
    required this.description,
    this.normalLow,
    this.normalHigh,
  });
}

/// Static registry of metric info for all Health Monitor metrics.
class MetricRegistry {
  static const Map<String, MetricInfo> metrics = {
    'Respiratory Rate': MetricInfo(
      title: 'Respiratory Rate',
      emoji: '',
      normalRange: '12.0 – 20.0 rpm',
      normalLow: 12.0,
      normalHigh: 20.0,
      description: 'Respiratory Rate (RR) tracks your breaths per minute during sleep.\n\n'
          'It calculates your average rate over the whole night from the rhythmic pattern of your heartbeat as you inhale and exhale.\n\n'
          'RR is usually stable night to night, so big shifts likely have meaning. Causes may be illness, tiredness, allergies or altitude changes. '
          'Unusually high or low RR could indicate health problems.',
    ),
    'Resting Heart Rate': MetricInfo(
      title: 'Resting Heart Rate',
      emoji: '',
      normalRange: '50 – 80 bpm',
      normalLow: 50,
      normalHigh: 80,
      description: 'Resting Heart Rate (RHR) is the number of times your heart beats per minute while completely at rest.\n\n'
          'A lower resting heart rate generally indicates better cardiovascular fitness. Athletes often have RHR below 60 bpm.\n\n'
          'RHR can be affected by stress, caffeine, illness, dehydration, and overtraining. '
          'Tracking it over time helps identify trends in your cardiovascular health.',
    ),
    'Heart Rate Variability': MetricInfo(
      title: 'Heart Rate Variability',
      emoji: '',
      normalRange: '20 – 100 ms',
      normalLow: 20,
      normalHigh: 100,
      description: 'Heart Rate Variability (HRV) measures the variation in time between each heartbeat.\n\n'
          'Higher HRV generally indicates better cardiovascular fitness and stress resilience. '
          'It reflects the balance between your sympathetic (fight-or-flight) and parasympathetic (rest-and-digest) nervous systems.\n\n'
          'HRV is influenced by sleep quality, stress, exercise, alcohol, and recovery status.',
    ),
    'Blood Oxygen': MetricInfo(
      title: 'Blood Oxygen',
      emoji: '',
      normalRange: '95 – 100 %',
      normalLow: 95,
      normalHigh: 100,
      description: 'Blood Oxygen Saturation (SpO₂) measures the percentage of oxygen-carrying hemoglobin in your blood.\n\n'
          'Normal levels are typically between 95-100%. Levels below 95% may indicate respiratory issues.\n\n'
          'SpO₂ can be affected by altitude, respiratory conditions, sleep apnea, and intense exercise. '
          'Monitoring trends can help identify potential breathing issues during sleep.',
    ),
    'Skin Temperature': MetricInfo(
      title: 'Skin Temperature',
      emoji: '',
      normalRange: '35.5 – 37.0 °C',
      normalLow: 35.5,
      normalHigh: 37.0,
      description: 'Skin Temperature tracks deviations from your personal baseline body temperature.\n\n'
          'Changes in skin temperature can indicate illness, hormonal cycles, or environmental factors.\n\n'
          'Consistent tracking helps establish your baseline and detect anomalies early.',
    ),
    'Sleep Duration': MetricInfo(
      title: 'Sleep Duration',
      emoji: '',
      normalRange: '7.0 – 9.0 hrs',
      normalLow: 7.0,
      normalHigh: 9.0,
      description: 'Sleep Duration measures how long you slept during the night.\n\n'
          'Most adults need 7-9 hours of quality sleep per night. Consistently getting less than 7 hours is associated with increased health risks.\n\n'
          'Quality matters as much as quantity. Deep sleep and REM sleep stages are crucial for physical recovery and cognitive function.',
    ),
    'Heart Rate': MetricInfo(
      title: 'Heart Rate',
      emoji: '',
      normalRange: '60 – 100 bpm',
      normalLow: 60,
      normalHigh: 100,
      description: 'Heart Rate measures how many times your heart beats per minute.\n\n'
          'During rest, a normal heart rate is between 60-100 bpm. During exercise, heart rate increases to meet the body\'s higher demand for oxygen.\n\n'
          'Abnormally high or low heart rates can indicate stress, dehydration, illness, or underlying cardiac conditions.',
    ),
    'Steps': MetricInfo(
      title: 'Steps',
      emoji: '',
      normalRange: '7,500 – 10,000 steps',
      normalLow: 7500,
      normalHigh: 10000,
      description: 'Daily step count is a simple measure of physical activity throughout the day.\n\n'
          'Research suggests even 7,500 steps per day significantly reduces health risks. The goal of 10,000 steps is a widely-used benchmark.\n\n'
          'Walking is one of the most accessible forms of exercise, improving cardiovascular health, mood, and metabolic function.',
    ),
    'VO₂ Max': MetricInfo(
      title: 'VO₂ Max',
      emoji: '',
      normalRange: '30 – 60 ml/kg/min',
      normalLow: 30,
      normalHigh: 60,
      description: 'VO₂ Max is the maximum rate of oxygen consumption during exercise.\n\n'
          'It is widely considered the gold standard for measuring aerobic cardiovascular fitness. '
          'Higher values mean your heart, lungs, and muscles can use oxygen more efficiently during workouts.\n\n'
          'Apple Watch estimates your VO₂ Max (Cardio Fitness) from heart rate data during outdoor walks, runs, and hikes. '
          'Values typically range from 20-60 ml/kg/min for most adults.',
    ),
    'Strain Performance': MetricInfo(
      title: 'Strain Performance',
      emoji: '',
      normalRange: '± 15 % delta',
      normalLow: -15,
      normalHigh: 15,
      description: 'Strain Performance measures your current day\'s training intensity relative to your 7-day rolling baseline.\n\n'
          'An "On Track" score (within ±15%) suggests you are maintaining your current fitness level. '
          'A "Peak Day" (> +15%) indicates a high-intensity session that may drive fitness gains if followed by recovery.\n\n'
          'Consistent tracking helps prevent overtraining and ensure progressive overload.',
    ),
    'Cardio Load': MetricInfo(
      title: 'Cardio Load',
      emoji: '',
      normalRange: '50 – 150 TSS',
      normalLow: 50,
      normalHigh: 150,
      description: 'Cardio Load quantified the physical stress of your workouts using Training Stress Score (TSS).\n\n'
          'It factors in both duration and heart rate intensity. Scores below 50 are considered "Recovery", while scores above 150 represent high-intensity "Threshold" training.\n\n'
          'Monitoring your total weekly load helps you build endurance without risking injury.',
    ),
    'Heart Rate Recovery': MetricInfo(
      title: 'Heart Rate Recovery',
      emoji: '',
      normalRange: '12 – 25+ bpm drop',
      normalLow: 12,
      normalHigh: 25,
      description: 'Heart Rate Recovery (HRR) measures how quickly your heart rate drops in the first minute after intense exercise.\n\n'
          'A drop of 12 bpm or more is considered normal. A higher drop (25+ bpm) typically indicates a strong, well-conditioned heart.\n\n'
          'HRR is a powerful indicator of both cardiovascular fitness and autonomic nervous system health.',
    ),
    'Exercise Minutes': MetricInfo(
      title: 'Exercise Minutes',
      emoji: '',
      normalRange: '30 – 60 min',
      normalLow: 30,
      normalHigh: 60,
      description: 'Exercise Minutes tracks the total duration of your physical activity and workouts.\n\n'
          'The American Heart Association recommends at least 150 minutes of moderate-intensity aerobic activity per week, which is approximately 30 minutes a day, 5 days a week.\n\n'
          'Consistent physical activity is essential for cardiovascular health, weight management, and mental well-being.',
    ),
    'Cardio Focus': MetricInfo(
      title: 'Cardio Focus',
      emoji: '',
      normalRange: 'Low to High Aerobic',
      normalLow: 0,
      normalHigh: 100,
      description: 'Cardio Focus analyzes your exercise intensity based on heart rate zones relative to your age and max heart rate.\n\n'
          '• Recovery (<60% Max HR): This is Zone 1, often called "Active Recovery." It focuses on metabolic health and fat-burning without cardiovascular strain. Ideal for walks or light activity.\n'
          '• Low Aerobic (60–80% Max HR): This is your "Endurance Base." It builds cardiovascular longevity and aerobic capacity. This is the foundation of long-term fitness.\n'
          '• High Aerobic (80–90% Max HR): This is "Threshold Training." It improves your VO₂ Max and allows you to sustain high-effort activity for longer periods.\n'
          '• Anaerobic (>90% Max HR): This is peak intensity. It pushes your body beyond its oxygen-utilization limit to build explosive power and speed.\n\n'
          'The value tracks your total exercise duration, while the classification identifies the primary physiological benefit of your movement today.',
    ),
  };

  static MetricInfo getInfo(String metricTitle) {
    return metrics[metricTitle] ??
        MetricInfo(
          title: metricTitle,
          emoji: '',
          normalRange: 'N/A',
          description: 'No additional information available for this metric.',
        );
  }
}

// ═══════════════════════════════════════════════════════
// MAIN METRIC DETAIL SCREEN
// ═══════════════════════════════════════════════════════

class MetricDetailScreen extends StatefulWidget {
  final String title;
  final String currentValue;
  final String unit;
  final List<Map<String, dynamic>> historyData;
  final Color color;
  final String insight;
  final HealthRepository? healthRepository;

  const MetricDetailScreen({
    super.key,
    required this.title,
    required this.currentValue,
    required this.unit,
    required this.historyData,
    required this.color,
    required this.insight,
    this.healthRepository,
  });

  @override
  State<MetricDetailScreen> createState() => _MetricDetailScreenState();
}

class _MetricDetailScreenState extends State<MetricDetailScreen> {
  final int _selectedTabIndex = 0;
  int _selectedTimeRange = 0; // 0=1M, 1=3M, 2=6M, 3=1Y

  final List<String> _timeRangeLabels = ['1M', '3M', '6M', '1Y'];
  final List<int> _timeRangeDays = [30, 90, 180, 365];
  late MetricInfo _metricInfo;

  // Mutable data that changes when time range selector is tapped
  List<Map<String, dynamic>> _displayData = [];
  final bool _isLoadingData = false;
  DateTime _windowEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _metricInfo = MetricRegistry.getInfo(widget.title);
    
    // Initialize with 1M (30 days) filtered data
    final days = _timeRangeDays[_selectedTimeRange];
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    
    _displayData = widget.historyData.where((dataPoint) {
      final date = dataPoint['date'] as DateTime;
      return date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate);
    }).toList();
  }

  /// Fetch data for the selected time range from local preloaded history
  void _fetchDataForTimeRange(int rangeIndex) {
    final days = _timeRangeDays[rangeIndex];
    final cutoffDate = _windowEndDate.subtract(Duration(days: days));

    // Instantly filter the 365-day preloaded history passed to the screen
    final filteredData = widget.historyData.where((dataPoint) {
      final date = dataPoint['date'] as DateTime;
      return (date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate)) &&
             (date.isBefore(_windowEndDate) || date.isAtSameMomentAs(_windowEndDate));
    }).toList();

    setState(() {
      _displayData = filteredData;
    });
  }

  void _shiftWindow(int direction) {
    final days = _timeRangeDays[_selectedTimeRange];
    setState(() {
      _windowEndDate = _windowEndDate.add(Duration(days: days * direction));
      // Cap at current date to prevent looking into the future
      if (_windowEndDate.isAfter(DateTime.now())) {
        _windowEndDate = DateTime.now();
      }
    });
    _fetchDataForTimeRange(_selectedTimeRange);
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _windowEndDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = context.nc.isDark;
        return Theme(
          data: (isDark ? ThemeData.dark() : ThemeData.light()).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: widget.color,
              brightness: isDark ? Brightness.dark : Brightness.light,
              surface: isDark ? const Color(0xFF0F172A) : Colors.white,
            ),
            dialogBackgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _windowEndDate) {
      setState(() {
        _windowEndDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
      _fetchDataForTimeRange(_selectedTimeRange);
    }
  }

  bool get _canShiftForward {
    final now = DateTime.now();
    return _windowEndDate.year < now.year || 
           _windowEndDate.month < now.month || 
           _windowEndDate.day < now.day;
  }

  double get _avg {
    if (_displayData.isEmpty) return 0;
    double sum = 0;
    for (var d in _displayData) {
      sum += (d['value'] as num).toDouble();
    }
    return sum / _displayData.length;
  }

  /// Compute real trend changes from actual historical data
  List<Map<String, dynamic>> get _trendRows {
    final data = _displayData;
    if (data.isEmpty) {
      return [
        {'period': '3-day', 'change': '-- ${widget.unit}', 'hasData': false},
        {'period': '7-day', 'change': '-- ${widget.unit}', 'hasData': false},
        {'period': '14-day', 'change': '-- ${widget.unit}', 'hasData': false},
        {'period': '30-day', 'change': '-- ${widget.unit}', 'hasData': false},
      ];
    }

    final values = data.map((d) => (d['value'] as num).toDouble()).toList();
    final latestValue = values.last;

    String computeChange(int periodDays) {
      if (data.length < 2) return '-- ${widget.unit}';
      
      final periodStart = _windowEndDate.subtract(Duration(days: periodDays));
      final periodData = data.where((d) {
        final date = d['date'] as DateTime;
        return (date.isAfter(periodStart) || date.isAtSameMomentAs(periodStart)) &&
               (date.isBefore(_windowEndDate) || date.isAtSameMomentAs(_windowEndDate));
      }).map((d) => (d['value'] as num).toDouble()).toList();
      
      if (periodData.isEmpty) return '-- ${widget.unit}';
      
      final periodAvg = periodData.reduce((a, b) => a + b) / periodData.length;
      final change = latestValue - periodAvg;
      return _formatChange(change);
    }

    return [
      {'period': '3-day', 'change': computeChange(3), 'hasData': values.length >= 2},
      {'period': '7-day', 'change': computeChange(7), 'hasData': values.length >= 3},
      {'period': '14-day', 'change': computeChange(14), 'hasData': values.length >= 5},
      {'period': '30-day', 'change': computeChange(30), 'hasData': values.length >= 7},
    ];
  }

  String _formatChange(double change) {
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)} ${widget.unit}';
  }

  /// Extract a slice of _displayData values for the mini sparkline in trends
  List<double> _getSparklineValues(String period) {
    if (_displayData.isEmpty) return [];
    
    int days;
    switch (period) {
      case '3-day': days = 3; break;
      case '7-day': days = 7; break;
      case '14-day': days = 14; break;
      case '30-day': days = 30; break;
      default: days = 30;
    }
    
    final periodStart = _windowEndDate.subtract(Duration(days: days));
    final periodData = _displayData.where((d) {
      final date = d['date'] as DateTime;
      return (date.isAfter(periodStart) || date.isAtSameMomentAs(periodStart)) &&
             (date.isBefore(_windowEndDate) || date.isAtSameMomentAs(_windowEndDate));
    }).map((d) => (d['value'] as num).toDouble()).toList();
    
    return periodData;
  }


  @override
  Widget build(BuildContext context) {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${_windowEndDate.day} ${monthNames[_windowEndDate.month - 1]} ${_windowEndDate.year}';

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
                    // Top section (value + tabs + chart + range selector)
                    Container(
                      color: context.nc.isDark ? context.nc.scaffoldBg : Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildValueSection(dateStr),
                          const SizedBox(height: 20),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    _buildChartSection(),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTrendsAnalysis(dateStr),
                          const SizedBox(height: 28),
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

  // ═══════════════════════════════════════════════════════════
  // HEADER: X | Title | ← →
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      color: context.nc.isDark ? context.nc.scaffoldBg : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Circular X close button
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
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.nc.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 40), // Placeholder to keep title centered
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // VALUE + DATE + NORMAL RANGE
  // ═══════════════════════════════════════════════════════════
  Widget _buildValueSection(String dateStr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: large value + date
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: widget.currentValue,
                      style: TextStyle(
                        fontSize: 40,
                        fontFamily: 'JetBrains Mono',
                        fontWeight: FontWeight.w600,
                        color: context.nc.textPrimary,
                        letterSpacing: -1.5,
                      ),
                    ),
                    TextSpan(
                      text: ' ${widget.unit}',
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
        // Right: Normal range badge
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Normal range',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981), // Emerald green
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '≡ ',
                  style: TextStyle(
                    fontSize: 16,
                    color: context.nc.textTertiary,
                  ),
                ),
                Text(
                  _metricInfo.normalRange,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'JetBrains Mono',
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



  // ═══════════════════════════════════════════════════════════
  // CHART SECTION
  // ═══════════════════════════════════════════════════════════
  Widget _buildChartSection() {
    if (_isLoadingData) {
      return Container(
        height: 220,
        color: context.nc.isDark ? context.nc.scaffoldBg : Colors.white,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_displayData.isEmpty) {
      return Container(
        height: 220,
        color: context.nc.isDark ? context.nc.scaffoldBg : Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.show_chart_outlined, size: 48, color: context.nc.textTertiary.withOpacity(0.3)),
              const SizedBox(height: 12),
              Text('No historical data available',
                  style: TextStyle(color: context.nc.textTertiary, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text('Wear your device for a few days to build trends',
                  style: TextStyle(color: context.nc.textTertiary.withOpacity(0.5), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    final timeRangeDays = _timeRangeDays[_selectedTimeRange];
    
    // Sort displaying data by date to ensure proper timeline progression
    final sortedData = List<Map<String, dynamic>>.from(_displayData);
    sortedData.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    if (sortedData.isEmpty) return const SizedBox();

    final endDate = sortedData.last['date'] as DateTime;
    final startDate = endDate.subtract(Duration(days: timeRangeDays));

    // Build spots using actual temporal distance from the start date
    final spots = sortedData.map((d) {
      final date = d['date'] as DateTime;
      final daysFromStart = date.difference(startDate).inHours / 24.0;
      return FlSpot(daysFromStart, (d['value'] as num).toDouble());
    }).toList();

    // Prevent spots extending past the left edge if data exists from before the exact range cutback 
    // Usually handled by the data fetcher, but good for safety
    final filteredSpots = spots.where((s) => s.x >= 0).toList();
    if (filteredSpots.isEmpty) return const SizedBox();

    // Calculate chart bounds
    double chartMin = double.infinity;
    double chartMax = double.negativeInfinity;
    double chartSum = 0;
    for (final s in filteredSpots) {
      if (s.y < chartMin) chartMin = s.y;
      if (s.y > chartMax) chartMax = s.y;
      chartSum += s.y;
    }
    final chartAvg = chartSum / filteredSpots.length;
    final yRange = chartMax - chartMin;
    final double yMin = (chartMin - yRange * 0.3).clamp(0.0, double.infinity);
    final yMax = chartMax + yRange * 0.3;
    final interval = yRange > 0 ? yRange / 3 : 1.0;
    final chartColor = widget.color;
    
    // X-Axis configurations
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    double xInterval;
    switch (_selectedTimeRange) {
      case 0: // 1M
        xInterval = 7; 
        break;
      case 1: // 3M
        xInterval = 30;
        break;
      case 2: // 6M
        xInterval = 60;
        break;
      case 3: // 1Y
        xInterval = 90;
        break;
      default:
        xInterval = 30;
    }

    // Create the envelope band spots matching the filtered spots
    final topSpots = <FlSpot>[];
    final bottomSpots = <FlSpot>[];
    for (int i = 0; i < filteredSpots.length; i++) {
      double maxV = filteredSpots[i].y;
      double minV = filteredSpots[i].y;
      for (int j = math.max(0, i - 2); j <= math.min(filteredSpots.length - 1, i + 2); j++) {
        if (filteredSpots[j].y > maxV) maxV = filteredSpots[j].y;
        if (filteredSpots[j].y < minV) minV = filteredSpots[j].y;
      }
      double diff = (maxV - minV);
      double minThickness = yRange * 0.15;
      if (diff < minThickness) {
        maxV += minThickness / 2;
        minV -= minThickness / 2;
      }
      topSpots.add(FlSpot(filteredSpots[i].x, maxV));
      bottomSpots.add(FlSpot(filteredSpots[i].x, minV));
    }

    // Calculate pill position
    // Chart Height = 240, TopPad = 16, BottomPad = 4, BottomTitles = 28 -> Inner Height = 192
    double p = yRange == 0 ? 0.5 : (chartAvg - yMin) / (yMax - yMin);
    double pillTop = 16 + 192 * (1 - p) - 13; // 13 is half the pill height (26)

    return Container(
      color: context.nc.isDark ? Colors.transparent : Colors.white,
      child: Column(
        children: [
          // Chart
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 4),
                  child: LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: timeRangeDays.toDouble(),
                      minY: yMin,
                      maxY: yMax,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: interval > 0 ? interval : 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: context.nc.isDark ? context.nc.divider.withOpacity(0.05) : const Color(0xFFF3F4F6),
                          strokeWidth: 1.5,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: interval > 0 ? interval : 1,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  value.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'JetBrains Mono',
                                    color: context.nc.textTertiary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: xInterval,
                            getTitlesWidget: (value, meta) {
                              // Ensure we don't draw label at exact 0 or exact max if it crowds the edge
                              if (value < 1 || value > timeRangeDays - 1) return const SizedBox.shrink();
                              
                              final labelDate = startDate.add(Duration(days: value.round()));
                              
                              String labelText = '';
                              if (_selectedTimeRange == 0) { // 1M
                                labelText = '${labelDate.day} ${monthNames[labelDate.month - 1]}';
                              } else { // 3M, 6M, 1Y
                                labelText = monthNames[labelDate.month - 1];
                              }

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  labelText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.nc.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((spot) {
                              if (spot.barIndex != 2) return null; // Only show tooltip for the main line
                              
                              final hitDate = startDate.add(Duration(days: spot.x.round()));
                              final dateLabel = '${hitDate.day} ${monthNames[hitDate.month - 1]}\n';
                              
                              return LineTooltipItem(
                                '$dateLabel${spot.y.toStringAsFixed(1)} ${widget.unit}',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              );
                            }).toList();
                          },
                        ),
                      ),
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: chartAvg,
                            color: chartColor,
                            strokeWidth: 2,
                            dashArray: [4, 4],
                          ),
                        ],
                      ),
                      lineBarsData: [
                        // Top Band Bound
                        LineChartBarData(
                          spots: topSpots,
                          show: false,
                          dotData: const FlDotData(show: false),
                        ),
                        // Bottom Band Bound
                        LineChartBarData(
                          spots: bottomSpots,
                          show: false,
                          dotData: const FlDotData(show: false),
                        ),
                        // Main Line
                        LineChartBarData(
                          spots: filteredSpots,
                          isCurved: false,
                          color: chartColor,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, bar, index) {
                              final isLast = index == filteredSpots.length - 1;
                              if (isLast) {
                                return _GlowingDotPainter(
                                  color: chartColor,
                                  radius: 4.0,
                                  strokeWidth: 2.0,
                                  isDark: context.nc.isDark,
                                );
                              }
                              return _SolidDotPainter(
                                color: chartColor,
                                radius: 3.5,
                                strokeWidth: 1.5,
                                isDark: context.nc.isDark,
                              );
                            },
                          ),
                        ),
                      ],
                      betweenBarsData: [
                        BetweenBarsData(
                          fromIndex: 0,
                          toIndex: 1,
                          color: chartColor.withOpacity(0.15),
                        ),
                      ],
                    ),
                  ),
                ),
                // Overlay for the centered Average Pill
                Positioned(
                  top: pillTop,
                  left: 0,
                  right: 58, // Shift left by the right axis width + padding
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: chartColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: chartColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        'Avg. ${chartAvg.toStringAsFixed(1)}${widget.unit.isNotEmpty ? ' ${widget.unit}' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Time range selector
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _shiftWindow(-1),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(Icons.chevron_left, size: 22, color: context.nc.textPrimary),
                  ),
                ),
                const SizedBox(width: 4),
                ...List.generate(_timeRangeLabels.length, (i) {
                  final isSelected = i == _selectedTimeRange;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedTimeRange = i);
                      _fetchDataForTimeRange(i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? context.nc.textPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _timeRangeLabels[i],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected 
                              ? (context.nc.isDark ? Colors.black : Colors.white) 
                              : context.nc.textSecondary,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                Text('|', style: TextStyle(color: context.nc.divider)),
                GestureDetector(
                  onTap: _pickDate,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Icon(LucideIcons.calendarDays, size: 17, color: context.nc.textPrimary),
                  ),
                ),
                GestureDetector(
                  onTap: _canShiftForward ? () => _shiftWindow(1) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.chevron_right, 
                      size: 22, 
                      color: _canShiftForward ? context.nc.textPrimary : context.nc.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // TRENDS ANALYSIS
  // ═══════════════════════════════════════════════════════════
  Widget _buildTrendsAnalysis(String dateStr) {
    final trends = _trendRows;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Trends Analysis',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.nc.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Last data point on $dateStr',
          style: TextStyle(
            fontSize: 13,
            color: context.nc.textTertiary,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: context.nc.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.nc.cardBorder),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text('Period',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.nc.textTertiary)),
                    ),
                    Expanded(
                      flex: 4,
                      child: Text('Change',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.nc.textTertiary)),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text('Trend',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.nc.textTertiary)),
                    ),
                  ],
                ),
              ),
              // Rows with horizontal dividers
              ...trends.asMap().entries.map((entry) {
                final row = entry.value;
                final changeStr = row['change'] as String;
                final isNegative = changeStr.startsWith('-');
                final isNeutral = changeStr.contains('0.0');

                return Column(
                  children: [
                    Divider(height: 1, thickness: 1, color: context.nc.divider.withOpacity(0.05)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              row['period'] as String,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: context.nc.textPrimary,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Row(
                              children: [
                                Icon(
                                  isNeutral
                                      ? Icons.remove_circle_outline
                                      : (isNegative
                                          ? Icons.arrow_circle_down_outlined
                                          : Icons.arrow_circle_up_outlined),
                                  size: 16,
                                  color: context.nc.textTertiary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  changeStr,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: context.nc.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Mini sparkline from real data
                          SizedBox(
                            width: 72,
                            height: 26,
                            child: CustomPaint(
                              painter: _MiniTrendPainter(
                                values: _getSparklineValues(row['period'] as String),
                                isUpward: !isNegative && !isNeutral,
                                color: context.nc.textTertiary.withOpacity(0.3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Based on 7-day rolling averages for the select period.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.nc.textTertiary, height: 1.4),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ABOUT THIS METRIC
  // ═══════════════════════════════════════════════════════════
  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: context.nc.textTertiary),
            const SizedBox(width: 6),
            Text(
              "About ${widget.title}",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.nc.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _metricInfo.description,
          style: TextStyle(
            fontSize: 15,
            color: context.nc.textPrimary,
            height: 1.65,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// MINI TREND SPARKLINE PAINTER — uses real data values
// ═══════════════════════════════════════════════════════

class _MiniTrendPainter extends CustomPainter {
  final List<double> values;
  final bool isUpward;
  final Color color;

  _MiniTrendPainter({required this.values, this.isUpward = false, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    // Normalize values to fit the canvas
    double minVal = values.first;
    double maxVal = values.first;
    for (final v in values) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }
    final range = maxVal - minVal;
    final effectiveRange = range > 0 ? range : 1.0;

    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1).clamp(1, values.length);
      final y = size.height - ((values[i] - minVal) / effectiveRange * (size.height - 4) + 2);
      points.add(Offset(x, y.clamp(2, size.height - 2)));
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final cp1 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i - 1].dy);
      final cp2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniTrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.isUpward != isUpward;
}

// ═══════════════════════════════════════════════════════
// CUSTOM CHART DOT PAINTERS
// ═══════════════════════════════════════════════════════

class _GlowingDotPainter extends FlDotPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final bool isDark;

  _GlowingDotPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.isDark,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    // Outer glow
    final glowPaint = Paint()
      ..color = color.withOpacity(0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(offsetInCanvas, radius + 4, glowPaint);

    // Colored Border
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(offsetInCanvas, radius, strokePaint);

    // Inner Fill
    final fillPaint = Paint()
      ..color = isDark ? const Color(0xFF111827) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offsetInCanvas, radius - (strokeWidth / 2) + 0.5, fillPaint);
  }

  @override
  Size getSize(FlSpot spot) {
    return Size(radius * 2 + 8, radius * 2 + 8);
  }

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => [color, radius, strokeWidth, isDark];
}

class _SolidDotPainter extends FlDotPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final bool isDark;

  _SolidDotPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.isDark,
  });

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    // Colored Border
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(offsetInCanvas, radius, strokePaint);

    // Inner Fill
    final fillPaint = Paint()
      ..color = isDark ? const Color(0xFF111827) : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offsetInCanvas, radius - (strokeWidth / 2) + 0.5, fillPaint);
  }

  @override
  Size getSize(FlSpot spot) {
    return Size(radius * 2, radius * 2);
  }

  @override
  Color get mainColor => color;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;

  @override
  List<Object?> get props => [color, radius, strokeWidth, isDark];
}
