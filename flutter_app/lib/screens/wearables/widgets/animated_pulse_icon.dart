import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class AnimatedPulseIcon extends StatefulWidget {
  final double size;
  final Color? color;

  const AnimatedPulseIcon({
    super.key,
    this.size = 48,
    this.color,
  });

  @override
  State<AnimatedPulseIcon> createState() => _AnimatedPulseIconState();
}

class _AnimatedPulseIconState extends State<AnimatedPulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _PulseWavePainter(
            progress: _controller.value,
            color: widget.color ?? BrandColors.emerald500,
          ),
        );
      },
    );
  }
}

class _PulseWavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _PulseWavePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final double width = size.width;
    final double height = size.height;
    final double midY = height / 2;

    final Path path = Path();
    path.moveTo(0, midY);

    // Create a pulse wave path
    for (double i = 0; i < width; i++) {
        double x = i;
        double y = midY;

        // The "beat" part of the pulse
        // We calculate a normalized x position for the beat
        // We use a sine-like function with sharp peak
        double beatCenter = width * progress;
        double dist = (x - beatCenter).abs();
        
        // Wrap around for seamless loop
        double distWrapped = math.min(dist, (x - (beatCenter + width)).abs());
        distWrapped = math.min(distWrapped, (x - (beatCenter - width)).abs());

        if (distWrapped < 15) {
            // Heartbeat morphology: P-QRS-T approximation
            // Sharp QRS complex
            double qrs = math.exp(-math.pow(distWrapped / 2, 2)) * -20;
            // Smaller T wave
            double tWave = math.exp(-math.pow((distWrapped - 6) / 4, 2)) * 5;
            
            y += qrs + tWave;
        }

        path.lineTo(x, y);
    }

    // Gradient stroke for the "active" trailing effect
    final Rect rect = Rect.fromLTWH(0, 0, width, height);
    paint.shader = LinearGradient(
      colors: [
        color.withOpacity(0.1),
        color,
        color.withOpacity(0.1),
      ],
      stops: [
          (progress - 0.3).clamp(0.0, 1.0),
          progress.clamp(0.0, 1.0),
          (progress + 0.3).clamp(0.0, 1.0),
      ],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ).createShader(rect);

    canvas.drawPath(path, paint);

    // Draw the "scanning" glowing dot at the tip
    final double dotX = width * progress;
    // Calculate the Y at dotX (approximate)
    double dotY = midY;
    double qrs = math.exp(-math.pow(0 / 2, 2)) * -20;
    dotY += qrs;

    final Paint dotPaint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);
    
    canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PulseWavePainter oldDelegate) => true;
}
