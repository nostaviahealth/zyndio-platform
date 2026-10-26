import 'dart:math' as math;
import 'dart:ui'; // Added for ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_theme_provider.dart';

// No imports from health_widgets to avoid circular dependency



/// A reusable wrapper that adds a slowly rotating, highly blurred SweepGradient
/// behind its child, creating a soft "alive" glow effect meant for Intelligence features.
class IntelligenceGlowWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final bool active;
  
  const IntelligenceGlowWrapper({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.blurSigma = 25.0,
    this.active = true,
  });

  @override
  ConsumerState<IntelligenceGlowWrapper> createState() => _IntelligenceGlowWrapperState();
}

class _IntelligenceGlowWrapperState extends ConsumerState<IntelligenceGlowWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _borderController;

  @override
  void initState() {
    super.initState();
    // 8s duration for a much slower, subtle rotating aura
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    );
    
    if (widget.active) {
      _borderController.repeat();
    }
  }

  @override
  void didUpdateWidget(IntelligenceGlowWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _borderController.repeat();
      } else {
        _borderController.stop();
      }
    }
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    final aiTheme = ref.watch(aiThemeProvider);
    final isSiri = aiTheme == AIThemeMode.siri;

    return AnimatedBuilder(
      animation: _borderController,
      builder: (context, child) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Rotating Glow Aura — wrapped in RepaintBoundary to isolate
            // its 60fps repaints from the rest of the widget tree
            Positioned.fill(
              child: RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: SweepGradient(
                      colors: isSiri ? [
                           const Color(0xFFF59E0B).withOpacity(0.12),
                           const Color(0xFFA855F7).withOpacity(0.12),
                           const Color(0xFF3B82F6).withOpacity(0.12),
                           const Color(0xFF22D3EE).withOpacity(0.12),
                           const Color(0xFFF43F5E).withOpacity(0.12),
                           const Color(0xFFF59E0B).withOpacity(0.12),
                      ] : [
                        const Color(0xFF22D3EE).withOpacity(0.12),
                        const Color(0xFF38BDF8).withOpacity(0.12),
                        const Color(0xFF3B82F6).withOpacity(0.12),
                        const Color(0xFF1D4ED8).withOpacity(0.12),
                        const Color(0xFF22D3EE).withOpacity(0.12),
                      ],
                      transform: GradientRotation(_borderController.value * 2 * math.pi),
                    ),
                  ),
                ).blur(widget.blurSigma),
              ),
            ),
            
            // The actual card content — also isolated from glow repaints
            RepaintBoundary(child: widget.child),
          ],
        );
      },
    );
  }
}

// Local extension to break circular dependency
extension _BlurExtension on Widget {
   Widget blur(double sigma) {
     return ImageFiltered(
       imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
       child: this,
     );
   }
}
