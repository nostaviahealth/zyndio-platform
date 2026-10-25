import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../providers/activity_meter_provider.dart';
import '../../../services/activity_meter_service.dart';
import '../../../widgets/ask_intelligence_button.dart';
import '../../wearables/widgets/dashboard_card_style.dart';

/// Premium Activity Meter card for the Intelligence screen.
/// Displays a semi-circular gauge showing the user's sedentary/activity level,
/// color-coded zone label, risk warnings, praise messages, and recommendations.
class ActivityMeterCard extends ConsumerStatefulWidget {
  const ActivityMeterCard({super.key});

  @override
  ConsumerState<ActivityMeterCard> createState() => _ActivityMeterCardState();
}

class _ActivityMeterCardState extends ConsumerState<ActivityMeterCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _needleController;
  late Animation<double> _needleAnimation;
  double _previousScore = 0;

  @override
  void initState() {
    super.initState();
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _needleAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _needleController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    if (!mounted || _needleController.isAnimating) return;
    if ((_previousScore - target).abs() < 0.5 && _previousScore != 0) return;
    
    _needleAnimation = Tween<double>(
      begin: _previousScore,
      end: target,
    ).animate(
      CurvedAnimation(parent: _needleController, curve: Curves.easeOutCubic),
    );
    
    try {
      _needleController
        ..reset()
        ..forward();
      _previousScore = target;
    } catch (e) {
      // Handle potential disposal race conditions
    }
  }

  @override
  Widget build(BuildContext context) {
    final meter = ref.watch(activityMeterProvider);

    // Use ref.listen to trigger animation when score changes
    ref.listen(activityMeterProvider.select((s) => s.score), (previous, next) {
      if (mounted) {
        _animateTo(next.toDouble());
      }
    });

    if (!meter.hasData) {
      return _buildEmptyState(context);
    }

    // Initialize previousScore on first load with data
    if (_previousScore == 0 && meter.score > 0) {
      _previousScore = meter.score.toDouble();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(meter.score.toDouble());
      });
    }

    final zone = meter.zone;
    final Color zoneColor = ActivityMeterService.getZoneColor(zone);
    final String zoneLabel = ActivityMeterService.getZoneLabel(zone);

    return Container(
      width: double.infinity,
      decoration: DashboardCardStyle.decorationOf(context),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: zoneColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Activity Meter',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.nc.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: zoneColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    zoneLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: zoneColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Text(
              'Movement & metabolic engagement tracking',
              style: TextStyle(
                fontSize: 13,
                color: context.nc.textTertiary,
              ),
            ),

            const SizedBox(height: 24),

            // ── Gauge ──
            Center(
              child: SizedBox(
                width: 200,
                height: 120,
                child: AnimatedBuilder(
                  animation: _needleAnimation,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _GaugePainter(
                        score: _needleAnimation.value,
                        zoneColor: zoneColor,
                        trackColor: context.nc.inputFill,
                        cardSurface: context.nc.cardSurface,
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Score number
                            Text(
                              _needleAnimation.value.round().toString(),
                              style: TextStyle(
                                fontSize: 52, // Slightly larger
                                fontWeight: FontWeight.w900,
                                color: context.nc.textPrimary,
                                height: 1.0,
                                letterSpacing: -2.0,
                              ),
                            ),
                            Text(
                              'SCORE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: context.nc.textTertiary,
                                letterSpacing: 1.5, // More air
                              ),
                            ),
                            const SizedBox(height: 2), // Moved lower to match original look
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Praise message ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.nc.inputFill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.nc.cardBorder),
              ),
              child: Text(
                meter.praiseMessage,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.nc.textSecondary,
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Risk & Recommendation Info ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                   Text(
                    meter.riskMessage,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: context.nc.textTertiary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    meter.recommendation,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.nc.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Ask AI button ──
            SizedBox(
              width: double.infinity,
              child: AskIntelligenceButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.pushNamed('chat', queryParameters: {
                    'initialMessage':
                        'My Activity Meter score is ${meter.score}/100 (${zoneLabel}). '
                            'Explain what this means for my health and suggest ways to improve my activity levels based on my current data.',
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.nc.divider,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Activity Meter',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: context.nc.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Locked gauge placeholder
          Center(
            child: SizedBox(
              width: 180,
              height: 100,
              child: CustomPaint(
                painter: _GaugePainter(
                  score: 0,
                  zoneColor: context.nc.divider,
                  trackColor: context.nc.inputFill,
                  cardSurface: context.nc.cardSurface,
                  isLocked: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: Column(
              children: [
                Text(
                  'Connect Wearable to Unlock',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.nc.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Track your movement patterns and get personalised insights on your sedentary risk.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.nc.textSecondary,
                    height: 1.4,
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

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter — Semi-circular gauge with gradient arc + needle
// ─────────────────────────────────────────────────────────────────────────────

class _GaugePainter extends CustomPainter {
  final double score;
  final Color zoneColor;
  final Color trackColor;
  final Color cardSurface;
  final bool isLocked;

  _GaugePainter({
    required this.score,
    required this.zoneColor,
    required this.trackColor,
    required this.cardSurface,
    this.isLocked = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 8;
    const startAngle = math.pi; // 180° (left)
    const sweepAngle = math.pi; // 180° arc

    // ── Background track ──
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0 // Thinner
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    if (isLocked) return;

    // ── Gradient fill arc ──
    final double fraction = (score / 100.0).clamp(0.01, 1.0);
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0 // Slightly thicker than track
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: const [
          Color(0xFFEF4444), // Red
          Color(0xFFF97316), // Orange
          Color(0xFFF59E0B), // Amber
          Color(0xFF84CC16), // Yellow-Green
          Color(0xFF22C55E), // Green
          Color(0xFF10B981), // Emerald
        ],
        stops: const [0.0, 0.2, 0.35, 0.55, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * fraction,
      false,
      gradientPaint,
    );

    // ── Glowing Indicator Orb (Minimal replacement for needle) ──
    final currentAngle = startAngle + sweepAngle * fraction;
    final orbPos = Offset(
      center.dx + radius * math.cos(currentAngle),
      center.dy + radius * math.sin(currentAngle),
    );

    // Draw orb glow
    final glowPaint = Paint()
      ..color = zoneColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(orbPos, 10, glowPaint);

    // Draw orb center
    final orbPaint = Paint()
      ..color = cardSurface
      ..style = PaintingStyle.fill;
    
    final orbBorderPaint = Paint()
      ..color = zoneColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(orbPos, 6, orbPaint);
    canvas.drawCircle(orbPos, 6, orbBorderPaint);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.score != score || old.zoneColor != zoneColor;
}

