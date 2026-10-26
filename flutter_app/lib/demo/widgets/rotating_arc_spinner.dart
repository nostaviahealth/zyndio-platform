import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Sending-state spinner: an animated rotating partial arc, not a static
/// full ring. In demo/screenshot mode ([MediaQuery.disableAnimations], set
/// globally by `DemoApp` for the screenshot harness) it renders frozen at a
/// fixed mid-arc angle so screenshots stay deterministic.
class RotatingArcSpinner extends StatefulWidget {
  const RotatingArcSpinner({
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 3,
  });

  final double size;
  final Color color;
  final double strokeWidth;

  /// Fixed turn (0..1) painted when animations are disabled.
  static const double frozenTurn = 0.4;

  @override
  State<RotatingArcSpinner> createState() => _RotatingArcSpinnerState();
}

class _RotatingArcSpinnerState extends State<RotatingArcSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animated = !MediaQuery.of(context).disableAnimations;
    if (animated) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return CustomPaint(
        size: Size.square(widget.size),
        painter: ArcSpinnerPainter(
          turn: RotatingArcSpinner.frozenTurn,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: ArcSpinnerPainter(
          turn: _controller.value,
          color: widget.color,
          strokeWidth: widget.strokeWidth,
        ),
      ),
    );
  }
}

/// Public so widget tests can inspect the painted [turn] directly instead of
/// relying on pixel diffing to prove the spinner is actually rotating.
class ArcSpinnerPainter extends CustomPainter {
  const ArcSpinnerPainter({required this.turn, required this.color, required this.strokeWidth});

  /// 0..1 fraction of a full turn.
  final double turn;
  final Color color;
  final double strokeWidth;

  static const double _sweep = math.pi * 1.2; // partial arc, never a full ring

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, turn * 2 * math.pi, _sweep, false, paint);
  }

  @override
  bool shouldRepaint(covariant ArcSpinnerPainter oldDelegate) =>
      oldDelegate.turn != turn || oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
