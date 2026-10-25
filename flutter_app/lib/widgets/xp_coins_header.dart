import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/gamification_provider.dart';
import '../services/gamification_service.dart';

/// Minimal XP & Coins display for the home screen header.
///
/// Shows: Level badge + XP progress bar + Coin count.
/// Follows the existing Zyndio dark-header design language.
class XpCoinsHeader extends ConsumerWidget {
  const XpCoinsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gState = ref.watch(gamificationProvider);

    return Row(
      children: [
        // ── Animated Spectral Orb ──
        AnimatedSpectralOrb(
          colors: gState.league.gradient,
          size: 28,
        ),

        const SizedBox(width: 8),

        // ── XP Progress Bar ──
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedCounter(
                        value: gState.xp,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        ' XP',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  height: 4,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: gState.leagueProgress),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(gState.league.color),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // ── Coins ──
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 1)),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                      ),
                    ),
                  ),
                  const Center(
                    child: Text('N', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 3),
            AnimatedCounter(
              value: gState.coins,
              style: const TextStyle(
                color: Color(0xFF60A5FA), // blue400
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A minimal toast that slides in when the user earns a reward.
/// Should be shown via an overlay or alert system.
class RewardToast extends StatelessWidget {
  final RewardEvent reward;

  const RewardToast({super.key, required this.reward});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: reward.leveledUp
              ? const Color(0xFFFBBF24).withOpacity(0.4)
              : const Color(0xFF34D399).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: reward.leveledUp
                    ? [const Color(0xFFFBBF24), const Color(0xFFF59E0B)]
                    : [const Color(0xFF34D399), const Color(0xFF059669)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              reward.leveledUp ? Icons.arrow_upward_rounded : Icons.bolt_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reward.leveledUp ? 'Level Up!' : reward.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '+${reward.xp} XP  •  +${reward.coins} N',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A more prominent, floating version of the XP/Coins display.
/// Designed to fit in the "Ask Intelligence" pill spot on the home screen.
class XpCoinsPill extends ConsumerStatefulWidget {
  const XpCoinsPill({super.key});

  @override
  ConsumerState<XpCoinsPill> createState() => _XpCoinsPillState();
}

class _XpCoinsPillState extends ConsumerState<XpCoinsPill> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.elasticIn)), weight: 70),
    ]).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gState = ref.watch(gamificationProvider);
    
    // Listen for rewards to trigger pulse
    ref.listen<RewardEvent?>(lastRewardEventProvider, (previous, next) {
      if (next != null && (previous == null || next.timestamp != previous.timestamp)) {
        _pulseController.forward(from: 0.0);
        HapticFeedback.mediumImpact();
      }
    });

    return ScaleTransition(
      scale: _scaleAnimation,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: _pulseController.isAnimating 
                    ? gState.league.color.withOpacity(0.5) 
                    : Colors.white.withOpacity(0.08), 
                width: 1.5,
              ),
              boxShadow: _pulseController.isAnimating ? [
                BoxShadow(
                  color: gState.league.color.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              ] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated Spectral Orb
                AnimatedSpectralOrb(
                  colors: gState.league.gradient,
                  size: 38,
                ),
                const SizedBox(width: 16),
                // XP & Tier
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      gState.league.displayName.toUpperCase(),
                      style: TextStyle(
                        color: gState.league.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedCounter(
                          value: gState.leagueXp,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          ' XP',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                // Circular Progress
                SizedBox(
                  width: 38, height: 38,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 3.5,
                        color: Colors.white.withOpacity(0.05),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: gState.leagueProgress),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return CircularProgressIndicator(
                            value: value,
                            strokeWidth: 3.5,
                            color: gState.league.color,
                            strokeCap: StrokeCap.round,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedCounter extends StatelessWidget {
  final int value;
  final TextStyle style;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value.toDouble(), end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutExpo,
      builder: (context, val, child) {
        return Text(
          val.toInt().toString(),
          style: style,
        );
      },
    );
  }
}

class CoinsPill extends ConsumerWidget {
  const CoinsPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gState = ref.watch(gamificationProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.8),
                    ),
                  ),
                ),
                const Center(
                  child: Text('N', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          AnimatedCounter(
            value: gState.coins,
            style: const TextStyle(
              color: Color(0xFF60A5FA),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedSpectralOrb extends StatefulWidget {
  final List<Color> colors;
  final double size;
  final bool isUnlocked;

  const AnimatedSpectralOrb({
    super.key,
    required this.colors,
    this.size = 100,
    this.isUnlocked = true,
  });

  @override
  State<AnimatedSpectralOrb> createState() => _AnimatedSpectralOrbState();
}

class _AnimatedSpectralOrbState extends State<AnimatedSpectralOrb> with TickerProviderStateMixin {
  AnimationController? _rotationController;
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController?.dispose();
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isUnlocked || _rotationController == null || _pulseController == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Ghostly Shell
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.02),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
            // Faint Static Nebula (Desaturated)
            Center(
              child: Container(
                width: widget.size * 0.6,
                height: widget.size * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final rotationController = _rotationController!;
    final pulseController = _pulseController!;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // ── Depth Layer 0: Ambient Glow ──
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.colors[0].withOpacity(0.2 + (pulseController.value * 0.15)),
                      blurRadius: widget.size * 0.7,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              );
            },
          ),
          
          // ── Depth Layer 1: The Nebula Core ──
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: ClipOval(
              child: AnimatedBuilder(
                animation: rotationController,
                builder: (context, child) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Energy Pocket A
                      Positioned.fill(
                        child: Transform.translate(
                          offset: Offset(
                            widget.size * 0.3 * math.cos(rotationController.value * 2 * math.pi),
                            widget.size * 0.3 * math.sin(rotationController.value * 2 * math.pi),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [widget.colors[0].withOpacity(1.0), Colors.transparent],
                                radius: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Energy Pocket B
                      Positioned.fill(
                        child: Transform.translate(
                          offset: Offset(
                            widget.size * 0.3 * math.cos((rotationController.value + 0.5) * 2 * math.pi),
                            widget.size * 0.3 * math.sin((rotationController.value + 0.5) * 2 * math.pi),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [widget.colors[1].withOpacity(1.0), Colors.transparent],
                                radius: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Energy Pocket C (Center Glow)
                      if (widget.colors.length > 2)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [widget.colors[2].withOpacity(0.5), Colors.transparent],
                                radius: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── Depth Layer 2: Frosted Refraction ──
          Positioned.fill(
            child: ClipOval(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: widget.size * 0.06, sigmaY: widget.size * 0.06),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(0.2, 0.2),
                      radius: 1.2,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.black.withOpacity(0.4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Depth Layer 3: Glass Shell & Highlights ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.4),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.5),
                    Colors.white.withOpacity(0.0),
                    Colors.black.withOpacity(0.3),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          
          // Specular Glint (Top Left)
          Positioned(
            top: widget.size * 0.1,
            left: widget.size * 0.1,
            child: Container(
              width: widget.size * 0.4,
              height: widget.size * 0.3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

