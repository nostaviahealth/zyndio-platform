import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';
import '../providers/wearable_sync_provider.dart';
import '../providers/lab_reports_provider.dart';
import '../screens/performance/performance_detail_screen.dart';

class PerformanceModuleCard extends ConsumerWidget {
  const PerformanceModuleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(wearableSyncProvider).value;
    final wearable = syncState?.snapshot;
    final labReports = ref.watch(labReportsProvider).value;

    if (wearable == null || syncState == null) return const SizedBox.shrink();

    // ── 1. Extract Biometrics ──
    final double currentHrv = wearable.hrv?.toDouble() ?? 52.0;
    final double currentRhr = wearable.rhr?.toDouble() ?? 64.0;
    final double sleepHours = wearable.sleepHours;
    final double sleepEfficiency = wearable.sleepEfficiency;
    final int recoveryScore = wearable.recoveryScore;
    final double hrvBaseline = wearable.hrvBaseline?.toDouble() ?? 52.0;
    final DateTime now = DateTime.now();

    // ── 2. Performance Readiness Score Calculation (Clinical-Grade) ──

    // Sleep Component (30%)
    double sleepScore = (sleepEfficiency * 0.6 +
            (sleepHours / 8.0).clamp(0.0, 1.0) * 0.4) *
        30;

    // Autonomic Component (35%)
    double hrvRatio = (currentHrv / 100.0).clamp(0.0, 1.0);
    double rhrGoodness = ((100 - currentRhr) / 100.0).clamp(0.0, 1.0);
    double autonomicScore = (hrvRatio * 0.65 + rhrGoodness * 0.35) * 35;

    // Circadian Alignment (15%)
    double circadianScore = _getCircadianAlignment(now.hour) * 15;

    // Cognitive Readiness (20%)
    double cognitiveScore =
        ((recoveryScore / 100.0) * 0.5 + hrvRatio * 0.5) * 20;

    int performanceReadiness =
        (sleepScore + autonomicScore + circadianScore + cognitiveScore)
            .clamp(0, 100)
            .round();

    // ── 3. Status Classification ──
    String statusText;
    Color statusColor;
    if (performanceReadiness >= 80) {
      statusText = 'Optimal';
      statusColor = const Color(0xFF10B981);
    } else if (performanceReadiness >= 60) {
      statusText = 'Moderate';
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusText = 'Low';
      statusColor = const Color(0xFFEF4444);
    }

    // ── 4. Focus / Energy / Reaction Classification ──
    String focusStatus = _classifyFocus(currentHrv, hrvBaseline);
    String energyStatus =
        _classifyEnergy(wearable.sleepScore.toDouble(), recoveryScore.toDouble());
    String reactionStatus = _classifyReaction(now.hour, currentHrv, hrvBaseline);

    // ── 5. Narrative ──
    String narrativeBold;
    String narrativeDim;
    if (performanceReadiness >= 80) {
      narrativeBold = "You're in a high performance window.";
      narrativeDim =
          'Focus, energy, and reaction time are all operating at peak levels.';
    } else if (performanceReadiness >= 60) {
      narrativeBold = 'Moderate readiness detected.';
      narrativeDim =
          'Some subsystems are below baseline. Hydration and light movement may optimize output.';
    } else {
      narrativeBold = 'Performance capacity is currently reduced.';
      narrativeDim =
          'Recovery and sleep metrics suggest postponing demanding cognitive or physical tasks.';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutQuart,
      builder: (context, animValue, child) {
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => PerformanceDetailScreen(
                  syncState: syncState,
                  labReports: labReports ?? [],
                  performanceReadiness: performanceReadiness,
                  statusText: statusText,
                  statusColor: statusColor,
                  focusStatus: focusStatus,
                  energyStatus: energyStatus,
                  reactionStatus: reactionStatus,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            height: 480,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1D4ED8), Color(0xFF030712)],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: context.nc.isDark ? 20 : 0,
                  sigmaY: context.nc.isDark ? 20 : 0,
                ),
                child: Stack(
                  clipBehavior: Clip.antiAlias,
                  children: [
                    // Top Radial Glow
                    Positioned(
                      top: -50,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 300,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF3B82F6).withOpacity(0.15),
                              const Color(0xFF3B82F6).withOpacity(0),
                            ],
                            center: Alignment.topCenter,
                            radius: 1.0,
                          ),
                        ),
                      ),
                    ),

                    // Top-right Chevron navigation
                    Positioned(
                      top: 24,
                      right: 24,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => PerformanceDetailScreen(
                                syncState: syncState,
                                labReports: labReports ?? [],
                                performanceReadiness: performanceReadiness,
                                statusText: statusText,
                                statusColor: statusColor,
                                focusStatus: focusStatus,
                                energyStatus: energyStatus,
                                reactionStatus: reactionStatus,
                              ),
                            ),
                          );
                        },
                        child: Icon(
                          LucideIcons.chevronRight,
                          size: 20,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ),

                    // Core Content
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 24, right: 24, top: 24, bottom: 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // -- Header Title --
                          Text(
                            'PERFORMANCE INTELLIGENCE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 1,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.15),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // -- Subtitle --
                          Text(
                            'Performance Readiness',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // -- Hero Score Row --
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$performanceReadiness%',
                                style: const TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.0,
                                  letterSpacing: -1,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.08)),
                                ),
                                child: Text(
                                  statusText,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // -- Circadian Wave Chart --
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.04)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: CustomPaint(
                                painter: PerformanceCircadianWavePainter(
                                  currentHour: now.hour + now.minute / 60.0,
                                  animValue: animValue,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // -- Dynamic Narrative --
                          Text(
                            narrativeBold,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            narrativeDim,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // -- Bottom Stats Panel --
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildPillMetric('FOCUS', focusStatus,
                                    focusStatus == 'High' || focusStatus == 'Optimal'),
                                Container(
                                    width: 1,
                                    height: 24,
                                    color: Colors.white.withOpacity(0.08)),
                                _buildPillMetric('ENERGY', energyStatus,
                                    energyStatus == 'High' || energyStatus == 'Optimal'),
                                Container(
                                    width: 1,
                                    height: 24,
                                    color: Colors.white.withOpacity(0.08)),
                                _buildPillMetric('REACTION', reactionStatus,
                                    reactionStatus == 'Optimal' || reactionStatus == 'High'),
                              ],
                            ),
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
      },
    );
  }

  // ── Circadian Alignment Score ──
  double _getCircadianAlignment(int hour) {
    // Peak performance: 8-11 AM, 4-7 PM
    // Slump: 1-3 PM
    // Low: late night
    if (hour >= 8 && hour <= 11) return 0.95;
    if (hour >= 16 && hour <= 19) return 0.85;
    if (hour >= 6 && hour < 8) return 0.65;
    if (hour >= 12 && hour < 13) return 0.75;
    if (hour >= 13 && hour <= 15) return 0.45;
    if (hour >= 20 && hour <= 22) return 0.50;
    if (hour >= 23 || hour < 6) return 0.20;
    return 0.60;
  }

  // ── Focus Classification ──
  String _classifyFocus(double currentHrv, double hrvBaseline) {
    if (hrvBaseline <= 0) return 'Moderate';
    if (currentHrv >= hrvBaseline * 0.9) return 'High';
    if (currentHrv >= hrvBaseline * 0.75) return 'Moderate';
    return 'Low';
  }

  // ── Energy Classification ──
  String _classifyEnergy(double sleepScoreVal, double recoveryScoreVal) {
    if (sleepScoreVal >= 70 && recoveryScoreVal >= 60) return 'High';
    if (sleepScoreVal >= 50 || recoveryScoreVal >= 40) return 'Moderate';
    return 'Low';
  }

  // ── Reaction Classification ──
  String _classifyReaction(int hour, double currentHrv, double hrvBaseline) {
    bool goodCircadian =
        (hour >= 8 && hour <= 11) || (hour >= 16 && hour <= 19);
    bool goodHrv = hrvBaseline > 0 && currentHrv >= hrvBaseline * 0.85;
    if (goodCircadian && goodHrv) return 'Optimal';
    if (goodCircadian || goodHrv) return 'Moderate';
    return 'Low';
  }

  Widget _buildPillMetric(String label, String value, bool isOptimal) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.4),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isOptimal ? Icons.check_circle_rounded : Icons.info_rounded,
              size: 11,
              color: isOptimal
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
          ],
        ),
      ],
    );
  }
}

/// A premium 24-hour circadian alertness wave painter (Process C).
/// Renders a neon-blue curve with glow effects, gridlines, current-time marker,
/// and annotated scan nodes at peak / slump / rebound positions.
class PerformanceCircadianWavePainter extends CustomPainter {
  final double currentHour;
  final double animValue;

  PerformanceCircadianWavePainter({
    required this.currentHour,
    required this.animValue,
  });

  // Normalized 0-1 alertness control points across 24 hours
  static const List<double> _alertnessHours = [
    0, 3, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24
  ];
  static const List<double> _alertnessValues = [
    0.15, 0.08, 0.35, 0.75, 0.92, 0.85, 0.55, 0.65, 0.80, 0.60, 0.30, 0.15
  ];

  double _alertnessAt(double hour) {
    if (hour <= 0) return _alertnessValues.first;
    if (hour >= 24) return _alertnessValues.last;
    for (int i = 0; i < _alertnessHours.length - 1; i++) {
      if (hour >= _alertnessHours[i] && hour <= _alertnessHours[i + 1]) {
        double t =
            (hour - _alertnessHours[i]) / (_alertnessHours[i + 1] - _alertnessHours[i]);
        // Smooth cubic interpolation
        t = t * t * (3 - 2 * t);
        return _alertnessValues[i] +
            (_alertnessValues[i + 1] - _alertnessValues[i]) * t;
      }
    }
    return _alertnessValues.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double leftPad = 24.0;
    final double rightPad = 24.0;
    final double topPad = 32.0;
    final double bottomPad = 24.0;
    final double chartWidth = size.width - leftPad - rightPad;
    final double chartHeight = size.height - topPad - bottomPad;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // ── 1. Subtle horizontal gridlines ──
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;

    for (double frac in [0.25, 0.50, 0.75]) {
      double y = topPad + chartHeight * (1.0 - frac);
      canvas.drawLine(
          Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
    }

    // ── 2. Build the main curve path ──
    const int segments = 200;
    final List<Offset> curvePoints = [];
    for (int i = 0; i <= segments; i++) {
      double hour = (i / segments) * 24.0;
      double alertness = _alertnessAt(hour) * animValue;
      double x = leftPad + (hour / 24.0) * chartWidth;
      double y = topPad + chartHeight * (1.0 - alertness);
      curvePoints.add(Offset(x, y));
    }

    final curvePath = Path()..moveTo(curvePoints[0].dx, curvePoints[0].dy);
    for (int i = 0; i < curvePoints.length - 1; i++) {
      final p0 = curvePoints[i];
      final p1 = curvePoints[i + 1];
      curvePath.cubicTo(
        (p0.dx + p1.dx) / 2, p0.dy,
        (p0.dx + p1.dx) / 2, p1.dy,
        p1.dx, p1.dy,
      );
    }

    // ── 3. Glowing area fill below curve ──
    final fillPath = Path.from(curvePath)
      ..lineTo(curvePoints.last.dx, topPad + chartHeight)
      ..lineTo(curvePoints.first.dx, topPad + chartHeight)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, topPad),
          Offset(0, topPad + chartHeight),
          [
            const Color(0xFF3B82F6).withOpacity(0.12),
            Colors.transparent,
          ],
        ),
    );

    // ── 4. Main curve line with neon blur effect ──
    // Outer glow
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = const Color(0xFF3B82F6).withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Inner bright line
    canvas.drawPath(
      curvePath,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round,
    );

    // ── 5. Vertical dashed line at current hour + glowing dot ──
    double currentX = leftPad + (currentHour / 24.0) * chartWidth;
    double currentAlertness = _alertnessAt(currentHour) * animValue;
    double currentY = topPad + chartHeight * (1.0 - currentAlertness);

    // Dashed vertical line
    final dashPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 1.0;
    double dashY = topPad;
    while (dashY < topPad + chartHeight) {
      canvas.drawLine(
        Offset(currentX, dashY),
        Offset(currentX, math.min(dashY + 3, topPad + chartHeight)),
        dashPaint,
      );
      dashY += 6;
    }

    // Glowing dot at intersection
    canvas.drawCircle(
      Offset(currentX, currentY),
      6 * animValue,
      Paint()..color = const Color(0xFF3B82F6).withOpacity(0.3),
    );
    canvas.drawCircle(
      Offset(currentX, currentY),
      3 * animValue,
      Paint()..color = Colors.white,
    );

    // ── 6. X-axis labels ──
    final xLabels = ['12 AM', '6 AM', '12 PM', '6 PM', '12 AM'];
    for (int i = 0; i < xLabels.length; i++) {
      double progress = i / (xLabels.length - 1);
      double x = leftPad + progress * chartWidth;
      textPainter.text = TextSpan(
        text: xLabels[i],
        style: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, topPad + chartHeight + 6),
      );
    }

    // ── 7. Scan node dots at peak, slump, and rebound ──
    final scanNodes = <_ScanNode>[
      _ScanNode(hour: 10, label: 'PEAK', color: const Color(0xFF10B981)),
      _ScanNode(hour: 14, label: 'SLUMP', color: const Color(0xFFF59E0B)),
      _ScanNode(hour: 18, label: 'REBOUND', color: const Color(0xFF3B82F6)),
    ];

    for (int i = 0; i < scanNodes.length; i++) {
      final node = scanNodes[i];
      double nx = leftPad + (node.hour / 24.0) * chartWidth;
      double nAlertness = _alertnessAt(node.hour.toDouble()) * animValue;
      double ny = topPad + chartHeight * (1.0 - nAlertness);
      Offset pt = Offset(nx, ny);

      // Glow dot
      canvas.drawCircle(
          pt, 5 * animValue, Paint()..color = node.color.withOpacity(0.35));
      canvas.drawCircle(pt, 2 * animValue, Paint()..color = Colors.white);

      // Label
      textPainter.text = TextSpan(
        text: node.label,
        style: TextStyle(
          color: node.color,
          fontSize: 6.8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      );
      textPainter.layout();

      // Alternating stems: UP for first and third, DOWN for second
      double stemHeight = (i == 1) ? 22.0 : -22.0;
      Offset labelCenter = Offset(pt.dx, pt.dy + stemHeight);

      // Stem line
      final stemPaint = Paint()
        ..color = node.color.withOpacity(0.35)
        ..strokeWidth = 1.0;
      canvas.drawLine(pt, labelCenter, stemPaint);

      // Connector bead
      canvas.drawCircle(labelCenter, 1.5, Paint()..color = node.color);

      // Glassmorphic capsule
      double cWidth = textPainter.width + 16;
      double cHeight = textPainter.height + 6;
      double rx = labelCenter.dx - cWidth / 2;
      double ry = labelCenter.dy - cHeight / 2;

      final capsuleRRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(rx, ry, cWidth, cHeight),
        const Radius.circular(100),
      );

      canvas.drawRRect(
        capsuleRRect,
        Paint()
          ..color = Colors.black.withOpacity(0.55)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        capsuleRRect,
        Paint()
          ..color = node.color.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      textPainter.paint(
        canvas,
        Offset(
          labelCenter.dx - textPainter.width / 2,
          labelCenter.dy - textPainter.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PerformanceCircadianWavePainter oldDelegate) =>
      oldDelegate.currentHour != currentHour ||
      oldDelegate.animValue != animValue;
}

class _ScanNode {
  final int hour;
  final String label;
  final Color color;

  const _ScanNode({
    required this.hour,
    required this.label,
    required this.color,
  });
}
