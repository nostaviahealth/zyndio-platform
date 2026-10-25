import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../data/health_repository.dart';
import '../metric_detail_screen.dart';
import '../widgets/dashboard_card_style.dart';
import '../../../config/theme.dart';

class CardioLoadDetailScreen extends StatefulWidget {
  final HealthRepository healthRepository;
  final double currentLoad;
  final String status;

  const CardioLoadDetailScreen({
    super.key,
    required this.healthRepository,
    required this.currentLoad,
    required this.status,
  });

  @override
  State<CardioLoadDetailScreen> createState() => _CardioLoadDetailScreenState();
}

class _CardioLoadDetailScreenState extends State<CardioLoadDetailScreen> {
  int _selectedTimeRange = 0; // 0=1M, 1=3M, 2=6M, 3=1Y
  final List<String> _timeRangeLabels = ['1M', '3M', '6M', '1Y'];
  final List<int> _timeRangeDays = [30, 90, 180, 365];
  
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoading = true;
  late MetricInfo _metricInfo;

  @override
  void initState() {
    super.initState();
    _metricInfo = MetricRegistry.getInfo('Cardio Load');
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final days = _timeRangeDays[_selectedTimeRange];
      final history = await widget.healthRepository.getCardioLoadHistory(days: days);
      setState(() {
        _historyData = history;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching cardio load history: $e');
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
              'Cardio Load',
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
                      text: widget.currentLoad.round().toString(),
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        color: context.nc.textPrimary,
                        letterSpacing: -1.5,
                      ),
                    ),
                    TextSpan(
                      text: ' TSS',
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
              widget.status,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFFF97316),
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
      return FlSpot(e.key.toDouble(), e.value['value'] as double);
    }).toList();

    return SizedBox(
      height: 240,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 50,
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
                interval: 50,
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
                interval: _selectedTimeRange == 0 ? 7 : 30,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= _historyData.length) return const SizedBox.shrink();
                  final date = _historyData[value.toInt()]['date'] as DateTime;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${date.day}/${date.month}',
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
              spots: spots,
              isCurved: true,
              color: const Color(0xFFF97316),
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3,
                  color: context.nc.cardSurfaceElevated,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFFF97316),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFF97316).withOpacity(0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => context.nc.isDark ? const Color(0xFF1F2937) : Colors.black,
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                return LineTooltipItem(
                  '${s.y.round()} TSS',
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
    int recovery = 0, aerobic = 0, threshold = 0, explosive = 0;
    for (var d in _historyData) {
      final val = d['value'] as double;
      if (val < 50) {
        recovery++;
      } else if (val < 150) {
        aerobic++;
      } else if (val < 300) {
        threshold++;
      } else {
        explosive++;
      }
    }
    final total = _historyData.isEmpty ? 1 : _historyData.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Load Intensity Breakdown',
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
              _buildBreakdownRow('Recovery', '$recovery days', (recovery / total), Colors.blue),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: context.nc.divider.withOpacity(0.05)),
              ),
              _buildBreakdownRow('Aerobic', '$aerobic days', (aerobic / total), Colors.green),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: context.nc.divider.withOpacity(0.05)),
              ),
              _buildBreakdownRow('Threshold', '$threshold days', (threshold / total), Colors.orange),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: context.nc.divider.withOpacity(0.05)),
              ),
              _buildBreakdownRow('Explosive', '$explosive days', (explosive / total), Colors.red),
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
          "About Cardio Load",
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
