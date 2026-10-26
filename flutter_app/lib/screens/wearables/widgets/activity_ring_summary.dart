import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class ActivityRingSummary extends StatelessWidget {
  final double moveKcal;
  final double moveGoal;
  final int exerciseMin;
  final int exerciseGoal;
  final int standHrs;
  final int standGoal;
  final int steps;
  final int stepsGoal;

  const ActivityRingSummary({
    super.key,
    required this.moveKcal,
    this.moveGoal = 500,
    required this.exerciseMin,
    this.exerciseGoal = 30,
    required this.standHrs,
    this.standGoal = 12,
    this.steps = 0,
    this.stepsGoal = 10000,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate percentages
    double moveProgress = moveGoal > 0 ? (moveKcal / moveGoal).clamp(0.0, 1.0) : 0;
    double exerciseProgress = exerciseGoal > 0 ? (exerciseMin / exerciseGoal).clamp(0.0, 1.0) : 0;
    double stepsProgress = stepsGoal > 0 ? (steps / stepsGoal).clamp(0.0, 1.0) : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Legend (Left)
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RingLegendItem(
                label: "Move",
                value: moveKcal.round().toString(),
                goal: "/${moveGoal.round()}",
                unit: "CAL",
              ),
              const SizedBox(height: 16),
              _RingLegendItem(
                label: "Training",
                value: exerciseMin.toString(),
                goal: "/$exerciseGoal",
                unit: "MIN",
              ),
              const SizedBox(height: 16),
              _RingLegendItem(
                label: "Steps",
                value: steps.toString(),
                goal: "/$stepsGoal",
              ),
            ],
          ),
        ),

        // Activity Rings Visualization (Right)
        Container(
          width: 170,
          height: 170,
          alignment: Alignment.centerRight,
          child: CustomPaint(
            size: const Size(170, 170),
            painter: _ConcentricRingsPainter(
              moveProgress: moveProgress,
              exerciseProgress: exerciseProgress,
              stepsProgress: stepsProgress,
              isDark: context.nc.isDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _RingLegendItem extends StatelessWidget {
  final String label;
  final String value;
  final String goal;
  final String? unit;

  const _RingLegendItem({
    required this.label,
    required this.value,
    required this.goal,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontSize: 14, 
            color: context.nc.textSecondary, 
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
          )
        ),
        const SizedBox(height: 2),
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
                letterSpacing: -0.5,
              ),
            ),
            Text(
              goal,
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.w800, 
                color: context.nc.textTertiary.withOpacity(0.4),
                letterSpacing: -0.5,
              ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Text(
                unit!,
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w700, 
                  color: context.nc.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ConcentricRingsPainter extends CustomPainter {
  final double moveProgress;
  final double exerciseProgress;
  final double stepsProgress;
  final bool isDark;
  
  _ConcentricRingsPainter({
    required this.moveProgress,
    required this.exerciseProgress,
    required this.stepsProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    const Color moveColor = Color(0xFFEF4444); // Pinkish-Red
    final Color moveBgColor = isDark ? moveColor.withOpacity(0.12) : const Color(0xFFFFE4E6); 
    
    const Color trainingColor = Color(0xFFF97316); // Orange
    final Color trainingBgColor = isDark ? trainingColor.withOpacity(0.12) : const Color(0xFFFFEDD5); 
    
    const Color stepsColor = Color(0xFF10B981); // Emerald Green
    final Color stepsBgColor = isDark ? stepsColor.withOpacity(0.12) : const Color(0xFFD1FAE5); 
    
    // Ring Dimensions
    const double strokeWidth = 20.0;
    const double spacing = 4.0;
    
    // Calculate Radii
    // Full size is 170. Center is 85.
    // Move ring radius: 85 - (20/2) = 75
    final double moveRadius = (size.width / 2) - (strokeWidth / 2);
    // Training ring radius: 75 - 20 - 4 = 51
    final double trainingRadius = moveRadius - strokeWidth - spacing;
    // Steps ring radius: 51 - 20 - 4 = 27
    final double stepsRadius = trainingRadius - strokeWidth - spacing;
    
    // Draw Background Tracks
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    
    bgPaint.color = moveBgColor;
    canvas.drawCircle(center, moveRadius, bgPaint);
    
    bgPaint.color = trainingBgColor;
    canvas.drawCircle(center, trainingRadius, bgPaint);
    
    bgPaint.color = stepsBgColor;
    canvas.drawCircle(center, stepsRadius, bgPaint);

    // Draw Progress Arcs
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const double startAngle = -math.pi / 2; // Start from top (12 o'clock)
    
    // Draw Move Progress
    if (moveProgress > 0) {
      progressPaint.color = moveColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: moveRadius),
        startAngle,
        _getSweepAngle(moveProgress),
        false,
        progressPaint,
      );
    }

    // Draw Training Progress
    if (exerciseProgress > 0) {
      progressPaint.color = trainingColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: trainingRadius),
        startAngle,
        _getSweepAngle(exerciseProgress),
        false,
        progressPaint,
      );
    }

    // Draw Steps Progress
    if (stepsProgress > 0) {
      progressPaint.color = stepsColor;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: stepsRadius),
        startAngle,
        _getSweepAngle(stepsProgress),
        false,
        progressPaint,
      );
    }
  }
  
  double _getSweepAngle(double progress) {
    // If progress is very small (like steps 155/10000 = 1.5%), 
    // it will draw a very small arc which StrokeCap.round will turn into a dot.
    // We clamp to slightly above 0 so the cap displays correctly.
    if (progress <= 0) return 0;
    if (progress < 0.001) progress = 0.001; // Ensure dot is drawn
    return (2 * math.pi) * progress;
  }

  @override
  bool shouldRepaint(covariant _ConcentricRingsPainter oldDelegate) {
    return oldDelegate.moveProgress != moveProgress ||
           oldDelegate.exerciseProgress != exerciseProgress ||
           oldDelegate.stepsProgress != stepsProgress ||
           oldDelegate.isDark != isDark;
  }
}

