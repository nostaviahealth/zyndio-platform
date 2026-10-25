import 'package:flutter/material.dart';

/// Brainwave frequency zones
enum BrainwaveZone {
  delta,  // 2 Hz - Deep sleep
  theta,  // 6 Hz - Meditation
  alpha,  // 10 Hz - Calm focus
  beta,   // 20 Hz - Active thinking
  gamma,  // 40 Hz - Peak concentration
}

extension BrainwaveZoneExtension on BrainwaveZone {
  String get label {
    switch (this) {
      case BrainwaveZone.delta: return 'DELTA';
      case BrainwaveZone.theta: return 'THETA';
      case BrainwaveZone.alpha: return 'ALPHA';
      case BrainwaveZone.beta: return 'BETA';
      case BrainwaveZone.gamma: return 'GAMMA';
    }
  }

  String get subtitle {
    switch (this) {
      case BrainwaveZone.delta: return 'Deep Rest';
      case BrainwaveZone.theta: return 'Meditation';
      case BrainwaveZone.alpha: return 'Flow';
      case BrainwaveZone.beta: return 'Focus';
      case BrainwaveZone.gamma: return 'Peak';
    }
  }

  double get frequency {
    switch (this) {
      case BrainwaveZone.delta: return 2.0;
      case BrainwaveZone.theta: return 6.0;
      case BrainwaveZone.alpha: return 10.0;
      case BrainwaveZone.beta: return 20.0;
      case BrainwaveZone.gamma: return 40.0;
    }
  }

  Color get color {
    switch (this) {
      case BrainwaveZone.delta: return const Color(0xFF6366F1); // Indigo
      case BrainwaveZone.theta: return const Color(0xFF8B5CF6); // Purple
      case BrainwaveZone.alpha: return const Color(0xFF10B981); // Emerald
      case BrainwaveZone.beta: return const Color(0xFFF59E0B); // Amber
      case BrainwaveZone.gamma: return const Color(0xFFEF4444); // Red
    }
  }
}

/// Vertical slider for brainwave frequency control
/// Position: Bottom = Delta (2Hz), Top = Gamma (40Hz)
class BrainwaveSlider extends StatefulWidget {
  final double value; // 0.0 (Delta) to 1.0 (Gamma)
  final ValueChanged<double> onChanged;
  final bool enabled;

  const BrainwaveSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<BrainwaveSlider> createState() => _BrainwaveSliderState();
}

class _BrainwaveSliderState extends State<BrainwaveSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  BrainwaveZone get _currentZone {
    if (widget.value < 0.2) return BrainwaveZone.delta;
    if (widget.value < 0.4) return BrainwaveZone.theta;
    if (widget.value < 0.6) return BrainwaveZone.alpha;
    if (widget.value < 0.8) return BrainwaveZone.beta;
    return BrainwaveZone.gamma;
  }

  double get _frequency {
    // Interpolate frequency: 2Hz (0.0) to 40Hz (1.0)
    return 2.0 + (widget.value * 38.0);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.enabled,
      child: Opacity(
        opacity: widget.enabled ? 1.0 : 0.3,
        child: SizedBox(
          width: 80,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Track background
              Container(
                width: 4,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF6366F1), // Delta - Indigo
                      Color(0xFF8B5CF6), // Theta - Purple
                      Color(0xFF10B981), // Alpha - Emerald
                      Color(0xFFF59E0B), // Beta - Amber
                      Color(0xFFEF4444), // Gamma - Red
                    ],
                  ),
                ),
              ),

              // Zone markers (right side)
              Positioned(
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _zoneMarker(BrainwaveZone.gamma),
                    const SizedBox(height: 48),
                    _zoneMarker(BrainwaveZone.beta),
                    const SizedBox(height: 48),
                    _zoneMarker(BrainwaveZone.alpha),
                    const SizedBox(height: 48),
                    _zoneMarker(BrainwaveZone.theta),
                    const SizedBox(height: 48),
                    _zoneMarker(BrainwaveZone.delta),
                  ],
                ),
              ),

              // Gesture area
              GestureDetector(
                onVerticalDragUpdate: (details) {
                  final RenderBox box = context.findRenderObject() as RenderBox;
                  final localY = box.globalToLocal(details.globalPosition).dy;
                  // Invert: top = 1.0, bottom = 0.0
                  final normalized = 1.0 - (localY / box.size.height).clamp(0.0, 1.0);
                  
                  // Check for zone boundary crossing
                  final oldZone = _currentZone;
                  widget.onChanged(normalized);
                  
                  // Haptic on zone change would happen in parent
                },
                child: Container(
                  width: 60,
                  height: 280,
                  color: Colors.transparent,
                ),
              ),

              // Thumb (animated glow)
              Positioned(
                bottom: 10 + (widget.value * 260),
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      return Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentZone.color,
                          boxShadow: [
                            BoxShadow(
                              color: _currentZone.color.withOpacity(
                                  0.4 + (_glowController.value * 0.3)),
                              blurRadius: 16 + (_glowController.value * 8),
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Current frequency display (left side)
              Positioned(
                left: 0,
                bottom: 10 + (widget.value * 260) - 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_frequency.toStringAsFixed(0)}Hz',
                      style: TextStyle(
                        color: _currentZone.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoneMarker(BrainwaveZone zone) {
    final isActive = _currentZone == zone;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isActive ? 1.0 : 0.4,
      child: Text(
        zone.label[0], // Just first letter: D, T, A, B, G
        style: TextStyle(
          color: isActive ? zone.color : Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
