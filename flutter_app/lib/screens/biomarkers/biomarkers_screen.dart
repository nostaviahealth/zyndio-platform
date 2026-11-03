import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

/// Neutral delta text between the first and last trend points (never coloured).
/// Null when there are fewer than two points (the "single result" case).
String? trendDeltaText(List<MarkerReading> trend) {
  if (trend.length < 2) return null;
  final first = parseMarkerValue(trend.first.marker.value);
  final last = parseMarkerValue(trend.last.marker.value);
  if (first == null || last == null) return null;
  final unit = trend.last.marker.unit;
  final u = unit.isEmpty ? '' : ' $unit';
  if (first == last) return 'Stable';
  final diff = last - first;
  final arrow = diff > 0 ? '↑' : '↓';
  final mag = _trim(diff.abs());
  return '${trend.first.marker.value} → ${trend.last.marker.value}$u  ($arrow $mag)';
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
    final caption = markerCaption(m);
    final band = referenceBandText(m);
    final delta = trendDeltaText(view.leadTrend);
    final altText = trendTextAlternative(m.name, view.leadTrend);

    return Semantics(
      container: true,
      label: [
        m.name,
        '${m.value}${m.unit.isEmpty ? '' : ' ${m.unit}'}',
        caption,
        if (band != null) band,
        altText,
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borderSubtle),
            boxShadow: ZyndioShadow.cardFor(Theme.of(context).brightness),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.name,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
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
              if (band != null) ...[
                const SizedBox(height: 2),
                Text(
                  band,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 13,
                    color: c.textTertiary,
                  ),
                ),
              ],
              if (delta != null) ...[
                const SizedBox(height: 10),
                Text(
                  delta,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.z25.deltaNeutral, // neutral, never red/green
                  ),
                ),
              ],
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
