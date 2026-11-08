import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/body_composition.dart';
import '../../data/dexa_measures.dart';
import '../../data/dexa_compare.dart';
import '../../config/theme.dart';
import '../../providers/body_composition_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../../providers/feature_flags_provider.dart';

/// Progress tab (client mockup "Body Composition"): segment pills, baseline vs
/// latest scan, four change cards per segment, and the full report. Values are
/// the stored scan measures only; no clinical score or recommendation.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final scans = ref.watch(bodyCompositionScansProvider);
    final appointmentsEnabled =
        ref.watch(featureFlagsProvider).appointmentsEnabled;
    final segments = dexaSegments.keys.toList();
    return ZyndioTabScaffold(
      title: 'Body Composition',
      subtitle: 'DEXASCAN · Measurable results. Real progress.',
      onRefresh: () => ref.refresh(bodyCompositionScansProvider.future),
      children: scans.when(
        loading: () => const [
          ZyndioStateCard(
            icon: LucideIcons.activity,
            title: 'Loading body composition',
            body: 'Checking for scans your care team has released.',
          ),
        ],
        error: (_, __) => [
          ZyndioStateCard(
            icon: LucideIcons.triangleAlert,
            title: "We couldn't load body composition",
            body: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(bodyCompositionScansProvider),
          ),
        ],
        data: (rows) {
          if (rows.isEmpty) {
            return [
              ZyndioStateCard(
                icon: LucideIcons.activity,
                title: 'No DEXASCAN results yet',
                body:
                    'Your body composition will appear here after a scan has been bound to your record.',
                // Booking is mock data until Appointments ships (feature flag).
                actionLabel:
                    appointmentsEnabled ? 'Book my baseline scan' : null,
                onAction: appointmentsEnabled
                    ? () => context.pushNamed('appointments')
                    : null,
              ),
            ];
          }
          final pair = baselineAndLatest(rows);
          final latest = pair.latest!;
          final compare = compareSegment(segments[_segment], latest, pair.baseline);
          return [
            ZyndioSegmentedTabs(
              labels: segments,
              selected: _segment,
              onSelected: (i) => setState(() => _segment = i),
            ),
            const SizedBox(height: 16),
            _ScanPanels(baseline: pair.baseline, latest: latest),
            const SizedBox(height: 12),
            if (compare.isEmpty)
              ZyndioStateCard(
                icon: LucideIcons.info,
                title: 'Not measured in this scan',
                body: '${segments[_segment]} values weren\'t included in your latest scan.',
              )
            else
              _CompareGrid(rows: compare),
            const SizedBox(height: 20),
            ZyndioGradientButton(
              label: 'View Full DEXASCAN Report',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DexaReportPage(scans: rows),
              )),
            ),
          ];
        },
      ),
    );
  }
}

/// Baseline and latest scan side by side (mockup body figures).
/// The scan stage: baseline and latest bodies glowing on a deep navy panel
/// (DEXA imagery reads best on dark), dates in white, an arrow between.
class _ScanPanels extends StatelessWidget {
  const _ScanPanels({required this.baseline, required this.latest});
  final StoredBodyScan? baseline;
  final StoredBodyScan latest;

  @override
  Widget build(BuildContext context) {
    Widget figure(String title, String date) => Expanded(
          child: Column(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(date,
                  style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.65))),
              const SizedBox(height: 14),
              const SizedBox(
                width: 92,
                height: 176,
                child: CustomPaint(painter: _BodyScanPainter()),
              ),
            ],
          ),
        );
    return Semantics(
      container: true,
      label: baseline == null
          ? 'Latest scan ${latest.scanDate}'
          : 'Baseline scan ${baseline!.scanDate}, latest scan ${latest.scanDate}',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF151A3E), Color(0xFF0B0F26)],
              ),
            ),
            child: Stack(
              children: [
                // Faint scan grid behind the figures.
                Positioned.fill(child: CustomPaint(painter: _GridPainter())),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (baseline != null) ...[
                      figure('Baseline', baseline!.scanDate),
                      Icon(LucideIcons.arrowRight, size: 22, color: Colors.white.withValues(alpha: 0.7)),
                    ],
                    figure('Latest Scan', latest.scanDate),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompareGrid extends StatelessWidget {
  const _CompareGrid({required this.rows});
  final List<DexaCompareRow> rows;

  @override
  Widget build(BuildContext context) {
    final cards = [for (final r in rows) _CompareCard(row: r)];
    final out = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      out.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cards[i]),
            const SizedBox(width: 12),
            Expanded(child: i + 1 < cards.length ? cards[i + 1] : const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < cards.length) out.add(const SizedBox(height: 12));
    }
    return Column(children: out);
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.row});
  final DexaCompareRow row;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final z = context.z25;
    return Semantics(
      container: true,
      label: [
        row.label,
        if (row.baseline != null) 'baseline ${row.baseline}',
        'latest ${row.latest}',
        if (row.change != null) row.change!,
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: zyndioCard(context, radius: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.label,
                  style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary)),
              const SizedBox(height: 10),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 8,
                children: [
                  if (row.baseline != null)
                    Text(row.baseline!,
                        style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFeatures: ZyndioType.tabular,
                            color: c.textTertiary)),
                  ShaderMask(
                    shaderCallback: (r) => ZyndioGradients.brand.createShader(r),
                    child: Text(row.latest,
                        style: const TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            fontFeatures: ZyndioType.tabular,
                            color: Colors.white)),
                  ),
                ],
              ),
              if (row.change != null) ...[
                const SizedBox(height: 8),
                Text(row.change!,
                    style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFeatures: ZyndioType.tabular,
                        color: z.deltaNeutral)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full DEXASCAN report: every stored measure, newest scan first, in report
/// sections (dexa_measures.dart).
class DexaReportPage extends StatelessWidget {
  const DexaReportPage({super.key, required this.scans});
  final List<StoredBodyScan> scans;

  @override
  Widget build(BuildContext context) {
    final sorted = [...scans]..sort((a, b) => b.scanDate.compareTo(a.scanDate));
    return Scaffold(
      backgroundColor: context.z25.screenBg,
      appBar: AppBar(
        title: const Text('DEXASCAN Report'),
        backgroundColor: context.z25.screenBg,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [for (final scan in sorted) _ScanCard(scan: scan)],
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.scan});

  final StoredBodyScan scan;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final device = scan.deviceLine;
    final groups = groupDexaMeasures(scan.measures);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: zyndioCard(context, radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.activity, size: 20, color: c.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      scan.scanDate.isEmpty ? 'DEXA scan' : 'DEXA scan · ${scan.scanDate}',
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (device.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(device, style: TextStyle(fontSize: 13, color: c.textTertiary)),
            ],
            if (groups.isEmpty) ...[
              const SizedBox(height: 12),
              Text('No measures were stored with this scan.',
                  style: TextStyle(fontSize: 15, color: c.textSecondary)),
            ],
            for (final g in groups) ...[
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  g.section.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              for (final r in g.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(r.label,
                            style: TextStyle(fontSize: 15, color: c.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        r.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              'Values are as reported by the scan provider. Review them with your care team.',
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A front-view body silhouette with a DEXA-style heat gradient (cool blue at
/// the extremities, violet to rose through the core), standing in for the
/// mockup's scan imagery. Decorative only; it does not encode any values.
class _BodyScanPainter extends CustomPainter {
  const _BodyScanPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    double y(double f) => h * f;

    final body = Path()
      // Head and neck.
      ..addOval(Rect.fromCircle(center: Offset(cx, y(0.075)), radius: w * 0.13))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, y(0.155)), width: w * 0.12, height: y(0.05)),
          const Radius.circular(4)));
    // Torso: shoulders to waist to hips.
    body.addPath(
      Path()
        ..moveTo(cx - w * 0.30, y(0.19))
        ..quadraticBezierTo(cx, y(0.165), cx + w * 0.30, y(0.19))
        ..quadraticBezierTo(cx + w * 0.31, y(0.33), cx + w * 0.20, y(0.47))
        ..quadraticBezierTo(cx + w * 0.25, y(0.55), cx + w * 0.23, y(0.60))
        ..lineTo(cx - w * 0.23, y(0.60))
        ..quadraticBezierTo(cx - w * 0.25, y(0.55), cx - w * 0.20, y(0.47))
        ..quadraticBezierTo(cx - w * 0.31, y(0.33), cx - w * 0.30, y(0.19))
        ..close(),
      Offset.zero,
    );
    // Arms (slightly angled out) and legs.
    void limb(Offset top, Offset bottom, double width) {
      final dir = bottom - top;
      final len = dir.distance;
      // A capsule along +y, rotated so it points from top to bottom.
      final angle = math.atan2(dir.dy, dir.dx) - math.pi / 2;
      final m = Matrix4.identity()
        ..translateByDouble(top.dx, top.dy, 0, 1)
        ..rotateZ(angle);
      body.addPath(
        Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromLTWH(-width / 2, 0, width, len), Radius.circular(width / 2))),
        Offset.zero,
        matrix4: m.storage,
      );
    }

    limb(Offset(cx - w * 0.29, y(0.20)), Offset(cx - w * 0.42, y(0.58)), w * 0.12);
    limb(Offset(cx + w * 0.29, y(0.20)), Offset(cx + w * 0.42, y(0.58)), w * 0.12);
    limb(Offset(cx - w * 0.12, y(0.58)), Offset(cx - w * 0.15, y(0.99)), w * 0.17);
    limb(Offset(cx + w * 0.12, y(0.58)), Offset(cx + w * 0.15, y(0.99)), w * 0.17);

    final heat = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0, -0.05),
        radius: 0.75,
        colors: [Color(0xFFFF5C7A), Color(0xFFB05CF0), Color(0xFF5B6CFF), Color(0xFF2E9BEA)],
        stops: [0.0, 0.35, 0.65, 1.0],
      ).createShader(Offset.zero & size);
    // Soft glow behind, then the body.
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF6A4CF5).withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(body, heat);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
