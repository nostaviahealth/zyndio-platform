import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../providers/daily_feed_provider.dart';
import 'daily_feed_card.dart';
import '../../../config/theme.dart';

/// A swipeable card stack for the health timeline.
class SwipeableTimeline extends StatefulWidget {
  final List<DaySnapshot> snapshots;

  const SwipeableTimeline({super.key, required this.snapshots});

  @override
  State<SwipeableTimeline> createState() => _SwipeableTimelineState();
}

class _SwipeableTimelineState extends State<SwipeableTimeline> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  Offset _dragOffset = Offset.zero;
  double _rotation = 0;

  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    // Used for physical spring bounciness
    _slideController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _slideController.stop();
    HapticFeedback.selectionClick(); // Tactile confirmation on grab
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Freeform movement
      _dragOffset += details.delta;
      // Rotational gravity: dynamic tilt based on horizontal pull
      _rotation = (_dragOffset.dx / MediaQuery.of(context).size.width) * 0.15;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final threshold = screenWidth * 0.3; // 30% of screen to trigger
    final velocity = details.velocity.pixelsPerSecond.dx;
    
    // Trigger swipe if threshold met OR strong flick
    if (_dragOffset.dx.abs() > threshold || velocity.abs() > 800) {
      final swipedRight = (velocity > 0) || (_dragOffset.dx > 0 && velocity.abs() < 200);

      // Guard boundaries against swiping past limits
      if (swipedRight && _currentIndex == 0) {
        _springBack();
        return;
      }
      if (!swipedRight && _currentIndex == widget.snapshots.length - 1) {
        _springBack();
        return;
      }
      
      _flickAway(swipedRight);
    } else {
      _springBack();
    }
  }

  void _springBack() {
    HapticFeedback.lightImpact(); // Subtle physical bump on release 
    final startOffset = _dragOffset;
    final startRotation = _rotation;

    _slideController.duration = const Duration(milliseconds: 500);
    _slideController.reset();

    // Apple-style elastic rubber band snap back
    final anim = CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack);
    anim.addListener(() {
      setState(() {
        _dragOffset = Offset.lerp(startOffset, Offset.zero, anim.value)!;
        _rotation = lerpDouble(startRotation, 0.0, anim.value)!;
      });
    });

    _slideController.forward();
  }

  void _flickAway(bool right) {
    HapticFeedback.mediumImpact(); // Satisfying click on successful pagination
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset = Offset(right ? screenWidth * 1.5 : -screenWidth * 1.5, _dragOffset.dy);
    final startOffset = _dragOffset;
    final startRotation = _rotation;

    _slideController.duration = const Duration(milliseconds: 350);
    _slideController.reset();

    // Smooth ballistic exit curve
    final anim = CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic);
    anim.addListener(() {
      setState(() {
        _dragOffset = Offset.lerp(startOffset, targetOffset, anim.value)!;
        _rotation = lerpDouble(startRotation, right ? 0.2 : -0.2, anim.value)!;
      });
    });

    _slideController.forward().then((_) {
      _dismissCard(right);
    });
  }

  void _dismissCard(bool swipedRight) {
    setState(() {
      if (swipedRight) {
        _currentIndex--;
      } else {
        _currentIndex++;
      }
      // Instantly reset coordinates for the new front card without animation
      _dragOffset = Offset.zero;
      _rotation = 0;
    });
  }



  @override
  Widget build(BuildContext context) {
    if (widget.snapshots.isEmpty) return const SizedBox.shrink();

    // Stack depth: front card sizes the stack naturally.
    final hasNext = _currentIndex < widget.snapshots.length - 1;
    final screenWidth = MediaQuery.of(context).size.width;

    // --- PARALLAX ENGINE ---
    // Calculate fractional drag progress (0.0 to 1.0)
    final dragProgress = (_dragOffset.dx.abs() / screenWidth).clamp(0.0, 1.0);
    
    // Back card dynamic scaling (breathes from 0.94 up to 1.0)
    final backScale = 0.94 + (0.06 * dragProgress);
    // Back card dynamic opacity (fades cleanly from 45% to 100%)
    final backOpacity = (0.45 + (0.55 * dragProgress)).clamp(0.0, 1.0);


    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card stack — Adjusted height viewport to be more responsive
            SizedBox(
              height: 580,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.hardEdge, // Hide overflow during swipes
            children: [
              // Back card: Top-aligned and parallax-driven
              if (hasNext)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Transform.scale(
                      scale: backScale,
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: backOpacity,
                        child: DailyFeedCard(snapshot: widget.snapshots[_currentIndex + 1]),
                      ),
                    ),
                  ),
                ),

              // Front card: Positioned.fill + Fluid Pan Handlers
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Transform.translate(
                    offset: _dragOffset,
                    child: Transform.rotate(
                      angle: _rotation,
                      child: DailyFeedCard(snapshot: widget.snapshots[_currentIndex]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Progress pips (animated for smooth transitions)
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.snapshots.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: index == _currentIndex ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: index == _currentIndex
                    ? const Color(0xFF10B981)
                    : context.nc.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Navigation controls
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
              icon: Icons.replay_rounded,
              color: const Color(0xFF64748B),
              onTap: () => setState(() => _currentIndex = 0),
            ),
            const SizedBox(width: 32),
            _ActionButton(
              icon: Icons.arrow_back_ios_new_rounded,
              color: context.nc.inputFill,
              iconColor: const Color(0xFF475569),
              onTap: _currentIndex > 0
                  ? () => setState(() => _currentIndex--)
                  : null,
            ),
            const SizedBox(width: 24),
            _ActionButton(
              icon: Icons.arrow_forward_ios_rounded,
              color: context.nc.inputFill,
              iconColor: const Color(0xFF475569),
              onTap: _currentIndex < widget.snapshots.length - 1
                  ? () => setState(() => _currentIndex++)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    this.iconColor = Colors.white,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.3 : 1.0,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }
}
