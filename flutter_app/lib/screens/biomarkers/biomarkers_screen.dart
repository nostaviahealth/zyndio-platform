import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/biomarker_segments.dart';
import '../../config/theme.dart';
import '../../models/lab_report.dart';
import '../../providers/lab_reports_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../health_data/health_data_screen.dart';

// ── Pure helpers (unit-tested) ───────────────────────────────────────────────

/// Leading numeric value of a free-form lab value string ("7.3", "<5", "1,234").
double? parseMarkerValue(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'-?\d+(\.\d+)?').firstMatch(raw.replaceAll(',', ''));
  return m == null ? null : double.tryParse(m.group(0)!);
}

/// A single marker reading on a given date (one point in a trend).
class MarkerReading {
  const MarkerReading({required this.date, required this.marker});
  final String date;
  final LabMarker marker;
}

/// Markers for one segment, ordered lead-first, taken from the latest report;
/// plus the lead marker's readings across every report (the trend points).
class SegmentView {
  const SegmentView({required this.markers, required this.leadTrend});
  final List<LabMarker> markers;
  final List<MarkerReading> leadTrend;

  bool get isEmpty => markers.isEmpty;
  LabMarker? get hero => markers.isEmpty ? null : markers.first;
  List<LabMarker> get rest => markers.length <= 1 ? const [] : markers.sublist(1);
}

/// Reports newest-first by their (yyyy-mm-dd) date string.
List<LabReport> sortReportsNewestFirst(List<LabReport> reports) {
  final copy = [...reports];
  copy.sort((a, b) => b.date.compareTo(a.date));
  return copy;
}

/// Build the per-segment view from all reports (newest-first expected).
SegmentView segmentView(List<LabReport> newestFirst, BiomarkerSegment seg) {
  final latest = newestFirst.isEmpty ? const <LabMarker>[] : newestFirst.first.markers;
  final inSeg = latest.where((m) => segmentForMarker(m.name) == seg).toList();
  // Lead marker first, otherwise the lab's own order.
  inSeg.sort((a, b) {
    final al = isSegmentLead(a.name, seg) ? 0 : 1;
    final bl = isSegmentLead(b.name, seg) ? 0 : 1;
    return al.compareTo(bl);
  });

  final leadName = inSeg.isEmpty ? null : inSeg.first.name;
  final trend = <MarkerReading>[];
  if (leadName != null) {
    final key = normalizeMarkerName(leadName);
    // Oldest → newest so a trend reads left to right.
    for (final r in newestFirst.reversed) {
      for (final m in r.markers) {
        if (normalizeMarkerName(m.name) == key) {
          trend.add(MarkerReading(date: r.date, marker: m));
          break;
        }
      }
    }
  }
  return SegmentView(markers: inSeg, leadTrend: trend);
}

/// Change of the latest reading against the BASELINE (first reading), per
/// spec Z6/§6 (PR #30 review M3). Null with fewer than two numeric points.
/// Rules (also in the PR body and unit tests):
/// - exactly equal → stable;
/// - otherwise n = |last − first| / |first| × 100, rounded to the nearest
///   integer with .5 away from zero (Dart `round()`); a real change that
///   rounds to 0 shows "<1" (never "+0%" or Stable);
/// - zero baseline: % is undefined, so the signed change in the marker's
///   unit is shown instead (e.g. "↑ +15 µM").
({bool stable, bool up, String magnitude, bool percent})? _baselineDelta(
    List<MarkerReading> trend) {
  if (trend.length < 2) return null;
  final first = parseMarkerValue(trend.first.marker.value);
  final last = parseMarkerValue(trend.last.marker.value);
  if (first == null || last == null) return null;
  if (first == last) return (stable: true, up: false, magnitude: '', percent: false);
  final up = last > first;
  if (first == 0) {
    final unit = trend.last.marker.unit;
    return (
      stable: false,
      up: up,
      magnitude: '${_trim(last.abs())}${unit.isEmpty ? '' : ' $unit'}',
      percent: false,
    );
  }
  final n = ((last - first).abs() / first.abs() * 100).round();
  return (stable: false, up: up, magnitude: n == 0 ? '<1' : '$n', percent: true);
}

/// Visible hero delta: `{↑|↓} {+|−}{n}%` (U+2212 minus), or "Stable".
String? trendDeltaText(List<MarkerReading> trend) {
  final d = _baselineDelta(trend);
  if (d == null) return null;
  if (d.stable) return 'Stable';
  return '${d.up ? '↑ +' : '↓ −'}${d.magnitude}${d.percent ? '%' : ''}';
}

/// Screen-reader form of [trendDeltaText], e.g. "up 58 percent since baseline".
String? trendDeltaSpoken(List<MarkerReading> trend) {
  final d = _baselineDelta(trend);
  if (d == null) return null;
  if (d.stable) return 'stable since baseline';
  final mag = d.magnitude == '<1' ? 'less than 1' : d.magnitude;
  return '${d.up ? 'up' : 'down'} $mag${d.percent ? ' percent' : ''} since baseline';
}

/// "Baseline: {v} · {date}" from the first reading, shown only with ≥2 readings.
String? baselineCaptionText(List<MarkerReading> trend) {
  if (trend.length < 2) return null;
  final first = trend.first;
  final unit = first.marker.unit.isEmpty ? '' : ' ${first.marker.unit}';
  return 'Baseline: ${first.marker.value}$unit · ${first.date}';
}

/// Single-result caption, shown only when there is exactly one reading.
String? firstResultCaptionText(List<MarkerReading> trend) {
  if (trend.length != 1) return null;
  return 'First result · ${trend.first.date}. Your trend appears after your next test.';
}

/// Whether a marker has BOTH lab bounds (drives the chart's reference band; a
/// single bound shows no band — we never invent the missing bound).
bool hasLabBand(LabMarker m) => m.minRange != null && m.maxRange != null;

/// Short X-axis label from a yyyy-mm-dd report date ("2026-06-01" → "06-01").
/// Falls back to the raw string so no value is ever invented.
String shortDate(String raw) {
  final m = RegExp(r'^\d{4}-(\d{2})-(\d{2})$').firstMatch(raw);
  return m == null ? raw : '${m.group(1)}-${m.group(2)}';
}

/// Non-clinical, data-only copy for the (i) marker explainer sheet. No medical
/// explanation of what the marker means and no advice — see QUESTIONS.md.
class MarkerInfoCopy {
  const MarkerInfoCopy({
    required this.title,
    required this.latestLine,
    required this.rangeLine,
    required this.sourceLine,
    required this.careLine,
  });
  final String title;
  final String latestLine;
  final String rangeLine;
  final String sourceLine;
  final String careLine;
}

MarkerInfoCopy markerInfoCopy(LabMarker m, String latestDate) {
  final unit = m.unit.isEmpty ? '' : ' ${m.unit}';
  return MarkerInfoCopy(
    title: 'About ${m.name}',
    latestLine: 'Latest: ${m.value}$unit on ${_explainerDate(latestDate)}',
    rangeLine: referenceBandText(m) ?? 'No lab range provided',
    sourceLine: 'Lab reference ranges come from the laboratory that ran your test.',
    careLine: 'Questions about your results go to your care team.',
  );
}

/// "2026-09-15" → "Sep 15, 2026" for the explainer (PR #30 review). Uses the
/// calendar date as written (no time-zone shift); anything else is shown as
/// given, so no date is ever invented.
String _explainerDate(String raw) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw);
  if (m == null) return raw;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final date = DateTime(y, mo, d);
  if (date.month != mo || date.day != d) return raw; // e.g. 2026-02-30
  return DateFormat('MMM d, y', 'en_US').format(date);
}

/// A readable reference-band line, or null when no range is recorded.
String? referenceBandText(LabMarker m) {
  final low = m.minRange, high = m.maxRange;
  final unit = m.unit.isEmpty ? '' : ' ${m.unit}';
  if (low != null && high != null) return 'Lab range ${_trim(low)}–${_trim(high)}$unit';
  if (high != null) return 'Lab range up to ${_trim(high)}$unit';
  if (low != null) return 'Lab range from ${_trim(low)}$unit';
  return null;
}

/// Text alternative for the hero trend chart: every point, in order.
String trendTextAlternative(String markerName, List<MarkerReading> trend) {
  if (trend.isEmpty) return '$markerName: no results yet.';
  final pts = trend
      .map((r) => '${r.marker.value}${r.marker.unit.isEmpty ? '' : ' ${r.marker.unit}'} on ${r.date}')
      .join(', ');
  return '$markerName trend: $pts.';
}

String _trim(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

String markerCaption(LabMarker m) => biomarkerRangeCaption(
      value: parseMarkerValue(m.value),
      low: m.minRange,
      high: m.maxRange,
      status: m.status,
    );

// ── Screen ───────────────────────────────────────────────────────────────────

class BiomarkersScreen extends ConsumerStatefulWidget {
  const BiomarkersScreen({super.key});

  @override
  ConsumerState<BiomarkersScreen> createState() => _BiomarkersScreenState();
}

class _BiomarkersScreenState extends ConsumerState<BiomarkersScreen> {
  BiomarkerSegment _segment = BiomarkerSegment.nad;

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(labReportsProvider);
    // Subtitle (lab-partner source line) comes from white-label/org config. No
    // such config field exists today, so it is omitted (no hard-coded partner).
    return ZyndioTabScaffold(
      title: 'Biomarkers',
      onRefresh: () => ref.refresh(labReportsProvider.future),
      children: reports.when(
        loading: () => const [_BiomarkersLoading()],
        error: (_, __) => [
          ZyndioStateCard(
            icon: LucideIcons.triangleAlert,
            title: "We couldn't load your results",
            body: 'Check your connection and try again. Nothing you saved has been lost.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(labReportsProvider),
          ),
        ],
        data: (reports) => _dataBody(context, reports),
      ),
    );
  }

  List<Widget> _dataBody(BuildContext context, List<LabReport> reports) {
    final newestFirst = sortReportsNewestFirst(reports);
    final hasAnyMarkers = newestFirst.any((r) => r.markers.isNotEmpty);
    if (!hasAnyMarkers) {
      return [
        ZyndioStateCard(
          icon: LucideIcons.flaskConical,
          title: 'No lab results yet',
          body:
              'Results appear here after you upload a lab report or your lab sends it to your care team.',
          actionLabel: 'Upload a lab report',
          onAction: () => context.pushNamed('upload_report'),
        ),
      ];
    }

    final view = segmentView(newestFirst, _segment);
    return [
      _SegmentBar(
        selected: _segment,
        onChanged: (s) => setState(() => _segment = s),
      ),
      const SizedBox(height: 16),
      if (view.isEmpty)
        ZyndioStateCard(
          icon: LucideIcons.flaskConical,
          title: 'No results in this group yet',
          body:
              'Upload a lab report with ${_segment.label} markers, or your lab can send them to your care team.',
          actionLabel: 'Upload a lab report',
          onAction: () => context.pushNamed('upload_report'),
        )
      else ...[
        _BiomarkerHero(view: view),
        if (view.rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          _MarkerGrid(markers: view.rest),
        ],
      ],
      const SizedBox(height: 16),
      _ViewFullReportCta(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HealthDataScreen()),
        ),
      ),
    ];
  }
}

// ── Segmented control (Z18) ──────────────────────────────────────────────────

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({required this.selected, required this.onChanged});
  final BiomarkerSegment selected;
  final ValueChanged<BiomarkerSegment> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final seg in BiomarkerSegment.values) ...[
            _SegmentPill(
              label: seg.label,
              selected: seg == selected,
              onTap: () => onChanged(seg),
            ),
            if (seg != BiomarkerSegment.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final z = context.z25;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap, // H1: screen-reader activation == finger tap
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              gradient: selected ? ZyndioGradients.segmentActive : null,
              color: selected ? null : z.segmentBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : z.segmentText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Z6 hero ──────────────────────────────────────────────────────────────────

class _BiomarkerHero extends StatelessWidget {
  const _BiomarkerHero({required this.view});
  final SegmentView view;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final m = view.hero!;
    final trend = view.leadTrend;
    final caption = markerCaption(m);
    final band = referenceBandText(m);
    final delta = trendDeltaText(trend);
    final deltaSpoken = trendDeltaSpoken(trend);
    final altText = trendTextAlternative(m.name, trend);
    final baseline = baselineCaptionText(trend);
    final firstResult = firstResultCaptionText(trend);
    final latestDate = trend.isEmpty ? '' : trend.last.date;
    final hasChart = trend.any((r) => parseMarkerValue(r.marker.value) != null);

    final readout = [
      m.name,
      '${m.value}${m.unit.isEmpty ? '' : ' ${m.unit}'}',
      caption,
      if (band != null) band,
      if (deltaSpoken != null) deltaSpoken,
      altText,
      if (baseline != null) baseline,
      if (firstResult != null) firstResult,
    ].join(', ');

    // M1: the 16pt card padding sits inside the Stack (not around it) so the
    // (i) button's full 44×44 target lies within the Stack's bounds; it was
    // clipped to 38×38 at top/right -6. Same painted position as before.
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSubtle),
        boxShadow: ZyndioShadow.cardFor(Theme.of(context).brightness),
      ),
      child: Stack(
        children: [
          // Data readout: one text alternative for screen readers; the painted
          // values and chart are decorative (ExcludeSemantics). M1: read
          // before the (i) button (sort key 0 vs 1).
          Padding(
            padding: const EdgeInsets.all(16),
            child: Semantics(
              container: true,
              sortKey: const OrdinalSortKey(0),
              label: readout,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 44),
                      child: Text(
                        m.name,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    RichText(
                      text: TextSpan(
                        text: m.value,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                        children: [
                          if (m.unit.isNotEmpty)
                            TextSpan(
                              text: ' ${m.unit}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: c.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      caption,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: c.textSecondary,
                      ),
                    ),
                    if (delta != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        delta,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: context.z25.deltaNeutral, // neutral, never red/green
                        ),
                      ),
                    ],
                    if (hasChart) ...[
                      const SizedBox(height: 12),
                      _BiomarkerTrendChart(trend: trend, marker: m),
                    ],
                    if (band != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        band,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 13,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                    if (baseline != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        baseline,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 13,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                    if (firstResult != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        firstResult,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 13,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: _MarkerInfoButton(marker: m, latestDate: latestDate),
          ),
        ],
      ),
    );
  }
}

/// (i) explainer button: 18pt icon inside a 44×44 hit target.
class _MarkerInfoButton extends StatelessWidget {
  const _MarkerInfoButton({required this.marker, required this.latestDate});
  final LabMarker marker;
  final String latestDate;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    // M1: its own 44×44 node (container) read after the hero readout, instead
    // of merging into a node that spans the whole hero card.
    return Semantics(
      container: true,
      sortKey: const OrdinalSortKey(1),
      button: true,
      label: 'About ${marker.name}',
      onTap: () => _open(context),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _open(context),
          child: SizedBox(
            key: const Key('marker-info-button'),
            width: 44,
            height: 44,
            child: Center(
              child: Icon(LucideIcons.info, size: 18, color: c.textTertiary),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) =>
      showMarkerInfoSheet(context, marker: marker, latestDate: latestDate);
}

/// Modal bottom sheet (radius 20) with the data-only marker explainer copy.
Future<void> showMarkerInfoSheet(
  BuildContext context, {
  required LabMarker marker,
  required String latestDate,
}) {
  final copy = markerInfoCopy(marker, latestDate);
  final c = Theme.of(context).extension<ZyndioColors>()!;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      copy.title,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Close',
                  onTap: () => Navigator.of(ctx).pop(),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.of(ctx).pop(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Text(
                            'Close',
                            style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: context.z25.tabActive,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final line in [copy.latestLine, copy.rangeLine, copy.sourceLine, copy.careLine]) ...[
              Text(
                line,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 15,
                  height: 1.45,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Z6 line chart: the lead marker's readings across reports. Decorative — the
/// hero carries the text alternative, so the chart is excluded from semantics.
class _BiomarkerTrendChart extends StatelessWidget {
  const _BiomarkerTrendChart({required this.trend, required this.marker});
  final List<MarkerReading> trend;
  final LabMarker marker;

  @override
  Widget build(BuildContext context) {
    final z = context.z25;
    final c = Theme.of(context).extension<ZyndioColors>()!;

    final spots = <FlSpot>[];
    final ys = <double>[];
    for (var i = 0; i < trend.length; i++) {
      final v = parseMarkerValue(trend[i].marker.value);
      if (v != null) {
        spots.add(FlSpot(i.toDouble(), v));
        ys.add(v);
      }
    }
    final band = hasLabBand(marker);
    var minY = ys.isEmpty ? 0.0 : ys.reduce(math.min);
    var maxY = ys.isEmpty ? 1.0 : ys.reduce(math.max);
    if (band) {
      minY = math.min(minY, marker.minRange!);
      maxY = math.max(maxY, marker.maxRange!);
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final pad = (maxY - minY) * 0.15;
    minY -= pad;
    maxY += pad;
    // Small X padding so the edge date labels aren't clipped by the plot bounds;
    // a single reading is centred.
    final lastX = (trend.length - 1).toDouble();
    final minX = trend.length <= 1 ? -1.0 : -0.35;
    final maxX = trend.length <= 1 ? 1.0 : lastX + 0.35;

    return ExcludeSemantics(
      child: SizedBox(
        key: const Key('biomarker-trend-chart'),
        height: 156,
        width: double.infinity,
        child: LineChart(
          LineChartData(
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            rangeAnnotations: band
                ? RangeAnnotations(horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(
                      y1: marker.minRange!,
                      y2: marker.maxRange!,
                      color: z.badgeActiveBg,
                    ),
                  ])
                : const RangeAnnotations(),
            titlesData: FlTitlesData(
              show: true,
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    // Only the exact reading positions get a date; the padded
                    // edge ticks (non-integer) render nothing (no ghost labels).
                    if ((value - value.roundToDouble()).abs() > 0.001) {
                      return const SizedBox.shrink();
                    }
                    final i = value.round();
                    if (i < 0 || i >= trend.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        shortDate(trend[i].date),
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 11,
                          color: c.textTertiary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                barWidth: 3,
                isStrokeCapRound: true,
                gradient: LinearGradient(
                  colors: [z.chartLineStart, z.chartLineEnd],
                ),
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, pct, bar, index) => FlDotCirclePainter(
                    radius: 5,
                    color: c.bgSurface,
                    strokeWidth: 2.5,
                    strokeColor: z.chartPointStroke,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: const LinearGradient(
                    colors: [Color(0x470B6FD6), Color(0x000B6FD6)], // 28% → 0
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Z7 marker tiles ──────────────────────────────────────────────────────────

class _MarkerGrid extends StatelessWidget {
  const _MarkerGrid({required this.markers});
  final List<LabMarker> markers;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < markers.length; i += 2) {
      if (i + 1 < markers.length) {
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _MarkerTile(marker: markers[i])),
              const SizedBox(width: 12),
              Expanded(child: _MarkerTile(marker: markers[i + 1])),
            ],
          ),
        ));
      } else {
        rows.add(SizedBox(width: double.infinity, child: _MarkerTile(marker: markers[i])));
      }
      if (i + 2 < markers.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }
}

class _MarkerTile extends StatelessWidget {
  const _MarkerTile({required this.marker});
  final LabMarker marker;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final z = context.z25;
    final caption = markerCaption(marker);
    return Semantics(
      container: true,
      label: '${marker.name}, ${marker.value}${marker.unit.isEmpty ? '' : ' ${marker.unit}'}, $caption',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: z.tileBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                marker.name,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  text: marker.value,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                  children: [
                    if (marker.unit.isNotEmpty)
                      TextSpan(
                        text: ' ${marker.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 13,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewFullReportCta extends StatelessWidget {
  const _ViewFullReportCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      button: true,
      label: 'View Full Biomarker Report',
      onTap: onTap, // H1: screen-reader activation == finger tap
      child: ExcludeSemantics(
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            side: BorderSide(color: context.z25.tabActive, width: 1.5),
            foregroundColor: c.textPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('View Full Biomarker Report'),
        ),
      ),
    );
  }
}

class _BiomarkersLoading extends StatelessWidget {
  const _BiomarkersLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      container: true,
      child: Column(
        children: [
          Row(
            children: [
              _skel(context, 44, width: 92),
              const SizedBox(width: 8),
              _skel(context, 44, width: 110),
            ],
          ),
          const SizedBox(height: 16),
          _skel(context, 150),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _skel(context, 84)),
              const SizedBox(width: 12),
              Expanded(child: _skel(context, 84)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _skel(BuildContext context, double h, {double? width}) => Container(
        height: h,
        width: width,
        decoration: BoxDecoration(
          color: context.nc.shimmerBase,
          borderRadius: BorderRadius.circular(16),
        ),
      );
}
