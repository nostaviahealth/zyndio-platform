import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Poincaré (Lorenz) scatter plot painter.
/// Plots RR(n) vs RR(n+1) intervals to visualize autonomic balance.
class PoincarePlotPainter extends CustomPainter {
  final List<double> rrIntervals;
  final Color dotColor;
  final Color axisColor;

  PoincarePlotPainter({
    required this.rrIntervals,
    this.dotColor = const Color(0xFFEF4444),
    this.axisColor = const Color(0x33FFFFFF),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rrIntervals.length < 2) {
      _paintEmpty(canvas, size);
      return;
    }

    // Calculate bounds
    double minRR = double.infinity, maxRR = double.negativeInfinity;
    for (final v in rrIntervals) {
      if (v < minRR) minRR = v;
      if (v > maxRR) maxRR = v;
    }
    final range = (maxRR - minRR).clamp(50.0, double.infinity);
    final padding = range * 0.1;
    final lo = minRR - padding;
    final hi = maxRR + padding;

    double mapX(double v) => ((v - lo) / (hi - lo)) * size.width;
    double mapY(double v) => size.height - ((v - lo) / (hi - lo)) * size.height;

    // Draw identity line (y = x)
    final linePaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(mapX(lo), mapY(lo)),
      Offset(mapX(hi), mapY(hi)),
      linePaint,
    );

    // Draw grid lines
    final gridPaint = Paint()
      ..color = axisColor.withOpacity(0.15)
      ..strokeWidth = 0.5;
    for (int i = 1; i < 4; i++) {
      final frac = lo + (hi - lo) * (i / 4);
      canvas.drawLine(Offset(mapX(frac), 0), Offset(mapX(frac), size.height), gridPaint);
      canvas.drawLine(Offset(0, mapY(frac)), Offset(size.width, mapY(frac)), gridPaint);
    }

    // Plot RR(n) vs RR(n+1)
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < rrIntervals.length - 1; i++) {
      final x = mapX(rrIntervals[i]);
      final y = mapY(rrIntervals[i + 1]);
      // Distance from identity line determines color intensity
      final dist = (rrIntervals[i] - rrIntervals[i + 1]).abs() / range;
      dotPaint.color = dotColor.withOpacity((0.3 + dist * 2).clamp(0.3, 0.9));
      canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
    }
  }

  void _paintEmpty(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Awaiting R-R data',
        style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant PoincarePlotPainter old) =>
      old.rrIntervals != rrIntervals;
}

/// Circular gauge painter for Cardiovascular Age.
class CardioAgeGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final Color trackColor;
  final List<Color> gradientColors;

  CardioAgeGaugePainter({
    required this.progress,
    this.trackColor = const Color(0x1AFFFFFF),
    this.gradientColors = const [Color(0xFF10B981), Color(0xFF3B82F6)],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const startAngle = -math.pi * 0.75;
    const sweepTotal = math.pi * 1.5;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepTotal, false, trackPaint,
    );

    // Progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final progressPaint = Paint()
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepTotal,
          colors: gradientColors,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepTotal * progress.clamp(0, 1), false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CardioAgeGaugePainter old) =>
      old.progress != progress;
}

/// Mini sparkline chart for trend data.
class MiniSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color fillColor;

  MiniSparklinePainter({
    required this.values,
    this.lineColor = const Color(0xFFEF4444),
    this.fillColor = const Color(0x1AEF4444),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = (maxV - minV).clamp(1.0, double.infinity);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1).clamp(1, double.infinity)) * size.width;
      final y = size.height - ((values[i] - minV) / range) * size.height * 0.85;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant MiniSparklinePainter old) =>
      old.values != values;
}
