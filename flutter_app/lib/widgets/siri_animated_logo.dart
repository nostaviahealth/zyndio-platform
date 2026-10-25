import 'package:flutter/material.dart';
import 'dart:math' as math;

class SiriAnimatedLogo extends StatefulWidget {
  final double size;
  const SiriAnimatedLogo({super.key, this.size = 24});

  @override
  State<SiriAnimatedLogo> createState() => _SiriAnimatedLogoState();
}

class _SiriAnimatedLogoState extends State<SiriAnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: const [
                  Color(0xFFF59E0B), // Orange
                  Color(0xFFA855F7), // Purple
                  Color(0xFF3B82F6), // Blue
                  Color(0xFF22D3EE), // Cyan
                  Color(0xFFF43F5E), // Pink
                  Color(0xFFF59E0B), // Loop back
                ],
                transform: GradientRotation(_controller.value * 2 * math.pi),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA855F7).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Container(
              margin: EdgeInsets.all(widget.size * 0.15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: Container(
                margin: EdgeInsets.all(widget.size * 0.15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.4),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
