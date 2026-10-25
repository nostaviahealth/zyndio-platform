import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../data/health_repository.dart';
import 'widgets/activity_session_card.dart';
import 'workout_detail_screen.dart';
import '../../config/theme.dart';

class ActivitySummaryDetailScreen extends StatefulWidget {
  final HealthRepository healthRepository;

  const ActivitySummaryDetailScreen({
    super.key,
    required this.healthRepository,
  });

  @override
  State<ActivitySummaryDetailScreen> createState() => _ActivitySummaryDetailScreenState();
}

class _ActivitySummaryDetailScreenState extends State<ActivitySummaryDetailScreen> {
  String _selectedRange = '1M';
  String _selectedType = 'All';
  
  List<Map<String, dynamic>> _workoutHistory = [];
  Map<String, List<double>> _cumulativeData = {'current': [], 'previous': []};
  bool _isLoading = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final days = _getDaysForRange(_selectedRange);
    
    // Fetch last 6 months of workouts for the list
    final workouts = await widget.healthRepository.getWorkoutHistory(days: 180);
    // Sort by date descending
    workouts.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    
    // Fetch cumulative chart data based on selected range
    final cumulative = await widget.healthRepository.getCumulativeWorkoutDuration(periodDays: days);
    
    setState(() {
      _workoutHistory = workouts;
      _cumulativeData = cumulative;
      _isLoading = false;
    });
  }

  int _getDaysForRange(String range) {
    switch (range) {
      case '1M': return 30;
      case '3M': return 90;
      case '6M': return 180;
      case '1Y': return 365;
      default: return 30;
    }
  }

  Future<void> _onRangeChanged(String newRange) async {
    if (_selectedRange == newRange) return;
    
    setState(() {
      _selectedRange = newRange;
      _isUpdating = true;
    });
    
    final days = _getDaysForRange(newRange);
    final cumulative = await widget.healthRepository.getCumulativeWorkoutDuration(periodDays: days);
    
    if (mounted) {
      setState(() {
        _cumulativeData = cumulative;
        _isUpdating = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredWorkouts() {
    if (_selectedType == 'All') return _workoutHistory;
    return _workoutHistory.where((w) {
      final type = w['type'] as String;
      if (_selectedType == 'Walking' && type.toLowerCase().contains('walk')) return true;
      if (type == _selectedType) return true;
      return false;
    }).toList();
  }

  double _calculateTotalTime(List<double> data) {
    if (data.isEmpty) return 0;
    return data.last;
  }

  double _getMaxValue() {
    final current = _cumulativeData['current'] ?? [];
    final prev = _cumulativeData['previous'] ?? [];
    
    double mx = 0;
    if (current.isNotEmpty) mx = current.last;
    if (prev.isNotEmpty && prev.last > mx) mx = prev.last;
    if (mx <= 0) return 10;
    return mx * 1.25;
  }

  String _formatHoursMinutes(double hoursDecimal) {
    if (hoursDecimal <= 0) return '0h 0m';
    final h = hoursDecimal.floor();
    final m = ((hoursDecimal - h) * 60).round();
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.nc.scaffoldBg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentData = _cumulativeData['current'] ?? [];
    final prevData = _cumulativeData['previous'] ?? [];

    final totalCurrent = _calculateTotalTime(currentData);
    final totalPrev = _calculateTotalTime(prevData);
    final maxValue = _getMaxValue();

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg, // Light grey Apple base -> theme
      appBar: AppBar(
        title: Text('Activity Summary', style: TextStyle(color: context.nc.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: context.nc.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.x, color: context.nc.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildChartSection(currentData, prevData, totalCurrent, totalPrev, maxValue),
                if (_isUpdating)
                  Positioned.fill(
                    child: Container(
                      color: context.nc.scaffoldBg.withOpacity(0.5),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7E80)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(List<double> currentData, List<double> prevData, double totalCurrent, double totalPrev, double maxValue) {
    final now = DateTime.now();
    final days = _getDaysForRange(_selectedRange);
    
    final currentEnd = now;
    final currentStart = now.subtract(Duration(days: days));
    final prevStart = currentStart.subtract(Duration(days: days));
    
    final monthsAbbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String dateLabel = '${currentStart.day} ${monthsAbbr[currentStart.month - 1]} – ${currentEnd.day} ${monthsAbbr[currentEnd.month - 1]} ${currentEnd.year}';
    String prevDateLabel = '${prevStart.day} ${monthsAbbr[prevStart.month - 1]} – ${currentStart.day} ${monthsAbbr[currentStart.month - 1]}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatHoursMinutes(totalCurrent),
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: context.nc.textPrimary, letterSpacing: -1),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFB866), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(dateLabel, style: TextStyle(fontSize: 14, color: context.nc.textSecondary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatHoursMinutes(totalPrev), 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.nc.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: context.nc.divider, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(prevDateLabel, style: TextStyle(fontSize: 14, color: context.nc.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingVerticalLine: (value) => FlLine(color: context.nc.divider.withOpacity(0.5), strokeWidth: 1.5, dashArray: [4, 4]),
                  horizontalInterval: maxValue / 3 > 0 ? maxValue / 3 : 100,
                  getDrawingHorizontalLine: (value) => FlLine(color: context.nc.divider.withOpacity(0.3), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxValue / 3 > 0 ? maxValue / 3 : 100,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value >= maxValue) return const SizedBox.shrink();
                        return Text('${value.toInt()}', style: TextStyle(fontSize: 10, color: context.nc.textTertiary));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: currentData.length > 5 ? currentData.length / 5 : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < currentData.length) {
                          if (idx == 0 || idx == currentData.length ~/ 2 || idx == currentData.length - 1) {
                            final d = currentStart.add(Duration(days: idx));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('${d.day} ${monthsAbbr[d.month-1]}', style: TextStyle(fontSize: 10, color: context.nc.textTertiary)),
                            );
                          }
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        // Only show tooltip for the activity line (index 1) or baseline if activity is empty (index 0)
                        if (prevData.isNotEmpty && spot.barIndex != 1) return null;
                        
                        final idx = spot.x.toInt();
                        String dateStr = '';
                        if (idx >= 0 && idx < currentData.length) {
                          final d = currentStart.add(Duration(days: idx));
                          dateStr = '${d.day} ${monthsAbbr[d.month-1]}';
                        }
                        
                        final h = spot.y.floor();
                        final m = ((spot.y - h) * 60).round();
                        final timeStr = '${h}h ${m}m';

                        return LineTooltipItem(
                          dateStr.isNotEmpty ? '$dateStr\n$timeStr' : timeStr,
                          TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // Previous line (grey) - drawn behind
                  if (prevData.isNotEmpty)
                    LineChartBarData(
                      spots: prevData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: context.nc.divider,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          final isLongRange = _selectedRange != '1M';
                          if (isLongRange && index != prevData.length - 1) {
                            return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                          }
                          if (index == prevData.length - 1) return FlDotCirclePainter(radius: 4, color: context.nc.divider, strokeWidth: 0);
                          return FlDotCirclePainter(radius: 3, color: context.nc.divider, strokeWidth: 0);
                        },
                      ),
                    ),
                  // Current line (orange gradient)
                  if (currentData.isNotEmpty)
                    LineChartBarData(
                      spots: currentData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: const Color(0xFFFF7E80),
                      barWidth: 4,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          final isLongRange = _selectedRange != '1M';
                          if (isLongRange && index != currentData.length - 1) {
                            return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                          }
                          return FlDotCirclePainter(radius: 3, color: context.nc.textOnDark, strokeWidth: 2, strokeColor: const Color(0xFFFF7E80));
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFFF7E80).withOpacity(0.2),
                            const Color(0xFFFF7E80).withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          // Time Filters
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: context.nc.cardBorder, 
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTimeFilter('1M'),
                          _buildTimeFilter('3M'),
                          _buildTimeFilter('6M'),
                          Container(width: 1, height: 16, color: context.nc.divider, margin: const EdgeInsets.symmetric(horizontal: 4)),
                          _buildTimeFilter('1Y'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilter(String label) {
    final isSelected = _selectedRange == label;
    return GestureDetector(
      onTap: () => _onRangeChanged(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? context.nc.cardSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(color: context.nc.shadowColor, blurRadius: 4, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? context.nc.textPrimary : context.nc.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      color: context.nc.scaffoldBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Activity History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.nc.textPrimary)),
            ],
          ),
          const SizedBox(height: 16),
          // Type filters (scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTypeFilter('All'),
                _buildTypeFilter('Walking'),
                _buildTypeFilter('Outdoor Walk'),
                _buildTypeFilter('Running'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator()))
          else
            ..._buildGroupedWorkouts(),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedWorkouts() {
    final workouts = _getFilteredWorkouts();
    if (workouts.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Center(child: Text('No matching activities found.', style: TextStyle(color: context.nc.textTertiary))),
        )
      ];
    }

    // Group by Day
    final grouped = <DateTime, List<Map<String, dynamic>>>{};
    for (var w in workouts) {
      final d = w['date'] as DateTime;
      final dayKey = DateTime(d.year, d.month, d.day);
      grouped.putIfAbsent(dayKey, () => []).add(w);
    }

    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final widgets = <Widget>[];
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final monthsStr = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    for (var day in sortedDays) {
      String dayLabel;
      if (day == today) {
        dayLabel = 'TODAY';
      } else if (day == yesterday) {
        dayLabel = 'YESTERDAY';
      } else {
        dayLabel = '${weekdays[day.weekday - 1]}, ${monthsStr[day.month - 1]} ${day.day}'.toUpperCase();
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
          child: Text(
            dayLabel,
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w700, 
              color: context.nc.textTertiary, 
              letterSpacing: 0.8
            ),
          ),
        ),
      );
      
      final dayWorkouts = grouped[day]!;
      // Sort within the day by time descending
      dayWorkouts.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      for (var w in dayWorkouts) {
        final d = w['date'] as DateTime;
        final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
        final amPm = d.hour >= 12 ? 'PM' : 'AM';
        final timeStr = '$hour12:${d.minute.toString().padLeft(2, '0')} $amPm';
        
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: ActivitySessionCard(
              title: w['type'],
              durationOrDistance: w['statString'],
              dateString: timeStr,
              iconData: _getIconForType(w['type']),
              iconColor: const Color(0xFFF59E0B),
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (_) => WorkoutDetailScreen(
                      workout: w,
                      healthRepository: widget.healthRepository,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
    
    return widgets;
  }

  Widget _buildTypeFilter(String label) {
    final isSelected = _selectedType == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? context.nc.textPrimary : context.nc.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: context.nc.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? context.nc.scaffoldBg : context.nc.textSecondary,
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('walk')) return LucideIcons.footprints;
    if (t.contains('run')) return LucideIcons.flame;
    if (t.contains('cycle') || t.contains('bike')) return LucideIcons.bike;
    if (t.contains('swim')) return LucideIcons.waves;
    if (t.contains('yoga') || t.contains('mind')) return LucideIcons.flower2;
    return LucideIcons.activity;
  }
}
