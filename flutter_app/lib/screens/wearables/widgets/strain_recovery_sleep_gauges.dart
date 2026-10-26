import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dashboard_card_style.dart';
import '../../../../config/theme.dart';

/// A combined card showing Strain, Recovery, and Sleep circular gauges,
/// along with an AI coaching insight matching the exact WHOOP reference UI.
class PerformanceCoachingCard extends StatelessWidget {
  final int strainPercent; // 0-100
  final int recoveryPercent; // 0-100
  final int sleepPercent; // 0-100
  final String insight;
  final VoidCallback? onStrainTap;
  final VoidCallback? onRecoveryTap;
  final VoidCallback? onSleepTap;

  const PerformanceCoachingCard({
    super.key,
    required this.strainPercent,
    required this.recoveryPercent,
    required this.sleepPercent,
    required this.insight,
    this.onStrainTap,
    this.onRecoveryTap,
    this.onSleepTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: DashboardCardStyle.decorationOf(context).copyWith(
            boxShadow: [], // Shadow handled by outer container if needed
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gauges Section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: onStrainTap,
                      behavior: HitTestBehavior.opaque,
                      child: _GaugeItem(
                        label: 'Strain',
                        percent: strainPercent,
                        colors: const [
                          Color(0xFFFFD700), // Gold
                          Color(0xFFF97316), // Orange-500
                          Color(0xFFEF4444), // Red-500
                        ],
                        hasStripePattern: false,
                      ),
                    ),
                  ),
                  VerticalDivider(
                    color: context.nc.isDark 
                        ? context.nc.divider.withOpacity(0.05) 
                        : BrandColors.slate200.withOpacity(0.5),
                    thickness: 1,
                    width: 1,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: onRecoveryTap,
                      behavior: HitTestBehavior.opaque,
                      child: _GaugeItem(
                        label: 'Recovery',
                        percent: recoveryPercent,
                        colors: const [
                          Color(0xFFBBF7D0), // Green-200
                          Color(0xFF22C55E), // Green-500
                          Color(0xFF15803D), // Green-700
                        ],
                      ),
                    ),
                  ),
                  VerticalDivider(
                    color: context.nc.isDark 
                        ? context.nc.divider.withOpacity(0.05) 
                        : BrandColors.slate200.withOpacity(0.5),
                    thickness: 1,
                    width: 1,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: onSleepTap,
                      behavior: HitTestBehavior.opaque,
                      child: _GaugeItem(
                        label: 'Sleep',
                        percent: sleepPercent,
                        colors: const [
                          Color(0xFFC7D2FE), // Indigo-200
                          Color(0xFF6366F1), // Indigo-500
                          Color(0xFF4338CA), // Indigo-700
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    ),
  );
}
}

class _GaugeItem extends StatelessWidget {
  final String label;
  final int percent;
  final List<Color> colors;
  final bool hasStripePattern;

  const _GaugeItem({
    required this.label,
    required this.percent,
    required this.colors,
    this.hasStripePattern = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: context.nc.cardSurface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: context.nc.shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: CustomPaint(
              painter: _GaugePainter(
                percent: percent / 100.0,
                colors: colors,
                hasStripePattern: hasStripePattern,
                trackColor: context.nc.isDark ? context.nc.inputFill : const Color(0xFFF1F5F9),
              ),
              child: Center(
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: context.nc.isDark ? context.nc.textPrimary : BrandColors.dark,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.nc.isDark ? context.nc.textSecondary : BrandColors.slate500,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double percent;
  final List<Color> colors;
  final bool hasStripePattern;
  final Color trackColor;

  _GaugePainter({
    required this.percent,
    required this.colors,
    required this.hasStripePattern,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width) / 2;
    const strokeWidth = 10.0; // Slightly thicker for WHOOP premium feel
    
    // Angles: Start at 7:30 (135 deg), Total sweep 270 deg.
    // This leaves a 90 deg gap centered at 6 o'clock.
    const startAngle = math.pi * 135 / 180;
    const sweepTotal = math.pi * 270 / 180; 

    // Base track (light gray)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    // Value arc
    if (percent > 0) {
      final sweepValue = sweepTotal * percent.clamp(0.001, 1.0); // Never 0 here

      // SEAMLESS GRADIENT:
      // Rotate gradient so the seam (0/1 point) is at 6 o'clock (PI/2).
      // Since our visible arc spans from 135 to 45 (wrap), 
      // the mid-gap is 90 (bottom/6 o'clock).
      // Placing the seam at PI/2 ensures the entire visible arc is smooth.
      final gradient = SweepGradient(
        colors: colors,
        transform: const GradientRotation(math.pi / 2),
      );

      final valuePaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        startAngle,
        sweepValue,
        false,
        valuePaint,
      );
      
      // Calculate interpolated color for the leading dot
      final Color currentDotColor = _getInterpolatedColor(colors, percent);

      // Draw leading dot
      final dotAngle = startAngle + sweepValue;
      final dotX = center.dx + radius * math.cos(dotAngle);
      final dotY = center.dy + radius * math.sin(dotAngle);
      
      // Shadow/Glow for the dot
      canvas.drawCircle(
        Offset(dotX, dotY), 
        (strokeWidth / 2) + 2, 
        Paint()
          ..color = currentDotColor.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      canvas.drawCircle(Offset(dotX, dotY), strokeWidth / 2, Paint()..color = currentDotColor);
    } else {
        // if 0%, draw a very faint dot at the start to indicate the origin
        final dotX = center.dx + radius * math.cos(startAngle);
        final dotY = center.dy + radius * math.sin(startAngle);
        canvas.drawCircle(Offset(dotX, dotY), strokeWidth / 2, Paint()..color = colors.first.withOpacity(0.3));
    }
  }

  Color _getInterpolatedColor(List<Color> colors, double percent) {
    if (colors.isEmpty) return Colors.transparent;
    if (colors.length == 1) return colors.first;
    
    final double value = percent.clamp(0.0, 1.0) * (colors.length - 1);
    final int index = value.floor();
    final double fraction = value - index;
    
    if (index >= colors.length - 1) return colors.last;
    
    return Color.lerp(colors[index], colors[index + 1], fraction)!;
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.percent != percent ||
           oldDelegate.colors != colors;
  }
}
