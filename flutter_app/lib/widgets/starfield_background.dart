import 'dart:math';
import 'package:flutter/material.dart';

class StarfieldBackground extends StatefulWidget {
  const StarfieldBackground({super.key});

  @override
  State<StarfieldBackground> createState() => _StarfieldBackgroundState();
}

class _StarfieldBackgroundState extends State<StarfieldBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Star> _stars = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // Slow rotation
    )..repeat();

    _generateStars();
  }

  void _generateStars() {
    final random = Random();
    for (int i = 0; i < 150; i++) {
      _stars.add(Star(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 1.2 + 0.3, // Tiny stars (0.3 - 1.5)
        opacity: random.nextDouble() * 0.7 + 0.1, // Fainter
        speed: random.nextDouble() * 0.02 + 0.005, // Slower (0.005 - 0.025)
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _StarfieldPainter(_stars, _controller.value),
          );
        },
      ),
    );
  }
}

class Star {
  double x;
  double y;
  final double size;
  final double opacity;
  final double speed;

  Star({required this.x, required this.y, required this.size, required this.opacity, required this.speed});
}

class _StarfieldPainter extends CustomPainter {
  final List<Star> stars;
  final double progress;

  _StarfieldPainter(this.stars, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var star in stars) {
      // Simulate movement
      // We use progress simply to prompt repaint, but logic can be time based.
      // Simple parallax: move y slightly down
      // But actually, simple static twinkling or slow drift is better.
      
      // We'll calculate a drifted Y based on progress
      double dy = (star.y + (progress * star.speed)) % 1.0;
      
      final dx = star.x * size.width;
      final effectiveY = dy * size.height;

      paint.color = Colors.white.withOpacity(star.opacity);
      canvas.drawCircle(Offset(dx, effectiveY), star.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarfieldPainter old) => old.progress != progress;
}
