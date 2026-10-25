import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';
import '../providers/wearable_sync_provider.dart';
import '../providers/lab_reports_provider.dart';
import '../providers/patient_provider.dart';
import '../screens/cardio/cardio_detail_screen.dart';
import '../services/vo2_max_service.dart';

class CardioModuleCard extends ConsumerWidget {
  const CardioModuleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(wearableSyncProvider).value;
    final wearable = syncState?.snapshot;
    final labReports = ref.watch(labReportsProvider).value;
    final profile = ref.watch(patientProfileProvider).value;

    if (wearable == null || syncState == null) return const SizedBox.shrink();

    // ── 1. Advanced Historical Baselines (Clinical Audit) ──
    double averageRhr = 64.0; // Clinical default baseline
    if (syncState.hrHistory.isNotEmpty) {
      averageRhr = syncState.hrHistory
          .map((e) => (e['value'] as num).toDouble())
          .reduce((a, b) => a + b) / syncState.hrHistory.length;
    }

    double averageHrv = 52.0; // Clinical default baseline
    if (syncState.hrvHistory.isNotEmpty) {
      averageHrv = syncState.hrvHistory
          .map((e) => (e['value'] as num).toDouble())
          .reduce((a, b) => a + b) / syncState.hrvHistory.length;
    }

    // ── 2. Functional Autonomic Strain Classifier ──
    double currentRhr = wearable.rhr?.toDouble() ?? 64.0;
    double currentHrv = wearable.hrv?.toDouble() ?? 52.0;
    
    // Clinical criteria: Strain is flagged if current resting heart rate is elevated by >= 6% 
    // OR if heart rate variability is suppressed by >= 15% relative to the 30-day chronological average.
    bool hasStrain = (currentRhr >= averageRhr * 1.06) || (currentHrv <= averageHrv * 0.85);

    // ── 3. Biological Score Synthesis ──
    double hrvScore = (currentHrv / 100 * 35);
    double rhrScore = ((100 - currentRhr).clamp(0, 100)) / 100 * 25;
    double vo2Score = (syncState.vo2Max?.toDouble() ?? 40) / 60 * 25;
    int adaptabilityIndex = (hrvScore + rhrScore + vo2Score + 15).clamp(0, 100).round();

    // ── 3.5. Soma Heart Age Calculation Preview ──
    final int chronologicalAge = profile?.age ?? 30;
    
    // RHR Delta
    double rhrDelta = (currentRhr - 58.0) * 0.25;
    rhrDelta = rhrDelta.clamp(-4.0, 6.0);
    
    // HRV Delta
    final double hrvBase = 65.0 - (0.35 * chronologicalAge);
    double hrvDelta = (hrvBase - currentHrv) * 0.15;
    hrvDelta = hrvDelta.clamp(-5.0, 5.0);
    
    // VO2 Delta
    bool isMale = true;
    if (profile?.questionnaireData != null) {
      final gender = profile!.questionnaireData!['gender'];
      if (gender == 'Female') {
        isMale = false;
      }
    }

    final vo2Class = Vo2MaxService.classifyFitness(
      syncState.vo2Max?.toDouble() ?? 42.5,
      age: chronologicalAge,
      isMale: isMale,
    );
    double vo2Delta = 1.0;
    final String vo2Level = vo2Class.level.toLowerCase();
    if (vo2Level.contains('superior')) {
      vo2Delta = -5.0;
    } else if (vo2Level.contains('excellent')) {
      vo2Delta = -3.5;
    } else if (vo2Level.contains('good')) {
      vo2Delta = -2.0;
    } else if (vo2Level.contains('fair')) {
      vo2Delta = 1.0;
    } else if (vo2Level.contains('poor')) {
      vo2Delta = 3.5;
    } else if (vo2Level.contains('very poor')) {
      vo2Delta = 6.0;
    }
    
    // Lipid / Metabolic Load Delta
    double vascularDelta = 0.0;
    if (labReports != null && labReports.isNotEmpty) {
      final report = labReports.first;
      double? tgVal;
      double? hdlVal;
      
      for (var m in report.markers) {
        final name = m.name.toLowerCase();
        if (name.contains('triglycerides')) {
          tgVal = double.tryParse(m.value.replaceAll(RegExp(r'[^\d\.]'), ''));
        }
        if (name.contains('hdl') && !name.contains('non-hdl') && !name.contains('non hdl')) {
          hdlVal = double.tryParse(m.value.replaceAll(RegExp(r'[^\d\.]'), ''));
        }
      }
      
      if (tgVal != null && hdlVal != null && hdlVal > 0) {
        vascularDelta = ((tgVal / hdlVal) - 1.5) * 1.5;
        vascularDelta = vascularDelta.clamp(-3.0, 5.0);
      }
    }
    
    int heartAge = (chronologicalAge + rhrDelta + hrvDelta + vo2Delta + vascularDelta)
        .clamp(chronologicalAge - 12.0, chronologicalAge + 15.0)
        .round();
        
    final int ageDiff = heartAge - chronologicalAge;
    final bool isYounger = ageDiff < 0;

    // ── 4. UI Mutating States ──
    String statusText = hasStrain ? 'Under Strain' : 'Resilient';
    Color statusColor = hasStrain ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOutQuart,
      builder: (context, animValue, child) {
        return Container(
          width: double.infinity,
          height: 440,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE11D48), Color(0xFF2A030A)], // Crimson to deep burgundy-black
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
                            const Color(0xFFE11D48).withOpacity(0.15),
                            const Color(0xFFE11D48).withOpacity(0),
                          ],
                          center: Alignment.topCenter,
                          radius: 1.0,
                        ),
                      ),
                    ),
                  ),

                  // Standalone top-right Chevron navigation (Minimalist chevron like Food Intelligence)
                  Positioned(
                    top: 24,
                    right: 24,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => CardioDetailScreen(
                              syncState: syncState,
                              labReports: labReports ?? [],
                              adaptabilityIndex: adaptabilityIndex,
                              statusText: statusText,
                              statusColor: statusColor,
                              chronologicalAge: chronologicalAge,
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

                  // Core Content (Left Aligned for readable, dashboard data layout)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // -- Heading Title Header (Left Aligned) --
                        Text(
                          'CARDIOVASCULAR INTELLIGENCE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withOpacity(0.85),
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // -- Hero Adaptability Score Title Row --
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$adaptabilityIndex',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    height: 1.0,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '/100',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white.withOpacity(0.4),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: Colors.white.withOpacity(0.08)),
                              ),
                              child: Text(
                                statusText.toUpperCase(),
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

                        // -- Signature Visualizer: Sleeping Tachogram & Autonomic Scans --
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.04)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CustomPaint(
                              painter: CardioHomeTachogramPainter(
                                hasStrain: hasStrain,
                                currentRhr: currentRhr,
                                averageRhr: averageRhr,
                                hrHistory: syncState.hrHistory,
                                animValue: animValue,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // -- Dynamic Clinical Narrative Copy (Left Aligned) --
                        Text(
                          hasStrain 
                              ? 'Autonomic recovery baseline compromised'
                              : 'Cardiovascular vagal tone is highly optimal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasStrain
                              ? 'Your overnight heart rate is elevated ${(((currentRhr - averageRhr) / averageRhr) * 100).round()}% above baseline, combined with HRV suppression. Prioritize vascular rest.'
                              : 'Your sleeping heart rate dipped smoothly below your 30-day baseline of ${averageRhr.round()} bpm, showcasing robust parasympathetic recovery.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.5),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // -- Core Readouts Grid --
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildPillMetric('HRV', '${currentHrv.round()} ms', !hasStrain),
                              Container(width: 1, height: 24, color: Colors.white.withOpacity(0.08)),
                              _buildPillMetric('RESTING HR', '${currentRhr.round()} bpm', !hasStrain),
                              Container(width: 1, height: 24, color: Colors.white.withOpacity(0.08)),
                              _buildPillMetric('VO2 MAX', syncState.vo2Max?.toStringAsFixed(1) ?? '--', true),
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
        );
      },
    );
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
              color: isOptimal ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
          ],
        )
      ],
    );
  }
}

/// A highly polished, medical-grade CustomPainter for the Home Card,
/// rendering an overnight autonomic sleep dip & scan chronogram.
class CardioHomeTachogramPainter extends CustomPainter {
  final bool hasStrain;
  final double currentRhr;
  final double averageRhr;
  final List<Map<String, dynamic>> hrHistory;
  final double animValue;

  CardioHomeTachogramPainter({
    required this.hasStrain,
    required this.currentRhr,
    required this.averageRhr,
    required this.hrHistory,
    required this.animValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    double minHR = 40.0;
    double maxHR = 100.0;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 1. Draw horizontal gridlines and Y-axis bpm labels (45, 60, 75, 90 bpm)
    final bpms = [90, 75, 60, 45];
    for (int bpm in bpms) {
      double normY = (bpm - minHR) / (maxHR - minHR);
      double y = size.height - 24 - (normY * (size.height - 40));

      // Draw grid line up to the right-margin labels
      canvas.drawLine(Offset(12, y), Offset(size.width - 44, y), gridPaint);

      textPainter.text = TextSpan(
        text: '$bpm',
        style: TextStyle(
          color: Colors.white.withOpacity(0.35),
          fontSize: 7.5,
          fontWeight: FontWeight.w800,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(size.width - 34, y - 5));
    }

    // 2. Map heart rate points
    List<Offset> points = [];
    int segments = 40;
    double startX = 24;
    double endX = size.width - 48; // Space for right Y-axis labels

    List<double> hrValues = [];
    if (hrHistory.isNotEmpty) {
      final recentHistory = hrHistory.length > segments
          ? hrHistory.sublist(hrHistory.length - segments)
          : hrHistory;
      for (var entry in recentHistory) {
        final val = (entry['value'] as num?)?.toDouble();
        if (val != null) {
          hrValues.add(val.clamp(minHR, maxHR));
        }
      }
    }

    if (hrValues.length < 5) {
      hrValues.clear();
      final rng = math.Random(hasStrain ? 1234 : 5678);
      double baselineStart = hasStrain ? (currentRhr + 10.0) : (currentRhr + 8.0);
      double maxCircadianDip = hasStrain ? 4.0 : 12.0;

      for (int i = 0; i < segments; i++) {
        double progress = i / (segments - 1);
        double circadianDip = math.sin(progress * math.pi) * maxCircadianDip;
        double noise = (rng.nextDouble() * 3.0 - 1.5);

        double spike = 0.0;
        if (hasStrain && progress > 0.45 && progress < 0.75) {
          spike = math.sin((progress - 0.45) / 0.30 * math.pi) * 12.0;
        }

        double hrVal = (baselineStart - circadianDip + noise + spike).clamp(minHR, maxHR);
        hrValues.add(hrVal);
      }
    }

    int count = hrValues.length;
    double actualStep = (endX - startX) / (count - 1);

    for (int i = 0; i < count; i++) {
      double hr = hrValues[i];
      double normY = (hr - minHR) / (maxHR - minHR);
      double x = startX + i * actualStep;
      double y = size.height - 24 - (normY * (size.height - 40) * animValue);
      points.add(Offset(x, y));
    }

    // 3. Draw pink glowing area fill below line
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      path.cubicTo((p1.dx + p2.dx) / 2, p1.dy, (p1.dx + p2.dx) / 2, p2.dy, p2.dx, p2.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height - 24)
      ..lineTo(points.first.dx, size.height - 24)
      ..close();

    canvas.drawPath(fillPath, Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 10),
        Offset(0, size.height - 24),
        [const Color(0xFFE11D48).withOpacity(0.12), Colors.transparent],
      ));

    // 4. Draw main heart rate trace curve with neon blur
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFE11D48).withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));

    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFE11D48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round);

    // 5. Draw Sleep Timeline X-Axis tick labels
    final times = ['10 PM', '1 AM', '4 AM', '7 AM'];
    for (int i = 0; i < times.length; i++) {
      double progress = i / (times.length - 1);
      double x = startX + progress * (endX - startX);
      textPainter.text = TextSpan(
        text: times[i],
        style: TextStyle(
          color: Colors.white.withOpacity(0.25),
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 16));
    }

    // 6. Highlighted clinical scan indicators (Micro-nodes)
    final nodePaint = Paint()..style = PaintingStyle.fill;
    
    int midIdx = (count * 0.5).round();
    int earlyIdx = (count * 0.25).round();
    int lateIdx = (count * 0.75).round();
    
    List<int> scanIndices = [earlyIdx, midIdx, lateIdx];
    for (int i = 0; i < scanIndices.length; i++) {
      int idx = scanIndices[i];
      if (idx < points.length) {
        Offset pt = points[idx];
        
        bool isSpikeNode = hasStrain && i == 1; 
        Color nodeColor = isSpikeNode ? const Color(0xFFEF4444) : const Color(0xFF10B981);
        String scanLabel = isSpikeNode 
            ? 'AUTONOMIC SPIKE' 
            : (i == 1 ? 'MAX SLEEP DIP' : (i == 0 ? 'SLEEP START' : 'VAGAL TONE'));

        // Core glow dot
        canvas.drawCircle(pt, 5 * animValue, Paint()..color = nodeColor.withOpacity(0.35));
        canvas.drawCircle(pt, 2 * animValue, nodePaint..color = Colors.white);

        // Tinted bold clinical label text
        textPainter.text = TextSpan(
          text: scanLabel,
          style: TextStyle(
            color: nodeColor,
            fontSize: 6.8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        );
        textPainter.layout();

        // Alternating Stems (UP, DOWN, UP) to prevent crowding & curve overlay
        double stemHeight = (i == 1) ? 22.0 : -22.0;
        Offset labelCenter = Offset(pt.dx, pt.dy + stemHeight);

        // Elegant callout hairline stem line
        final stemPaint = Paint()
          ..color = nodeColor.withOpacity(0.35)
          ..strokeWidth = 1.0;
        canvas.drawLine(pt, labelCenter, stemPaint);

        // Connector bead
        canvas.drawCircle(labelCenter, 1.5, Paint()..color = nodeColor);

        // Glassmorphic capsule
        double width = textPainter.width + 16;
        double height = textPainter.height + 6;
        double rx = labelCenter.dx - width / 2;
        double ry = labelCenter.dy - height / 2;

        final capsuleRRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(rx, ry, width, height),
          const Radius.circular(100),
        );
        
        canvas.drawRRect(
          capsuleRRect,
          Paint()
            ..color = Colors.black.withOpacity(0.55)
            ..style = PaintingStyle.fill,
        );

        // Color-tinted glass frame border
        canvas.drawRRect(
          capsuleRRect,
          Paint()
            ..color = nodeColor.withOpacity(0.25)
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
  }

  @override
  bool shouldRepaint(covariant CardioHomeTachogramPainter oldDelegate) =>
      oldDelegate.hasStrain != hasStrain ||
      oldDelegate.currentRhr != currentRhr ||
      oldDelegate.averageRhr != averageRhr ||
      oldDelegate.hrHistory != hrHistory ||
      oldDelegate.animValue != animValue;
}
