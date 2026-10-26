import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dashboard_card_style.dart';
import '../../../config/theme.dart';

class StressEnergyCard extends StatelessWidget {
  final int stressScore;
  final int energyScore;
  final int stressHigh;
  final int stressLow;
  final int stressAvg;
  final VoidCallback onStressTap;
  final VoidCallback onEnergyTap;

  const StressEnergyCard({
    super.key,
    required this.stressScore,
    required this.energyScore,
    required this.stressHigh,
    required this.stressLow,
    required this.stressAvg,
    required this.onStressTap,
    required this.onEnergyTap,
  });

  String _getClassification(int score) {
    if (score < 25) return 'Rest';
    if (score < 50) return 'Low';
    if (score < 75) return 'Medium';
    return 'High';
  }

  Color _getColorForLevel(int level, bool isDark) {
    switch (level) {
      case 0: return const Color(0xFF60A5FA); // Rest (Blue)
      case 1: return const Color(0xFF34D399); // Low (Green)
      case 2: return const Color(0xFFFBBF24); // Med (Yellow)
      case 3: return const Color(0xFFF87171); // High (Orange/Red)
      default: return isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine color class for stress (0-3)
    final int stressLevel = stressScore < 25 ? 0 : stressScore < 50 ? 1 : stressScore < 75 ? 2 : 3;
    final now = DateTime.now();
    final timeString = "${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Card Container (Stress)
        GestureDetector(
          onTap: onStressTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: DashboardCardStyle.decorationOf(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header row
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getColorForLevel(stressLevel, context.nc.isDark),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Today\'s stress',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.nc.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Icon(LucideIcons.arrowRight, size: 20, color: context.nc.textTertiary),
                  ],
                ),
                const SizedBox(height: 4),
                // Dynamic updated time
                Text(
                  'Last updated at $timeString',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.nc.textSecondary,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Content Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Stats side
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _VerticalStat(title: 'Highest', value: '$stressHigh', color: const Color(0xFFF97316)),
                          Container(width: 1, height: 40, color: context.nc.divider),
                          _VerticalStat(title: 'Lowest', value: '$stressLow', color: const Color(0xFF34D399)),
                          Container(width: 1, height: 40, color: context.nc.divider),
                          _VerticalStat(title: 'Average', value: '$stressAvg', color: const Color(0xFF64A338)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Circular Gauge
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(
                        painter: DashStressGaugePainter(progress: stressScore / 100.0, isDark: context.nc.isDark),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$stressScore',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w500,
                                  color: context.nc.textPrimary,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                _getClassification(stressScore),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _getColorForLevel(stressLevel, context.nc.isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Bottom Energy Bar
        GestureDetector(
          onTap: onEnergyTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: DashboardCardStyle.decorationOf(context),
            child: Row(
              children: [
                const Icon(LucideIcons.zap, size: 24, color: Color(0xFF22C55E)),
                const SizedBox(width: 16),
                
                // Custom Battery Marks
                Expanded(
                  child: CustomPaint(
                    size: const Size(double.infinity, 24),
                    painter: DashEnergyBatteryPainter(progress: energyScore / 100.0, isDark: context.nc.isDark),
                  ),
                ),
                
                const SizedBox(width: 12),
                Text(
                  energyScore < 0 ? '--%' : '$energyScore%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: context.nc.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VerticalStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _VerticalStat({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.nc.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// CUSTOM PAINTERS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class DashStressGaugePainter extends CustomPainter {
  final double progress; 
  final bool isDark;

  DashStressGaugePainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw outer tick marks
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    int numTicks = 60;
    // Sweep from bottom left to bottom right (leave a small gap)
    double startAngle = math.pi * 0.8;
    double sweepAngle = math.pi * 1.4;

    for (int i = 0; i <= numTicks; i++) {
      double pct = i / numTicks;
      double angle = startAngle + (pct * sweepAngle);
      
      Color tickColor = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFF1F5F9); 
      if (pct <= progress) {
        if (pct < 0.25) {
          tickColor = const Color(0xFF60A5FA);
        } else if (pct < 0.50) tickColor = const Color(0xFF34D399);
        else if (pct < 0.75) tickColor = const Color(0xFFFBBF24);
        else tickColor = const Color(0xFFEF4444);
      }

      tickPaint.color = tickColor;

      double innerRadius = (i % 10 == 0) ? radius - 8 : radius - 4;
      
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
  bool shouldRepaint(DashStressGaugePainter old) => old.progress != progress || old.isDark != isDark;
}

class DashEnergyBatteryPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  DashEnergyBatteryPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    int totalBars = 35; 
    double gap = 4.0;
    double barWidth = (size.width - (gap * (totalBars - 1))) / totalBars;
    if (barWidth < 1) barWidth = 1.0; 

    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < totalBars; i++) {
      double pct = i / totalBars;
      double x = i * (barWidth + gap) + (barWidth / 2);
      
      if (pct < progress) {
        paint.color = const Color(0xFF22C55E); // Bright Green
      } else {
        paint.color = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE2E8F0); // Gray empty
      }
      
      // Constrain points so the stroke radius doesn't bleed out of bounding box
      double yStart = barWidth / 2;
      double yEnd = size.height - (barWidth / 2);

      canvas.drawLine(Offset(x, yStart), Offset(x, yEnd), paint);
    }
  }

  @override
  bool shouldRepaint(DashEnergyBatteryPainter old) => old.progress != progress || old.isDark != isDark;
}
