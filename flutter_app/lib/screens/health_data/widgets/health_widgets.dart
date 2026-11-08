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
import '../../wearables/widgets/dashboard_card_style.dart';

import '../../../widgets/intelligence_glow_wrapper.dart';
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                child: Column(
                    children: [
                        Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
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
    Color statusColor;
    
    if (widget.marker.isOptimal) {
      statusColor = const Color(0xFF10B981);
    } else if (widget.marker.isInRange) {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = const Color(0xFFEF4444);
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
        decoration: DashboardCardStyle.decorationOf(context),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Removed status-colored left accent edge per user request

              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: context.nc.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Status Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6, height: 6,
                                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        // APP-06: bounded pill wording; the full
                                        // caption sits under the pill.
                                        widget.marker.isOutlier
                                            ? kOutsideClinicRangeShort.toUpperCase()
                                            : widget.marker.displayStatus,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: statusColor,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (widget.marker.isOutlier) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    kOutsideClinicRange,
                                    key: const Key('marker-outside-range-caption'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.nc.textSecondary,
                                      height: 1.3,
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
                                  fontSize: 22,
                                  fontFamily: 'JetBrains Mono',
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (unit.isNotEmpty)
                                Text(
                                  unit,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: context.nc.textTertiary,
                                  ),
                                ),
                            ],
                          ),

                          // 3. Right: Sparkline (Only if history exists)
                          if (!isExpanded && widget.history.length > 1) ...[
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 80, height: 40,
                              child: SimpleSparkline(history: widget.history, color: statusColor),
                            ),
                          ],

                          // Chevron indicator
                          const SizedBox(width: 8),
                          Icon(
                            isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                            size: 16,
                            color: context.nc.textTertiary,
                          ),
                        ],
                      ),

                      // --- EXPANDED SECTION ---
                      if (isExpanded) ...[
                        const SizedBox(height: 20),
                        Container(height: 1, color: context.nc.divider),
                        const SizedBox(height: 10),
                        if (widget.history.length > 1) ...[
                          SizedBox(
                            height: 200, 
                            child: DetailedTrendChart(
                              history: widget.history,
                              color: statusColor,
                              label: widget.marker.name,
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.nc.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              // ── Multi-Lab Reference Ranges ──
                              ..._buildMultiLabRanges(context),
                              
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Category", style: TextStyle(fontSize: 11, color: context.nc.textTertiary)),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: Text(
                                      widget.marker.category, 
                                      textAlign: TextAlign.right,
                                      style: TextStyle(fontSize: 11, color: context.nc.textSecondary)
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Last Sync", style: TextStyle(fontSize: 11, color: context.nc.textTertiary)),
                                  Text(widget.history.isNotEmpty ? widget.history.last['date']! : 'Today', style: TextStyle(fontSize: 11, color: context.nc.textSecondary)),
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

  /// Builds per-lab reference range rows from the enriched history data.
  /// If only one lab exists, shows a single row. If multiple labs have tested
  /// this biomarker, shows each lab's range independently.
  List<Widget> _buildMultiLabRanges(BuildContext context) {
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
            Text("Reference Range", style: TextStyle(fontSize: 11, color: context.nc.textTertiary)),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                entry['range']!,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w600, color: context.nc.textSecondary),
              ),
            ),
          ],
        ),
      );
      if (entry['lab']!.isNotEmpty && entry['lab'] != 'Unknown Lab') {
        widgets.add(const SizedBox(height: 8));
        widgets.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Source Lab", style: TextStyle(fontSize: 11, color: context.nc.textTertiary)),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  entry['lab']!,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: context.nc.textSecondary),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Multiple labs — show each range with its lab name
      widgets.add(
        Text("Reference Ranges", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.nc.textTertiary)),
      );
      for (int i = 0; i < entries.length; i++) {
        final entry = entries[i];
        if (i > 0) widgets.add(const SizedBox(height: 6));
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.nc.isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.building2, size: 10, color: context.nc.textTertiary),
                const SizedBox(width: 6),
                SizedBox(
                  width: 100, // Give lab name a guaranteed base width
                  child: Text(
                    entry['lab']!,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.nc.textSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${entry['range']!}${entry['unit']!.isNotEmpty ? ' ${entry['unit']}' : ''}',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 10, fontFamily: 'JetBrains Mono', fontWeight: FontWeight.w700, color: context.nc.textPrimary),
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(LucideIcons.checkCircle, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Units Auto-Normalized',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Values from different labs have been automatically converted to a standardized unit for accurate trend comparison.',
                      style: TextStyle(fontSize: 11, color: context.nc.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ];
    }

    // Normalization could not resolve the mismatch — show warning
    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 14, color: Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unit Mismatch — Manual Review Required',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This biomarker was reported in different units (${rawUnits.join(' vs ')}) and could not be auto-normalized. Trend comparison may be unreliable.',
                    style: TextStyle(fontSize: 11, color: context.nc.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildAIContainer({required Widget child, required double height}) {
     return IntelligenceGlowWrapper(
       borderRadius: 20,
       blurSigma: 15,
       child: Container(
         width: double.infinity,
         decoration: BoxDecoration(
           color: context.nc.isDark ? context.nc.cardSurfaceElevated : Colors.white,
           borderRadius: BorderRadius.circular(20),
           border: Border.all(color: context.nc.cardBorder.withValues(alpha: 0.1)),
         ),
         child: ClipRRect(
           borderRadius: BorderRadius.circular(20),
           child: child,
         ),
       ),
     );
  }

  Widget _buildAIContent() {
      // STATE 1: RESULT
      if (_aiInsight != null) {
          return Padding(
            padding: const EdgeInsets.all(20),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.nc.textPrimary,
                        fontFamily: 'SF Pro Display',
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Markdown Content
                MarkdownBody(
                   data: _aiInsight!,
                   styleSheet: MarkdownStyleSheet(
                     p: TextStyle(fontSize: 14, height: 1.6, color: context.nc.textSecondary, fontFamily: 'SF Pro Display'),
                     strong: TextStyle(fontWeight: FontWeight.w700, color: context.nc.textPrimary),
                   ),
                ),
                
                const SizedBox(height: 24),
                
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
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                            radius: 3,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: color,
                        ),
                    ),
                    belowBarData: BarAreaData(
                        show: true, 
                        gradient: LinearGradient(
                            colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
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
    // Use fallback if sparse history
    // Use actual history, no fake data
    final dataPoints = history;
    
    if (dataPoints.isEmpty) {
      return const Center(
        child: Text("No trend data available", style: TextStyle(color: BrandColors.slate400, fontSize: 12)),
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
                    color: color,
                    fontWeight: FontWeight.bold,
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
            getDrawingHorizontalLine: (value) => FlLine(color: context.nc.divider.withValues(alpha: 0.15), strokeWidth: 1),
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
                                 style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: context.nc.textTertiary),
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
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: color,
                        );
                    }
                ),
                belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
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


