import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/hrr_service.dart';
import '../metric_detail_screen.dart';
import '../widgets/dashboard_card_style.dart';
import '../../../config/theme.dart';

class HrrDetailScreen extends StatefulWidget {
  final double currentHrr;
  final String status;

  const HrrDetailScreen({
    super.key,
    required this.currentHrr,
    required this.status,
  });

  @override
  State<HrrDetailScreen> createState() => _HrrDetailScreenState();
}

class _HrrDetailScreenState extends State<HrrDetailScreen> {
  int _selectedTimeRange = 0; // 0=1M, 1=3M, 2=6M, 3=1Y
  final List<String> _timeRangeLabels = ['1M', '3M', '6M', '1Y'];
  final List<int> _timeRangeDays = [30, 90, 180, 365];
  
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;
  late MetricInfo _metricInfo;

  @override
  void initState() {
    super.initState();
    _metricInfo = MetricRegistry.getInfo('Heart Rate Recovery');
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final days = _timeRangeDays[_selectedTimeRange];
      final history = await HrrService.getHrrHistory(days: days);
      history.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
      setState(() {
        _historyData = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching HRR history: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final now = DateTime.now();
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
                    Container(
                      color: context.nc.scaffoldBg,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildValueSection(dateStr),
                          const SizedBox(height: 24),
                          if (_isLoading)
                            SizedBox(
                              height: 240, 
                              child: Center(child: CircularProgressIndicator(color: context.nc.textPrimary))
                            )
                          else
                            _buildChartSection(),
                          const SizedBox(height: 20),
                          _buildTimeRangeSelector(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBreakdownSection(),
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
              'Heart Rate Recovery',
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

  Widget _buildValueSection(String dateStr) {
    double displayValue = widget.currentHrr;
    String displayStatus = widget.status;
    
    if (displayValue <= 0 && _historyData.isNotEmpty) {
      // Find latest non-zero
      final latestNonZero = _historyData.where((d) => (d['value'] as num) > 0).toList();
      if (latestNonZero.isNotEmpty) {
        displayValue = latestNonZero.last['value'] as double;
        displayStatus = HrrService.classifyHrr(displayValue);
      }
    }

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
                      text: displayValue.round().toString(),
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: context.nc.textPrimary,
                        letterSpacing: -1.5,
                      ),
                    ),
                    TextSpan(
                      text: ' bpm',
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
              displayStatus,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: HrrService.classifyHrr(displayValue) == 'Below normal' ? Colors.red : const Color(0xFF10B981),
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
    // Filter out zeros and sort by date
    final filteredData = _historyData.where((d) => (d['value'] as num) > 0).toList();
    if (filteredData.isEmpty) {
      return SizedBox(
        height: 240, 
        child: Center(
          child: Text(
            "No recovery data found",
            style: TextStyle(color: context.nc.textTertiary),
          )
        )
      );
    }
    
    filteredData.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

    final timeRangeDays = _timeRangeDays[_selectedTimeRange];
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: timeRangeDays));

    final spots = filteredData.map((d) {
      final date = d['date'] as DateTime;
      final daysFromStart = date.difference(startDate).inHours / 24.0;
      return FlSpot(daysFromStart, (d['value'] as num).toDouble());
    }).where((s) => s.x >= 0).toList();

    if (spots.isEmpty) {
       return SizedBox(
        height: 240, 
        child: Center(
          child: Text(
            "No recovery data in this range",
            style: TextStyle(color: context.nc.textTertiary),
          )
        )
      );
    }

    double xInterval = 7;
    if (_selectedTimeRange == 1) xInterval = 14;
    if (_selectedTimeRange == 2) xInterval = 30;
    if (_selectedTimeRange == 3) xInterval = 60;

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: timeRangeDays.toDouble(),
          gridData: FlGridData(
            show: true, 
            drawVerticalLine: false,
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
                reservedSize: 30,
                interval: 10,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(), 
                  style: TextStyle(color: context.nc.textTertiary, fontSize: 11)
                ),
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: xInterval,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value > timeRangeDays) return const SizedBox.shrink();
                  final labelDate = startDate.add(Duration(days: value.round()));
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${labelDate.day}/${labelDate.month}', 
                      style: TextStyle(color: context.nc.textTertiary, fontSize: 10)
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFFEF4444),
              barWidth: 2,
              dotData: FlDotData(
                show: _selectedTimeRange == 0, // Only show dots for 1M to reduce clutter
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 2,
                  color: context.nc.cardSurfaceElevated,
                  strokeWidth: 1,
                  strokeColor: const Color(0xFFEF4444),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFEF4444).withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => context.nc.isDark ? const Color(0xFF1F2937) : Colors.black,
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                return LineTooltipItem(
                  '${s.y.round()} bpm',
                  TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
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
                _fetchHistory();
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

  Widget _buildBreakdownSection() {
    int good = 0, normal = 0, below = 0;
    int validCount = 0;
    for (var d in _historyData) {
      final val = d['value'] as double;
      if (val <= 0) continue;
      
      validCount++;
      if (val >= 20) {
        good++;
      } else if (val >= 12) {
        normal++;
      } else {
        below++;
      }
    }
    final total = validCount == 0 ? 1 : validCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recovery Quality Breakdown', 
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
          child: Column(
            children: [
              _buildBreakdownRow('Good', '$good events', (good / total), Colors.green),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: context.nc.divider.withOpacity(0.05)),
              ),
              _buildBreakdownRow('Normal', '$normal events', (normal / total), Colors.orange),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: context.nc.divider.withOpacity(0.05)),
              ),
              _buildBreakdownRow('Below', '$below events', (below / total), Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownRow(String label, String duration, double percent, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(color: context.nc.textSecondary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    duration,
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.nc.textPrimary, fontSize: 14),
                  ),
                  Text(
                    '${(percent * 100).round()}%',
                    style: TextStyle(fontWeight: FontWeight.w700, color: context.nc.textPrimary, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.nc.divider.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: percent.clamp(0.02, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
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
      ],
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "About HRR",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.nc.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        DashboardCard(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Text(
            _metricInfo.description,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: context.nc.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
