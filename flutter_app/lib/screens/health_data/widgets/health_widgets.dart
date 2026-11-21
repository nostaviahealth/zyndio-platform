import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/lab_range_wording.dart';
import '../../../config/theme.dart';
import '../../../models/lab_report.dart';
import '../../../services/azure_openai_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../widgets/tc025/tc025_widgets.dart';

import '../../../widgets/intelligence_analysis_loading.dart';
import '../../../widgets/ask_intelligence_button.dart';
class ImmersiveWrapper extends StatelessWidget {
  final Widget child;
  final bool isImmersive;
  final BorderRadius? borderRadius;

  const ImmersiveWrapper({
    super.key,
    required this.child,
    required this.isImmersive,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (!isImmersive) return child;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: child,
    );
  }
}

class StatPill extends StatelessWidget {
    final String label; final int count; final Color color; final Color bg;
    const StatPill({super.key, required this.label, required this.count, required this.color, required this.bg});
    @override
    Widget build(BuildContext context) {
        return Expanded(
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 22,
                            height: 28 / 22,
                            fontWeight: FontWeight.w700,
                            fontFeatures: ZyndioType.tabular,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 11,
                            height: 14 / 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: color,
                          ),
                        ),
                    ],
                ),
            ),
        );
    }
}

class BiomarkerCard extends ConsumerStatefulWidget {
  final LabMarker marker;
  final bool isImmersive;
  final List<Map<String, String>> history;
  final bool initiallyExpanded;

  const BiomarkerCard({
    super.key,
    required this.marker,
    required this.isImmersive,
    this.history = const [],
    this.initiallyExpanded = false,
  });

  @override
  ConsumerState<BiomarkerCard> createState() => _BiomarkerCardState();
}

class _BiomarkerCardState extends ConsumerState<BiomarkerCard> {
  bool isExpanded = false;

  // AI State
  bool _isGenerating = false;
  String? _aiInsight;

  @override
  void initState() {
    super.initState();
    isExpanded = widget.initiallyExpanded;
  }

  Future<void> _generateInsight() async {
    setState(() => _isGenerating = true);

    try {
      final units = widget.history.map((p) => (p['unit'] ?? '').trim().toLowerCase()).where((u) => u.isNotEmpty).toSet();
      final hasUnitMismatch = units.length > 1;

      final historyStr = widget.history.map((p) => "${p['date']}: ${p['value']}${p['unit'] ?? ''}").join(", ");
      final mismatchWarning = hasUnitMismatch
          ? "CAUTION: A unit mismatch was detected across these reports (${units.join(' vs ')}). Adjust your analysis to account for this discrepancy."
          : "";

      final trendContext = widget.history.length > 1
          ? "Here is my full history for ${widget.marker.name}: $historyStr. $mismatchWarning Analyze the trajectory and velocity of this trend."
          : "My current ${widget.marker.name} level is ${widget.marker.value}.";

      final prompt = "$trendContext Is this optimal? What does this specific trend suggest about my health? Provide a concise, clinical-grade, single-paragraph analysis suitable for a mobile screen. Focus on the most recent trajectory.";

      final response = await AzureOpenAIService().getChatResponse([
        {"role": "user", "content": prompt}
      ]);

      if (mounted) {
        setState(() {
          _aiInsight = response.content;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiInsight = "Unable to generate insight at this time.";
          _isGenerating = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final ZyndioPillTone statusTone;

    // In range (or optimal) is good news: success. Only values outside the
    // clinic's range get the critical tone; no amber "normal" state.
    if (widget.marker.isOptimal || widget.marker.isInRange) {
      statusTone = ZyndioPillTone.success;
    } else {
      statusTone = ZyndioPillTone.critical;
    }

    // Use the lab-reported unit directly instead of parsing from range text
    final unit = widget.marker.unit.isNotEmpty
        ? widget.marker.unit
        : (widget.marker.range.contains('mg/dL') ? 'mg/dL' : (widget.marker.range.contains('%') ? '%' : ''));

    return Semantics(
      button: true,
      expanded: isExpanded,
      onTapHint: isExpanded ? 'collapse' : 'show trend and ranges',
      child: GestureDetector(
      onTap: () => setState(() => isExpanded = !isExpanded),
      child: Container(
        decoration: zyndioCard(context, radius: 22),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Left: Name & Status
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.marker.name,
                                  style: TextStyle(
                                    fontFamily: ZyndioType.family,
                                    fontSize: 16,
                                    height: 22 / 16,
                                    fontWeight: FontWeight.w600,
                                    color: c.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Status Pill
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: ZyndioPill(
                                    // APP-06: bounded pill wording; the full
                                    // caption sits under the pill.
                                    widget.marker.isOutlier
                                        ? kOutsideClinicRangeShort
                                        : widget.marker.isOptimal
                                            ? 'Optimal'
                                            : 'In range',
                                    tone: statusTone,
                                  ),
                                ),
                                if (widget.marker.isOutlier) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    kOutsideClinicRange,
                                    key: const Key('marker-outside-range-caption'),
                                    style: TextStyle(
                                      fontFamily: ZyndioType.family,
                                      fontSize: 13,
                                      color: c.textSecondary,
                                      height: 18 / 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // 2. Middle: Value & Unit
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                widget.marker.value,
                                style: TextStyle(
                                  fontFamily: ZyndioType.family,
                                  fontSize: 22,
                                  height: 28 / 22,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: ZyndioType.tabular,
                                  color: c.textPrimary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              if (unit.isNotEmpty)
                                Text(
                                  unit,
                                  style: TextStyle(
                                    fontFamily: ZyndioType.family,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: c.textTertiary,
                                  ),
                                ),
                            ],
                          ),

                          // 3. Right: Sparkline (Only if history exists)
                          if (!isExpanded && widget.history.length > 1) ...[
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 72, height: 36,
                              child: SimpleSparkline(history: widget.history, color: c.chartLine),
                            ),
                          ],

                          // Chevron indicator
                          const SizedBox(width: 8),
                          Icon(
                            isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                            size: 18,
                            color: c.textTertiary,
                          ),
                        ],
                      ),

                      // --- EXPANDED SECTION ---
                      if (isExpanded) ...[
                        const SizedBox(height: 18),
                        Container(height: 1, color: c.borderSubtle),
                        const SizedBox(height: 12),
                        if (widget.history.length > 1) ...[
                          SizedBox(
                            height: 200,
                            child: DetailedTrendChart(
                              history: widget.history,
                              color: c.chartLine,
                              label: widget.marker.name,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: c.bgSunken,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              // ── Multi-Lab Reference Ranges ──
                              ..._buildMultiLabRanges(context),

                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Category", style: _detailLabel(c)),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Text(
                                      widget.marker.category,
                                      textAlign: TextAlign.right,
                                      style: _detailValue(c),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Last Sync", style: _detailLabel(c)),
                                  Text(widget.history.isNotEmpty ? widget.history.last['date']! : 'Today', style: _detailValue(c)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Unit Mismatch Warning ──
                        ..._buildUnitMismatchWarning(context),
                        const SizedBox(height: 16),
                        if (_aiInsight != null || _isGenerating)
                          _buildAIContainer(child: _buildAIContent(), height: 0)
                        else
                          _buildAIContent(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      );
  }

  TextStyle _detailLabel(ZyndioColors c) => TextStyle(
        fontFamily: ZyndioType.family,
        fontSize: 13,
        color: c.textTertiary,
      );

  TextStyle _detailValue(ZyndioColors c) => TextStyle(
        fontFamily: ZyndioType.family,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: c.textSecondary,
      );

  /// Builds per-lab reference range rows from the enriched history data.
  /// If only one lab exists, shows a single row. If multiple labs have tested
  /// this biomarker, shows each lab's range independently.
  List<Widget> _buildMultiLabRanges(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    // Collect unique lab+range+unit combos from history
    final Map<String, Map<String, String>> labRanges = {};
    for (final point in widget.history) {
      final lab = (point['labName'] ?? '').isNotEmpty ? point['labName']! : 'Unknown Lab';
      final range = point['range'] ?? '--';
      final unit = point['unit'] ?? '';
      final key = '$lab|$range'; // deduplicate by lab+range combo
      if (!labRanges.containsKey(key)) {
        labRanges[key] = {'lab': lab, 'range': range, 'unit': unit};
      }
    }

    // Fallback: if history has no enriched data, use the marker's own range
    if (labRanges.isEmpty) {
      final lab = widget.marker.labName ?? 'Lab';
      labRanges['$lab|${widget.marker.range}'] = {
        'lab': lab,
        'range': widget.marker.range,
        'unit': widget.marker.unit,
      };
    }

    final entries = labRanges.values.toList();
    final List<Widget> widgets = [];

    if (entries.length == 1) {
      // Single lab — compact display
      final entry = entries.first;
      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reference Range", style: _detailLabel(c)),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                entry['range']!,
                textAlign: TextAlign.right,
                style: _detailValue(c).copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: ZyndioType.tabular,
                ),
              ),
            ),
          ],
        ),
      );
      if (entry['lab']!.isNotEmpty && entry['lab'] != 'Unknown Lab') {
        widgets.add(const SizedBox(height: 10));
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Source Lab", style: _detailLabel(c)),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  entry['lab']!,
                  textAlign: TextAlign.right,
                  style: _detailValue(c),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Multiple labs — show each range with its lab name
      widgets.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Reference Ranges",
            style: _detailLabel(c).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        if (i > 0) widgets.add(const SizedBox(height: 6));
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.building2, size: 12, color: c.textTertiary),
                const SizedBox(width: 6),
                SizedBox(
                  width: 100, // Give lab name a guaranteed base width
                  child: Text(
                    entry['lab']!,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${entry['range']!}${entry['unit']!.isNotEmpty ? ' ${entry['unit']}' : ''}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: ZyndioType.tabular,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return widgets;
  }

  /// Checks if different data points in the history use different units.
  /// If normalization was applied, shows an informational badge.
  /// If normalization couldn't resolve it, shows a warning.
  List<Widget> _buildUnitMismatchWarning(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final rawUnits = widget.history
        .map((p) => (p['unit'] ?? '').trim().toLowerCase())
        .where((u) => u.isNotEmpty)
        .toSet();

    if (rawUnits.length <= 1) return [];

    // Check if normalization was actually applied to any points
    final anyConverted = widget.history.any((p) => p['wasConverted'] == 'true');

    // After normalization, check if all units are now the same
    final normalizedUnits = widget.history
        .map((p) => (p['unit'] ?? '').trim().toLowerCase())
        .where((u) => u.isNotEmpty)
        .toSet();
    final isResolved = normalizedUnits.length <= 1;

    if (anyConverted && isResolved) {
      // Normalization was successful — show a soft informational note
      return [
        const SizedBox(height: 12),
        _buildNote(
          c: c,
          icon: LucideIcons.checkCircle,
          fg: c.statusSuccess,
          bg: c.statusSuccessSubtle,
          title: 'Units Auto-Normalized',
          body: 'Values from different labs have been automatically converted to a standardized unit for accurate trend comparison.',
        ),
      ];
    }

    // Normalization could not resolve the mismatch — show warning
    return [
      const SizedBox(height: 12),
      _buildNote(
        c: c,
        icon: LucideIcons.alertTriangle,
        fg: c.statusWarning,
        bg: c.statusWarningSubtle,
        title: 'Unit Mismatch — Manual Review Required',
        body: 'This biomarker was reported in different units (${rawUnits.join(' vs ')}) and could not be auto-normalized. Trend comparison may be unreliable.',
      ),
    ];
  }

  Widget _buildNote({
    required ZyndioColors c,
    required IconData icon,
    required Color fg,
    required Color bg,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 13,
                    color: c.textSecondary,
                    height: 18 / 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIContainer({required Widget child, required double height}) {
     final c = Theme.of(context).extension<ZyndioColors>()!;
     return Container(
       width: double.infinity,
       decoration: BoxDecoration(
         color: c.bgSurface,
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: c.borderSubtle),
       ),
       child: ClipRRect(
         borderRadius: BorderRadius.circular(20),
         child: child,
       ),
     );
  }

  Widget _buildAIContent() {
      final c = Theme.of(context).extension<ZyndioColors>()!;
      // STATE 1: RESULT
      if (_aiInsight != null) {
          return Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Assets Logo + Text)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "Intelligence Summary",
                      style: TextStyle(
                        fontSize: 17,
                        height: 24 / 17,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                        fontFamily: ZyndioType.family,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Markdown Content
                MarkdownBody(
                   data: _aiInsight!,
                   styleSheet: MarkdownStyleSheet(
                     p: TextStyle(fontSize: 15, height: 22 / 15, color: c.textSecondary, fontFamily: ZyndioType.family),
                     strong: TextStyle(fontWeight: FontWeight.w700, color: c.textPrimary, fontFamily: ZyndioType.family),
                   ),
                ),

                const SizedBox(height: 20),

                AskIntelligenceButton(
                  label: "Deep Dive",
                  onTap: () {
                    final units = widget.history.map((p) => (p['unit'] ?? '').trim().toLowerCase()).where((u) => u.isNotEmpty).toSet();
                    final hasUnitMismatch = units.length > 1;

                    final historyStr = widget.history.map((p) => "${p['date']}: ${p['value']}${p['unit'] ?? ''}").join(", ");
                    final mismatchWarning = hasUnitMismatch
                        ? "CAUTION: A unit mismatch was detected across these reports (${units.join(' vs ')})."
                        : "";

                    final trendContext = widget.history.length > 1
                        ? "I have the following history for ${widget.marker.name}: $historyStr. $mismatchWarning"
                        : "My current ${widget.marker.name} level is ${widget.marker.value}.";
                    context.pushNamed('chat', queryParameters: {
                      'initialMessage': 'Deep dive: $trendContext Analyze the trajectory. Is it optimal? How can I improve it? (Context: $_aiInsight)'
                    });
                  },
                ),
              ],
            ),
          );
      }

      // STATE 2: LOADING - SIRI ORB ANIMATION
      if (_isGenerating) {
        return const IntelligenceAnalysisLoading(type: LoadingType.labs);
      }

      // STATE 3: IDLE (BUTTON)

      return AskIntelligenceButton(
        onTap: _generateInsight,
      );
  }

  // ..
}

// Helper for blur
extension WidgetBlur on Widget {
  Widget blur(double sigma) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: this,
    );
  }
}

class SimpleSparkline extends StatelessWidget {
  final List<Map<String, String>> history;
  final Color color;
  const SimpleSparkline({super.key, required this.history, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    // Generate fallback data if history is empty
    if (history.isEmpty) return const SizedBox();

    final points = history.asMap().entries.map((e) {
      final val = double.tryParse(e.value['value']!.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
      return FlSpot(e.key.toDouble(), val);
    }).toList();

    return LineChart(
        LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
                LineChartBarData(
                    spots: points,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 2.5,
                            color: c.bgSurface,
                            strokeWidth: 2,
                            strokeColor: color,
                        ),
                    ),
                    belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                        )
                    ),
                ),
            ],
        )
    );
  }
}

class DetailedTrendChart extends StatelessWidget {
  final List<Map<String, String>> history;
  final Color color;
  final String label;

  const DetailedTrendChart({super.key, required this.history, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    // Use fallback if sparse history
    // Use actual history, no fake data
    final dataPoints = history;

    if (dataPoints.isEmpty) {
      return Center(
        child: Text(
          "No trend data available",
          style: TextStyle(fontFamily: ZyndioType.family, color: c.textTertiary, fontSize: 13),
        ),
      );
    }

    final spots = dataPoints.asMap().entries.map((e) {
         final val = double.tryParse(e.value['value']!.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
         return FlSpot(e.key.toDouble(), val);
    }).toList();

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            tooltipMargin: 4,
            getTooltipColor: (spot) => Colors.transparent,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                return LineTooltipItem(
                  dataPoints[barSpot.spotIndex]['value']!,
                  TextStyle(
                    fontFamily: ZyndioType.family,
                    color: c.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontFeatures: ZyndioType.tabular,
                    fontSize: 13,
                  ),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: false,
        ),
        showingTooltipIndicators: spots.map((spot) {
          return ShowingTooltipIndicators([
            LineBarSpot(
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 3,
              ),
              0,
              spot,
            ),
          ]);
        }).toList(),
        gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: c.borderSubtle, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 35, // More space for the date
                    getTitlesWidget: (val, meta) {
                        // Only show label if the value is an exact integer index
                        if (val % 1 != 0) return const SizedBox.shrink();

                        final index = val.toInt();
                        if (index >= 0 && index < dataPoints.length) {
                             final dateStr = dataPoints[index]['date']!;
                             return Padding(
                               padding: const EdgeInsets.only(top: 10.0),
                               child: Text(
                                 dateStr.length > 10 ? dateStr.substring(5, 10) : dateStr,
                                 style: TextStyle(fontFamily: ZyndioType.family, fontSize: 11, fontWeight: FontWeight.w500, color: c.textTertiary),
                                 textAlign: TextAlign.center,
                               ),
                             );
                        }
                        return const SizedBox.shrink();
                    },
                    interval: 1,
                )
            ),
        ),
        borderData: FlBorderData(show: false),
        minX: -0.1,
        maxX: dataPoints.length - 0.9,
        lineBarsData: [
            LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                            radius: 4,
                            color: c.bgSurface,
                            strokeWidth: 2,
                            strokeColor: color,
                        );
                    }
                ),
                belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                    )
                ),
            ),
        ],
      ),
    );
  }
}


