import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../config/theme.dart';

class AuthBackground extends StatefulWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  State<AuthBackground> createState() => _AuthBackgroundState();
}

class _AuthBackgroundState extends State<AuthBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: Stack(
        children: [
          // Aurora Blobs
          if (isDark) ...[
            _buildAuroraBlob(
              color: const Color(0xFFFBBF24), // Ethereal Gold
              top: -100,
              right: -50,
              size: 500,
              opacity: 0.08,
            ),
            _buildAuroraBlob(
              color: const Color(0xFF4F46E5), // Deep Indigo
              bottom: 150,
              left: -100,
              size: 600,
              opacity: 0.12,
            ),
            _buildAuroraBlob(
              color: const Color(0xFF10B981), // Zenith Jade
              bottom: -200,
              right: -100,
              size: 550,
              opacity: 0.1,
            ),
          ] else ...[
            // Light Mode: Very subtle soft blobs
            _buildAuroraBlob(
              color: const Color(0xFF3B82F6), // Blue
              top: -50,
              left: -50,
              size: 300,
              opacity: 0.05,
            ),
            _buildAuroraBlob(
              color: const Color(0xFF10B981), // Emerald
              bottom: -100,
              right: -100,
              size: 400,
              opacity: 0.05,
            ),
          ],

          // Animated Overlay (Subtle mesh movement)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _MeshPainter(
                    progress: _controller.value,
                    isDark: isDark,
                  ),
                );
              },
            ),
          ),

          // Content
          widget.child,
        ],
      ),
    );
  }

  Widget _buildAuroraBlob({
    required Color color,
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double opacity,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      ).blur(80),
    );
  }
}

class _MeshPainter extends CustomPainter {
  final double progress;
  final bool isDark;

  _MeshPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // We could add more complex mesh painting here if needed
    // For now, let's keep it simple with just the blurred blobs
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) => oldDelegate.progress != progress;
}

extension _BlurExtension on Widget {
  Widget blur(double sigma) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: this,
    );
  }
}
