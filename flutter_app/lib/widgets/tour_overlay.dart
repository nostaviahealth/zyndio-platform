import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final bool alignBottom; // If true, forces tooltip placement below the target if possible
  final EdgeInsets padding;
  final double borderRadius;
  final Offset offset;
  final VoidCallback? onShow;

  const TourStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.alignBottom = false,
    this.padding = const EdgeInsets.all(8.0),
    this.borderRadius = 16.0,
    this.offset = Offset.zero,
    this.onShow,
  });
}

class TourOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const TourOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends State<TourOverlay> with SingleTickerProviderStateMixin {
  int _currentStepIndex = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  Rect? _targetRect;
  bool _isSearching = false;
  
  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    
    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateTarget();
    });
  }
  
  Future<void> _updateTarget() async {
    if (_isSearching) return;
    
    setState(() {
      _isSearching = true;
      _targetRect = null;
    });

    final step = widget.steps[_currentStepIndex];
    step.onShow?.call(); // Trigger navigation or action
    
    // Retry loop to allow for navigation/rendering
    for (int i = 0; i < 15; i++) { // Max 3 seconds (15 * 200ms)
      if (!mounted) return;
      
      final RenderBox? renderBox = step.targetKey.currentContext?.findRenderObject() as RenderBox?;
      
      if (renderBox != null && renderBox.hasSize) {
        final position = renderBox.localToGlobal(Offset.zero) + step.offset;
        if (mounted) {
          setState(() {
            _targetRect = Rect.fromLTWH(
              position.dx,
              position.dy,
              renderBox.size.width,
              renderBox.size.height,
            );
            _isSearching = false;
          });
          _animController.forward(from: 0.0);
        }
        return;
      }
      
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      debugPrint("TourOverlay: Target not found for step $_currentStepIndex after retries");
      setState(() => _isSearching = false);
      // Auto-skip if target still missing to prevent complete breakage
      _nextStep();
    }
  }

  void _nextStep() {
    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
        _updateTarget();
      });
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_targetRect == null) {
      // Show semi-transparent overlay while searching to prevent clicks
      return Material(
        color: BrandColors.dark.withOpacity(0.5),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final step = widget.steps[_currentStepIndex];
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // 1. Hole Overlay
        CustomPaint(
          size: screenSize,
          painter: _HoleOverlayPainter(
            targetRect: _targetRect!,
            overlayColor: BrandColors.dark.withOpacity(0.85),
            padding: step.padding,
            radius: step.borderRadius,
          ),
        ),

        // 2. Tooltip Card
        Positioned(
          top: _calculateTooltipTop(_targetRect!, screenSize, step.alignBottom),
          left: 24,
          right: 24,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _TourTooltip(
              title: step.title,
              description: step.description,
              onNext: _nextStep,
              onSkip: widget.onSkip,
              isLast: _currentStepIndex == widget.steps.length - 1,
            ),
          ),
        ),
      ],
    );
  }

  double? _calculateTooltipTop(Rect target, Size screenSize, bool preferBottom) {
    const double tooltipHeight = 200; // Approx
    const double margin = 20;

    // Check space below
    final double spaceBelow = screenSize.height - target.bottom - margin;
    final double spaceAbove = target.top - margin;
    
    if (preferBottom) {
       if (spaceBelow > tooltipHeight) return target.bottom + margin;
       return target.top - margin - tooltipHeight; // Fallback to top
    } else {
       // Prefer Top unless not enough space
       if (spaceAbove > tooltipHeight) return target.top - margin - tooltipHeight;
       return target.bottom + margin;
    }
  }
}

class _HoleOverlayPainter extends CustomPainter {
  final Rect targetRect;
  final Color overlayColor;
  final EdgeInsets padding;
  final double radius;

  _HoleOverlayPainter({
    required this.targetRect,
    required this.overlayColor,
    required this.padding,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Path overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final Rect holeRect = Rect.fromLTRB(
      targetRect.left - padding.left, 
      targetRect.top - padding.top, 
      targetRect.right + padding.right, 
      targetRect.bottom + padding.bottom
    );
    
    final Path holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(holeRect, Radius.circular(radius)));

    final Path finalPath = Path.combine(
      PathOperation.difference,
      overlayPath,
      holePath,
    );
    
    // Draw Overlay
    canvas.drawPath(finalPath, Paint()..color = overlayColor);
    
    // Draw Glow/Border around hole
    final Paint borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      
    canvas.drawRRect(RRect.fromRectAndRadius(holeRect, Radius.circular(radius)), borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HoleOverlayPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}

class _TourTooltip extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  const _TourTooltip({
    required this.title,
    required this.description,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), // Glass
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: onSkip,
                    child: Text(
                      "Skip",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: BrandColors.dark,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isLast ? "Done" : "Next"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
