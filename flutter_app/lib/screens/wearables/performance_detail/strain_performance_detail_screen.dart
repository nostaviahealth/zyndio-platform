import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/health_repository.dart';
import '../../../services/health_intelligence_service.dart';
import '../metric_detail_screen.dart';
import '../widgets/dashboard_card_style.dart';
import '../../../config/theme.dart';

class StrainPerformanceDetailScreen extends StatefulWidget {
  final HealthRepository healthRepository;
  final int currentStrain;
  final String status;
  final double performanceDelta;

  const StrainPerformanceDetailScreen({
    super.key,
    required this.healthRepository,
    required this.currentStrain,
    required this.status,
    required this.performanceDelta,
  });

  @override
  State<StrainPerformanceDetailScreen> createState() => _StrainPerformanceDetailScreenState();
}

class _StrainPerformanceDetailScreenState extends State<StrainPerformanceDetailScreen> {
  int _selectedTimeRange = 0; // 0=1M, 1=3M, 2=6M, 3=1Y
  final List<String> _timeRangeLabels = ['1M', '3M', '6M', '1Y'];
  final List<int> _timeRangeDays = [30, 90, 180, 365];
  
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;
  late MetricInfo _metricInfo;

  @override
  void initState() {
    super.initState();
    _metricInfo = MetricRegistry.getInfo('Strain Performance');
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final days = _timeRangeDays[_selectedTimeRange];
      final history = await widget.healthRepository.getStrainPerformanceHistory(days: days);
      setState(() {
        _historyData = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching strain history: $e');
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
                    // Top section card
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
              'Strain Performance',
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
    final delta = widget.performanceDelta;
    final sign = delta >= 0 ? '+' : '';
    final details = HealthIntelligenceService.getStrainPerformanceStatusDetails(delta.round());
    final color = details['color'] as Color;

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
                      text: '$sign${delta.round()}',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: context.nc.textPrimary,
                        letterSpacing: -1.5,
                      ),
                    ),
                    TextSpan(
                      text: ' %',
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
              details['status'],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
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
                  details['range'],
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
    if (_historyData.isEmpty) {
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

    final spots = _historyData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value['delta'] as double);
    }).toList();

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    // Add 20% padding to top and bottom
    final padding = (maxY - minY).abs() * 0.2;
    minY -= padding;
    maxY += padding;

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 40, // Increased interval for cleaner grid
            getDrawingHorizontalLine: (value) => FlLine(
              color: context.nc.divider.withValues(alpha: 0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 40, // Increased interval to prevent overlapping
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(color: context.nc.textTertiary, fontSize: 11),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _selectedTimeRange == 0 ? 7 : 30,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= _historyData.length) return const SizedBox.shrink();
                  final date = _historyData[value.toInt()]['date'] as DateTime;
                  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.day} ${months[date.month - 1]}',
                      style: TextStyle(color: context.nc.textTertiary, fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _historyData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), 15)).toList(),
              isCurved: true,
              color: Colors.transparent,
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF22C55E).withValues(alpha: 0.05),
                cutOffY: -15,
                applyCutOffY: true,
              ),
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF22C55E)],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: context.nc.cardSurfaceElevated,
                  strokeWidth: 2,
                  strokeColor: spots[index].y >= -15 && spots[index].y <= 15 
                      ? const Color(0xFF22C55E) 
                      : const Color(0xFF6366F1),
                ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => context.nc.isDark ? const Color(0xFF1F2937) : Colors.black,
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                return LineTooltipItem(
                  '${s.y.round()}%',
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
    int below = 0, within = 0, above = 0;
    for (var d in _historyData) {
      final delta = d['delta'] as double;
      if (delta < -15) {
        below++;
      } else if (delta > 15) {
        above++;
      } else {
        within++;
      }
    }
    final total = _historyData.isEmpty ? 1 : _historyData.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Target Strain Breakdown',
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
              _buildBreakdownRow('Below', '$below days', (below / total), const Color(0xFF6366F1)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: context.nc.divider.withOpacity(0.05)),
              ),
              _buildBreakdownRow('Within', '$within days', (within / total), const Color(0xFF22C55E)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: context.nc.divider.withOpacity(0.05)),
              ),
              _buildBreakdownRow('Above', '$above days', (above / total), const Color(0xFFF97316)),
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
          width: 70,
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
          "About Strain Performance",
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
