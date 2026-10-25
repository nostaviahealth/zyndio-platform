import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'widgets/dashboard_card_style.dart';
import 'metric_detail_screen.dart';
import '../../data/health_repository.dart';
import '../../config/theme.dart';

class StressDetailScreen extends StatefulWidget {
  final int stressScore;
  final int energyScore;
  final double? hrv;
  final double? lastHrv;
  final DateTime? lastHrvTime;
  final int? rhr;
  final int? lastHr;
  final DateTime? lastHrTime;
  final List<Map<String, dynamic>> intradayStress;
  final DateTime selectedDate;

  const StressDetailScreen({
    super.key,
    required this.stressScore,
    required this.energyScore,
    this.hrv,
    this.lastHrv,
    this.lastHrvTime,
    this.rhr,
    this.lastHr,
    this.lastHrTime,
    required this.intradayStress,
    required this.selectedDate,
  });

  @override
  State<StressDetailScreen> createState() => _StressDetailScreenState();
}

class _StressDetailScreenState extends State<StressDetailScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _gaugeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _gaugeAnimation = Tween<double>(begin: 0, end: widget.stressScore / 100.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime? d) {
    if (d == null) return '--';
    int h = d.hour;
    int m = d.minute;
    String period = 'AM';
    if (h >= 12) {
      period = 'PM';
      if (h > 12) h -= 12;
    }
    if (h == 0) h = 12;
    String ms = m.toString().padLeft(2, '0');
    return '$h:$ms $period';
  }

  String _getClassification(int score) {
    if (score < 25) return 'Rest';
    if (score < 50) return 'Low';
    if (score < 75) return 'Medium';
    return 'High';
  }

  Color _getColorForLevel(int level) {
    switch (level) {
      case 0: return const Color(0xFF60A5FA); // Rest (Blue)
      case 1: return const Color(0xFF34D399); // Low (Green)
      case 2: return const Color(0xFFFBBF24); // Med (Yellow)
      case 3: return const Color(0xFFF87171); // High (Orange/Red)
      case 4: return const Color(0xFF94A3B8); // Activity (Gray)
      default: return const Color(0xFFE2E8F0);
    }
  }

  Map<int, Duration> _calculateDurations() {
    Map<int, Duration> totals = {0: Duration.zero, 1: Duration.zero, 2: Duration.zero, 3: Duration.zero, 4: Duration.zero};
    for (var point in widget.intradayStress) {
      int level = point['level'] as int;
      if (totals.containsKey(level)) {
        totals[level] = totals[level]! + const Duration(minutes: 15);
      }
    }
    return totals;
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final durations = _calculateDurations();
    final totalMeasured = durations.values.fold(Duration.zero, (prev, element) => prev + element);
    
    // Percentages for the breakdown bars
    final highPct = totalMeasured.inMinutes > 0 ? (durations[3]!.inMinutes / totalMeasured.inMinutes) : 0.0;
    final medPct = totalMeasured.inMinutes > 0 ? (durations[2]!.inMinutes / totalMeasured.inMinutes) : 0.0;
    final lowPct = totalMeasured.inMinutes > 0 ? (durations[1]!.inMinutes / totalMeasured.inMinutes) : 0.0;
    final restPct = totalMeasured.inMinutes > 0 ? (durations[0]!.inMinutes / totalMeasured.inMinutes) : 0.0;

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: context.nc.isDark 
                        ? [const Color(0xFF1E1B4B).withOpacity(0.5), context.nc.scaffoldBg]
                        : [const Color(0xFFE0F2FE), context.nc.scaffoldBg],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Text(
                        'Stress',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: context.nc.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.selectedDate.day} ${_getMonthMap()[widget.selectedDate.month]} ${widget.selectedDate.year} ⌄',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.nc.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Circular Gauge
                      SizedBox(
                        height: 220,
                        width: 220,
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _gaugeAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: StressHeroGaugePainter(
                                  progress: _gaugeAnimation.value,
                                  classification: _getClassification(widget.stressScore),
                                  isDark: context.nc.isDark,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${widget.stressScore}',
                                        style: TextStyle(
                                          fontSize: 56,
                                          fontWeight: FontWeight.w800,
                                          color: context.nc.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        _getClassification(widget.stressScore),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: _getColorForLevel(widget.stressScore < 25 ? 0 : widget.stressScore < 50 ? 1 : widget.stressScore < 75 ? 2 : 3),
                                        ),
                                      ),
                                    ],
                                  ),
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
            ),
            leading: Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: context.nc.cardSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.nc.cardBorder, width: 1),
                ),
                child: IconButton(
                  icon: Icon(LucideIcons.chevronLeft, color: context.nc.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0, top: 4, bottom: 4),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.nc.cardSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.nc.cardBorder, width: 1),
                  ),
                  child: IconButton(
                    icon: Icon(LucideIcons.info, color: context.nc.textPrimary),
                    onPressed: () => _showInfoBottomSheet(context),
                  ),
                ),
              ),
            ],
          ),

          // Content below gauge
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stat cards back-to-back
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          iconFallback: LucideIcons.activity,
                          title: 'Last HRV',
                          value: '${widget.lastHrv?.round() ?? widget.hrv?.round() ?? '--'}',
                          unit: 'ms',
                          subtitle: widget.lastHrvTime != null ? 'Updated: ${_formatTime(widget.lastHrvTime)}' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          iconFallback: LucideIcons.heart,
                          title: 'Last HR',
                          value: '${widget.lastHr ?? widget.rhr ?? '--'}',
                          unit: 'bpm',
                          subtitle: widget.lastHrTime != null ? 'Updated: ${_formatTime(widget.lastHrTime)}' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Insight box
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.nc.cardSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.nc.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(LucideIcons.brain, size: 16, color: context.nc.textTertiary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Balanced Stress Day',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: context.nc.textPrimary,
                                ),
                              ),
                            ),
                            Icon(LucideIcons.maximize2, size: 14, color: context.nc.textTertiary),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stress was on par with your 3-day average reflecting a steady physiological state despite a 15% drop in overall Strain. You spent ample minutes in Low Stress, which likely helped your Sleep Score climb.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: context.nc.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Today's Stress header
                  Text(
                    '${widget.selectedDate.day} ${_getMonthMap()[widget.selectedDate.month]} ${widget.selectedDate.year}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.nc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TODAY\'S STRESS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: context.nc.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timeline Chart
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: StressTimelinePainter(
                        data: widget.intradayStress,
                        isDark: context.nc.isDark,
                      ),
                    ),
                  ),

                  // X-Axis labels for chart
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('12:00 AM', style: TextStyle(fontSize: 11, color: context.nc.textTertiary)),
                        Text('6:00 AM', style: TextStyle(fontSize: 11, color: context.nc.textTertiary)),
                        Text('12:00 PM', style: TextStyle(fontSize: 11, color: context.nc.textTertiary)),
                        Text('6:00 PM', style: TextStyle(fontSize: 11, color: context.nc.textTertiary)),
                      ],
                    ),
                  ),

                  // Duration Header
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Duration:  ${_formatDuration(totalMeasured)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.nc.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Progress Bars
                  _StressDurationRow(label: 'High', percentage: highPct, duration: _formatDuration(durations[3]!), color: const Color(0xFFEF4444)),
                  const SizedBox(height: 12),
                  _StressDurationRow(label: 'Med', percentage: medPct, duration: _formatDuration(durations[2]!), color: const Color(0xFFFBBF24)),
                  const SizedBox(height: 12),
                  _StressDurationRow(label: 'Low', percentage: lowPct, duration: _formatDuration(durations[1]!), color: const Color(0xFF34D399)),
                  const SizedBox(height: 12),
                  _StressDurationRow(label: 'Rest', percentage: restPct, duration: _formatDuration(durations[0]!), color: const Color(0xFF60A5FA)),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    'Trends',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.nc.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Mini Trends list
                  _TrendCard(title: 'Stress Score', value: '${widget.stressScore}', color: const Color(0xFFEAB308), data: [60, 40, 50, 30, 70, 45, widget.stressScore.toDouble()]),
                  _TrendCard(title: 'Non-Activity Stress', value: '${(widget.stressScore * 1.2).round()}', color: const Color(0xFF38BDF8), data: [50, 60, 40, 50, 45, 60, (widget.stressScore * 1.2)]),
                  _TrendCard(title: 'Sleep Stress', value: '${(widget.stressScore * 0.4).round()}', color: const Color(0xFF38BDF8), data: [20, 15, 25, 10, 30, 15, (widget.stressScore * 0.4)]),
                  
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoBottomSheet(BuildContext context) {
    const String description = 'Stress is calculated by analyzing your heart rate variability (HRV) and heart rate in real-time. It represents the physiological load on your autonomic nervous system. High levels indicate higher sympathetic activation (fight or flight), while low levels indicate parasympathetic dominance (rest and digest).';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'About Stress',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: context.nc.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                DashboardCard(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    LucideIcons.x,
                    size: 20,
                    color: context.nc.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              description,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.nc.textPrimary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Map<int, String> _getMonthMap() => {
    1: 'January', 2: 'February', 3: 'March', 4: 'April', 5: 'May', 6: 'June',
    7: 'July', 8: 'August', 9: 'September', 10: 'October', 11: 'November', 12: 'December'
  };
}

class _StatBox extends StatelessWidget {
  final IconData iconFallback;
  final String title;
  final String value;
  final String unit;
  final String? subtitle;

  const _StatBox({
    required this.iconFallback,
    required this.title,
    required this.value,
    required this.unit,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(iconFallback, size: 14, color: context.nc.textTertiary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.nc.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.nc.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.nc.textTertiary,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: context.nc.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StressDurationRow extends StatelessWidget {
  final String label;
  final double percentage; // 0.0 to 1.0
  final String duration;
  final Color color;

  const _StressDurationRow({
    required this.label,
    required this.percentage,
    required this.duration,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.nc.textPrimary,
              ),
            ),
          ),
          // Colored Bar
          Expanded(
            child: Row(
              children: [
                if ((percentage * 100).toInt() > 0)
                  Expanded(
                    flex: (percentage * 100).toInt(),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: percentage > 0.95 ? BorderRadius.circular(4) : const BorderRadius.horizontal(left: Radius.circular(4)),
                      ),
                    ),
                  ),
                if (100 - (percentage * 100).toInt() > 0)
                  Expanded(
                    flex: 100 - (percentage * 100).toInt(),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: percentage < 0.05 ? BorderRadius.circular(4) : const BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Percentage Text
          SizedBox(
            width: 40,
            child: Text(
              '${(percentage * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.nc.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Time Text
          SizedBox(
            width: 70,
            child: Text(
              duration,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: context.nc.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final List<double> data;

  const _TrendCard({
    required this.title,
    required this.value,
    required this.color,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Convert double list to history format
        final history = data.asMap().entries.map((e) => {
          'date': DateTime.now().subtract(Duration(days: data.length - 1 - e.key)),
          'value': e.value,
        }).toList();

        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (context) => MetricDetailScreen(
              title: title,
              currentValue: value,
              unit: '',
              historyData: history,
              color: color,
              insight: 'Detailed analysis for $title based on historical physiological data.',
              healthRepository: HealthRepository(),
            ),
          ),
        );
      },
      child: DashboardCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.activity, size: 14, color: context.nc.textTertiary),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.nc.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      Icon(LucideIcons.chevronRight, size: 16, color: context.nc.textTertiary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: context.nc.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(LucideIcons.checkCircle2, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      const Text(
                        'Normal range',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 80,
              height: 40,
              child: CustomPaint(painter: MiniSparklinePainter(data: data, color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

class StressHeroGaugePainter extends CustomPainter {
  final double progress;
  final String classification;
  final bool isDark;

  StressHeroGaugePainter({required this.progress, required this.classification, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);

    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    int numTicks = 80;
    double startAngle = math.pi * 0.75;
    double sweepAngle = math.pi * 1.5;

    for (int i = 0; i <= numTicks; i++) {
      double pct = i / numTicks;
      double angle = startAngle + (pct * sweepAngle);
      
      Color startColor = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFF1F5F9);
      if (pct <= progress) {
        if (pct < 0.25) {
          startColor = const Color(0xFF60A5FA);
        } else if (pct < 0.50) {
          startColor = const Color(0xFF34D399);
        } else if (pct < 0.75) {
          startColor = const Color(0xFFFBBF24);
        } else {
          startColor = const Color(0xFFEF4444);
        }
      }

      tickPaint.color = startColor;
      double innerRadius = (i % 10 == 0) ? radius - 16 : radius - 10;
      
      final p1 = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant StressHeroGaugePainter old) => old.progress != progress || old.isDark != isDark;
}

class StressTimelinePainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final bool isDark;

  StressTimelinePainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()..strokeWidth = 4.0..strokeCap = StrokeCap.round;
    final double colWidth = size.width / 96; // 15-min intervals over 24h

    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final level = point['level'] as int;
      final score = point['score'] as int;
      
      final double x = i * colWidth;
      final double barHeight = (score / 100) * size.height;
      
      paint.color = _getColorForLevel(level);
      
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x, size.height - barHeight),
        paint,
      );
    }

    // Baseline axis
    final axisPaint = Paint()..color = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0)..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
  }

  Color _getColorForLevel(int level) {
    switch (level) {
      case 0: return const Color(0xFF60A5FA);
      case 1: return const Color(0xFF34D399);
      case 2: return const Color(0xFFFBBF24);
      case 3: return const Color(0xFFF87171);
      case 4: return const Color(0xFF94A3B8).withOpacity(0.5);
      default: return const Color(0xFFE2E8F0);
    }
  }

  @override
  bool shouldRepaint(covariant StressTimelinePainter old) => old.data != data || old.isDark != isDark;
}

class MiniSparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  MiniSparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final double dx = size.width / (data.length - 1);
    
    double min = data.reduce(math.min);
    double max = data.reduce(math.max);
    double range = max - min;
    if (range == 0) range = 1;

    for (int i = 0; i < data.length; i++) {
      double x = i * dx;
      double y = size.height - ((data[i] - min) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant MiniSparklinePainter old) => old.data != data;
}
