import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/simulation_result.dart';
import '../../config/theme.dart';

/// Digital Twin V3 — Super Intelligence Edition
/// • Causal Driver Badges (Labs/Wearables links)
/// • Active Modifiers (Interactively flatten the curve)
/// • Touch-scrub crosshair + haptics
/// • Time-travel slider (circadian)
class SimulationCard extends StatefulWidget {
  final SimulationResult simulation;
  const SimulationCard({super.key, required this.simulation});

  @override
  State<SimulationCard> createState() => _SimulationCardState();
}

class _SimulationCardState extends State<SimulationCard> {
  bool _expanded = false;
  bool _reasoningExpanded = false;
  double _selectedHour = -1; // -1 = current time
  final Set<String> _activeModifiers = {}; // Track active mitigations (Super Intelligence)

  static const _presets = [
    _TimePreset("Morning",  "7 AM",  7,  "☀️", "Peak insulin sensitivity"),
    _TimePreset("Lunch",    "12 PM", 12, "🍽️", "Best metabolic window"),
    _TimePreset("Dinner",   "7 PM",  19, "🌆", "Poor glucose clearance"),
    _TimePreset("Late",     "11 PM", 23, "🌙", "Worst — fat storage mode"),
  ];

  @override
  void initState() {
    super.initState();
    _selectedHour = DateTime.now().hour.toDouble();
  }

  Color _riskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'low': return const Color(0xFF34C759);
      case 'moderate': return const Color(0xFFFF9500);
      case 'high': return const Color(0xFFFF3B30);
      default: return const Color(0xFF8E8E93);
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'positive': return const Color(0xFF34C759);
      case 'neutral': return const Color(0xFF8E8E93);
      case 'negative': return const Color(0xFFFF9500);
      case 'critical': return const Color(0xFFFF3B30);
      default: return const Color(0xFF8E8E93);
    }
  }

  /// Circadian multiplier — how much the glucose spike amplifies at a given hour.
  double _circadianMultiplier(double hour) {
    if (hour >= 6 && hour < 10) return 1.0;       // Morning
    if (hour >= 10 && hour < 14) return 0.85;      // Midday (peak sensitivity)
    if (hour >= 14 && hour < 18) return 1.15;      // Afternoon
    if (hour >= 18 && hour < 22) return 1.35;      // Evening
    return 1.50;                                    // Night (worst)
  }

  /// Apply circadian multiplier AND active modifiers to a curve.
  List<CurvePoint> _adjustCurve(List<CurvePoint> original, double baseline, Map<String, double> mitigationEffects) {
    final origHour = DateTime.now().hour.toDouble();
    final origMult = _circadianMultiplier(origHour);
    final newMult = _circadianMultiplier(_selectedHour);
    final circadianRatio = newMult / origMult;

    // Calculate mitigation multiplier (e.g., -15% = 0.85)
    double mitigationPower = 0.0;
    for (var mod in _activeModifiers) {
      mitigationPower += (mitigationEffects[mod] ?? 0.0);
    }
    final mitigationRatio = (1.0 + (mitigationPower / 100.0)).clamp(0.5, 1.5);

    return original.map((p) {
      final delta = p.value - baseline;
      return CurvePoint(time: p.time, value: baseline + delta * circadianRatio * mitigationRatio);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sim = widget.simulation;
    final riskColor = _riskColor(sim.riskLevel);

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.nc.cardBorder, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ━━━ COMPACT HEADER ━━━
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text("Projected Prediction", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: riskColor, letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: riskColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                              child: Text(
                                sim.riskLevel[0].toUpperCase() + sim.riskLevel.substring(1),
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: riskColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sim.verdict,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.nc.textPrimary, height: 1.3, letterSpacing: -0.3),
                          maxLines: _expanded ? 5 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_expanded && sim.causalDrivers.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: sim.causalDrivers.map((d) => _buildCausalBadge(d)).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: context.nc.textTertiary),
                  ),
                ],
              ),
            ),

            // ━━━ EXPANDED ━━━
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpanded(sim),
              crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(SimulationResult sim) {
    final metrics = [sim.glucose, sim.insulin, sim.sleep, sim.energy, sim.inflammation]
        .where((m) => m.label.isNotEmpty)
        .toList();

    // Apply circadian and mitigation adjustment
    final originalGlucose = _adjustCurve(sim.glucoseCurve, sim.baselineGlucose, {}); // Just circadian
    final adjustedGlucose = _adjustCurve(sim.glucoseCurve, sim.baselineGlucose, sim.mitigationEffects);
    final adjustedEnergy = sim.energyCurve; 

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          if (sim.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(sim.summary, style: TextStyle(fontSize: 14, color: context.nc.textSecondary, height: 1.5, letterSpacing: -0.2)),
            ),

          // ━━━ GRAPH INSIGHT ━━━
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.nc.inputFill,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.nc.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.activity, size: 18, color: context.nc.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getGraphInsight(adjustedGlucose, sim.timescale),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.nc.textPrimary, letterSpacing: -0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ━━━ GLUCOSE PREDICTION GRAPH ━━━
        if (sim.glucoseCurve.isNotEmpty) ...[
          Divider(height: 0.5, color: context.nc.divider),
          _InteractiveGraph(
            title: sim.timescale == '3h' ? "Glucose Response" : sim.glucose.label,
            unit: sim.timescale == '3h' ? "mg/dL" : "",
            curve: adjustedGlucose,
            compareCurve: sim.isComparison 
                ? sim.compareGlucoseCurve 
                : (_activeModifiers.isNotEmpty ? originalGlucose : null),
            baseline: sim.timescale == '3h' ? sim.baselineGlucose : null,
            timescale: sim.timescale,
            curveColor: const Color(0xFFFF9500),
            compareColor: _activeModifiers.isNotEmpty ? const Color(0xFF8E8E93).withOpacity(0.4) : const Color(0xFF34C759),
            baselineColor: const Color(0xFF34C759),
            primaryLabel: _activeModifiers.isNotEmpty ? "Mitigated" : (sim.primaryLabel.isNotEmpty ? sim.primaryLabel : "Predicted"),
            compareLabel: _activeModifiers.isNotEmpty ? "Original" : sim.compareLabel,
            isMitigationMode: _activeModifiers.isNotEmpty,
          ),
        ],

        // ━━━ ENERGY PREDICTION GRAPH ━━━
        if (sim.energyCurve.isNotEmpty) ...[
          Divider(height: 0.5, color: context.nc.divider),
          _InteractiveGraph(
            title: sim.timescale == '3h' ? "Energy Level" : sim.energy.label,
            unit: sim.timescale == '3h' ? "%" : "",
            curve: adjustedEnergy,
            compareCurve: sim.isComparison ? sim.compareEnergyCurve : null,
            baseline: null,
            timescale: sim.timescale,
            curveColor: const Color(0xFF007AFF),
            compareColor: const Color(0xFF34C759),
            baselineColor: const Color(0xFF34C759),
            primaryLabel: sim.primaryLabel.isNotEmpty ? sim.primaryLabel : "Predicted",
            compareLabel: sim.compareLabel,
          ),
        ],

        // ━━━ TIME-TRAVEL & MITIGATION (only for 3h metabolic) ━━━
        if (sim.glucoseCurve.isNotEmpty && sim.timescale == '3h') ...[
          Divider(height: 0.5, color: context.nc.divider),
          _buildTimeTravelSlider(adjustedGlucose, sim.baselineGlucose),
          if (sim.mitigationEffects.isNotEmpty) ...[
            const Divider(height: 0.5, indent: 16, endIndent: 16),
            _buildMitigationBar(sim.mitigationEffects),
          ],
        ],

        Divider(height: 0.5, color: context.nc.divider),

        // Metrics
        ...List.generate(metrics.length, (i) {
          final metric = metrics[i];
          final color = _severityColor(metric.severity);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metric.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: context.nc.textSecondary, letterSpacing: -0.1)),
                    const SizedBox(height: 2),
                    Text(metric.prediction, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color, letterSpacing: -0.3)),
                    if (metric.detail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(metric.detail, style: TextStyle(fontSize: 12, color: context.nc.textTertiary, height: 1.4, letterSpacing: -0.1)),
                    ],
                  ],
                ),
              ),
              if (i < metrics.length - 1)
                Divider(height: 0.5, indent: 16, endIndent: 16, color: context.nc.divider),
            ],
          );
        }),

        // Recommendations
        if (sim.recommendations.isNotEmpty) ...[
          Divider(height: 0.5, color: context.nc.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text("What You Can Do", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.nc.textPrimary, letterSpacing: -0.1)),
          ),
          ...List.generate(sim.recommendations.length, (i) {
            final rec = sim.recommendations[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("•  ", style: TextStyle(fontSize: 14, color: Color(0xFF34C759), fontWeight: FontWeight.w700)),
                  Expanded(child: Text(rec, style: TextStyle(fontSize: 14, color: context.nc.textPrimary, height: 1.4, letterSpacing: -0.2))),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],

        // Reasoning
        if (sim.reasoning.isNotEmpty) ...[
          Divider(height: 0.5, color: context.nc.divider),
          GestureDetector(
            onTap: () => setState(() => _reasoningExpanded = !_reasoningExpanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Expanded(child: Text("Scientific Reasoning", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.nc.textPrimary, letterSpacing: -0.1))),
                  AnimatedRotation(
                    turns: _reasoningExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: context.nc.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(sim.reasoning, style: TextStyle(fontSize: 13, color: context.nc.textSecondary, height: 1.6, letterSpacing: -0.1)),
            ),
            crossFadeState: _reasoningExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ],
    );
  }

  Widget _buildCausalBadge(CausalDriver driver) {
    final color = driver.impact == 'positive'
        ? const Color(0xFF34C759)
        : driver.impact == 'negative'
            ? const Color(0xFFFF3B30)
            : const Color(0xFF8E8E93);
    final icon = driver.source == 'lab'
        ? LucideIcons.testTube2
        : driver.source == 'wearable'
            ? LucideIcons.watch
            : LucideIcons.user;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            "${driver.label}: ${driver.value}",
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color, letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildMitigationBar(Map<String, double> effects) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck, size: 16, color: Color(0xFF34C759)),
              const SizedBox(width: 6),
              Text("Mitigation (Flatten the Curve)",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.nc.textPrimary, letterSpacing: -0.3)),
              const Spacer(),
              if (_activeModifiers.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _activeModifiers.clear()),
                  child: const Text("Reset", style: TextStyle(fontSize: 12, color: Color(0xFF007AFF), fontWeight: FontWeight.w500)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: effects.keys.map((label) {
                final isSelected = _activeModifiers.contains(label);
                final impact = effects[label]!;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        if (isSelected) {
                          _activeModifiers.remove(label);
                        } else {
                          _activeModifiers.add(label);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF34C759) : context.nc.inputFill,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isSelected ? [BoxShadow(color: const Color(0xFF34C759).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))] : null,
                      ),
                      child: Row(
                        children: [
                          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : context.nc.textPrimary)),
                          const SizedBox(width: 6),
                          Text("${impact.toInt()}%", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white.withOpacity(0.8) : context.nc.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeTravelSlider(List<CurvePoint> currentCurve, double baseline) {
    final mult = _circadianMultiplier(_selectedHour);

    String riskLabel;
    Color riskColor;
    if (mult <= 0.9) { riskLabel = "Optimal Window"; riskColor = const Color(0xFF34C759); }
    else if (mult <= 1.05) { riskLabel = "Normal Window"; riskColor = const Color(0xFF8E8E93); }
    else if (mult <= 1.2) { riskLabel = "Elevated Risk"; riskColor = const Color(0xFFFF9500); }
    else { riskLabel = "High Risk"; riskColor = const Color(0xFFFF3B30); }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: context.nc.textSecondary),
              const SizedBox(width: 6),
              Text("When should I eat this?",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.nc.textPrimary, letterSpacing: -0.3)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(riskLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: riskColor, letterSpacing: -0.2)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ━━━ PRESET CHIPS ━━━
          Row(
            children: _presets.map((preset) {
              final isSelected = (_selectedHour - preset.hour).abs() < 2;
              final presetMult = _circadianMultiplier(preset.hour.toDouble());
              final chipColor = presetMult <= 0.9
                  ? const Color(0xFF34C759)
                  : presetMult <= 1.05
                      ? const Color(0xFF8E8E93)
                      : presetMult <= 1.2
                          ? const Color(0xFFFF9500)
                          : const Color(0xFFFF3B30);

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _selectedHour = preset.hour.toDouble());
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? chipColor.withOpacity(0.12) : context.nc.inputFill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? chipColor.withOpacity(0.4) : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(preset.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 4),
                        Text(preset.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? chipColor : context.nc.textSecondary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(preset.time,
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? chipColor.withOpacity(0.7) : context.nc.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // ━━━ FINE-TUNE SLIDER ━━━
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: riskColor,
              inactiveTrackColor: context.nc.inputFill,
              thumbColor: context.nc.cardSurface,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7, elevation: 2),
              overlayColor: riskColor.withOpacity(0.08),
              trackHeight: 3,
            ),
            child: Slider(
              min: 0,
              max: 23,
              divisions: 23,
              value: _selectedHour,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _selectedHour = v);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("12 AM", style: TextStyle(fontSize: 9, color: context.nc.textTertiary)),
                Text("6 AM",  style: TextStyle(fontSize: 9, color: context.nc.textTertiary)),
                Text("12 PM", style: TextStyle(fontSize: 9, color: context.nc.textTertiary)),
                Text("6 PM",  style: TextStyle(fontSize: 9, color: context.nc.textTertiary)),
                Text("11 PM", style: TextStyle(fontSize: 9, color: context.nc.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGraphInsight(List<CurvePoint> curve, String timescale) {
    if (curve.isEmpty) return "No data available.";
    double maxVal = curve.map((p) => p.value).reduce(max);
    double startVal = curve.first.value;
    final delta = maxVal - startVal;

    if (timescale == '3h') {
      if (maxVal > 160) return "⚠️ Significant Spike: Projected to reach ${maxVal.toInt()} mg/dL.";
      if (delta < 20) return "✅ Stable Response: Minimal metabolic impact projected.";
      return "Normal Response: Reaches ${maxVal.toInt()} mg/dL (Peak).";
    }
    return "Trajectory is stable across the $timescale horizon.";
  }
}

class _InteractiveGraph extends StatefulWidget {
  final String title;
  final String unit;
  final List<CurvePoint> curve;
  final List<CurvePoint>? compareCurve;
  final double? baseline;
  final String timescale;
  final Color curveColor;
  final Color compareColor;
  final Color baselineColor;
  final String primaryLabel;
  final String compareLabel;
  final bool isMitigationMode;

  const _InteractiveGraph({
    required this.title, required this.unit, required this.curve,
    this.compareCurve, this.baseline, this.timescale = '3h',
    required this.curveColor, required this.compareColor, required this.baselineColor,
    required this.primaryLabel, required this.compareLabel,
    this.isMitigationMode = false,
  });

  @override
  State<_InteractiveGraph> createState() => _InteractiveGraphState();
}

class _InteractiveGraphState extends State<_InteractiveGraph> {
  double? _touchX;
  bool _isTouching = false;

  void _handleTouch(Offset localPosition, double width) {
    setState(() => _touchX = localPosition.dx.clamp(0.0, width));
  }

  @override
  Widget build(BuildContext context) {
    final allValues = [
      ...widget.curve.map((p) => p.value),
      if (widget.compareCurve != null) ...widget.compareCurve!.map((p) => p.value),
      if (widget.baseline != null) widget.baseline!,
    ];
    final maxVal = allValues.reduce(max) + 10;
    final minVal = allValues.reduce(min) - 10;
    final peakPoint = widget.curve.isEmpty ? CurvePoint(time: 0, value: 0) : widget.curve.reduce((a, b) => a.value > b.value ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(widget.timescale, style: TextStyle(fontSize: 11, color: context.nc.textTertiary)),
            ],
          ),
          const SizedBox(height: 4),
          if (widget.curve.isNotEmpty)
            Text("Peak: ${peakPoint.value.toInt()} ${widget.unit}", style: TextStyle(fontSize: 12, color: widget.curveColor, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            return GestureDetector(
              onPanUpdate: (d) => _handleTouch(d.localPosition, constraints.maxWidth),
              onPanStart: (d) { HapticFeedback.lightImpact(); setState(() => _isTouching = true); _handleTouch(d.localPosition, constraints.maxWidth); },
              onPanEnd: (_) => setState(() { _isTouching = false; _touchX = null; }),
              child: SizedBox(
                height: 130,
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 130),
                  painter: _DualCurvePainter(
                    curve: widget.curve,
                    compareCurve: widget.compareCurve,
                    baseline: widget.baseline,
                    curveColor: widget.curveColor,
                    compareColor: widget.compareColor,
                    baselineColor: widget.baselineColor,
                    minVal: minVal, maxVal: maxVal,
                    touchX: _touchX, isTouching: _isTouching,
                    unit: widget.unit,
                    primaryLabel: widget.primaryLabel,
                    compareLabel: widget.compareLabel,
                    isMitigationMode: widget.isMitigationMode,
                    gridColor: context.nc.cardBorder,
                    labelColor: context.nc.textSecondary,
                    dividerColor: context.nc.divider,
                    surfaceColor: context.nc.cardSurface,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.curveColor, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(widget.primaryLabel, style: TextStyle(fontSize: 10, color: context.nc.textSecondary)),
        if (widget.compareCurve != null) ...[
          const SizedBox(width: 12),
          Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.compareColor.withOpacity(0.5), shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(widget.compareLabel, style: TextStyle(fontSize: 10, color: context.nc.textSecondary)),
        ],
      ],
    );
  }
}

class _DualCurvePainter extends CustomPainter {
  final List<CurvePoint> curve;
  final List<CurvePoint>? compareCurve;
  final double? baseline;
  final Color curveColor;
  final Color compareColor;
  final Color baselineColor;
  final double minVal;
  final double maxVal;
  final double? touchX;
  final bool isTouching;
  final String unit;
  final String primaryLabel;
  final String compareLabel;
  final bool isMitigationMode;
  final Color gridColor;
  final Color labelColor;
  final Color dividerColor;
  final Color surfaceColor;

  _DualCurvePainter({
    required this.curve, required this.compareCurve, required this.baseline,
    required this.curveColor, required this.compareColor, required this.baselineColor,
    required this.minVal, required this.maxVal, required this.touchX,
    required this.isTouching, required this.unit,
    required this.primaryLabel, required this.compareLabel,
    required this.gridColor, required this.labelColor,
    required this.dividerColor, required this.surfaceColor,
    this.isMitigationMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (curve.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final maxTime = curve.last.time;
    final valRange = maxVal - minVal;
    if (valRange == 0) return;

    double tx(double t) => (t / maxTime) * w;
    double ty(double v) => h - ((v - minVal) / valRange) * h;

    // Draw grid lines and labels
    final int gridLines = 3;
    final textStyle = TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.w500);
    
    for (int i = 0; i < gridLines; i++) {
      double y = h - (i / (gridLines - 1)) * h;
      double val = minVal + (i / (gridLines - 1)) * valRange;
      
      canvas.drawLine(Offset(0, y), Offset(w, y), Paint()..color = gridColor..strokeWidth = 0.5);
      
      final textSpan = TextSpan(text: '${val.toInt()}', style: textStyle);
      final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, Offset(2, y > 10 ? y - textPainter.height - 2 : y + 2));
    }

    if (baseline != null) {
      final paint = Paint()..color = baselineColor.withOpacity(0.2)..strokeWidth = 1;
      double y = ty(baseline!);
      for (double x = 0; x < w; x += 8) { canvas.drawLine(Offset(x, y), Offset(min(x+4, w), y), paint); }
    }

    if (compareCurve != null) {
      _drawCurve(canvas, size, compareCurve!, compareColor, tx, ty, isSecondary: true, dashed: isMitigationMode);
    }
    _drawCurve(canvas, size, curve, curveColor, tx, ty, isSecondary: false);

    if (isTouching && touchX != null) {
      final time = (touchX! / w) * maxTime;
      final val = _interpolate(curve, time);
      final y = ty(val);
      canvas.drawLine(Offset(touchX!, 0), Offset(touchX!, h), Paint()..color = dividerColor);
      canvas.drawCircle(Offset(touchX!, y), 5, Paint()..color = curveColor);
      canvas.drawCircle(Offset(touchX!, y), 3, Paint()..color = surfaceColor);
    }
  }

  void _drawCurve(Canvas canvas, Size size, List<CurvePoint> points, Color color,
      double Function(double) tx, double Function(double) ty, 
      {required bool isSecondary, bool dashed = false}) {
    final path = Path();
    path.moveTo(tx(points.first.time), ty(points.first.value));
    for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1]; final curr = points[i];
        final cpx1 = tx(prev.time) + (tx(curr.time) - tx(prev.time)) * 0.5;
        path.cubicTo(cpx1, ty(prev.value), cpx1, ty(curr.value), tx(curr.time), ty(curr.value));
    }

    if (dashed) {
      final paint = Paint()..color = color.withOpacity(0.4)..strokeWidth = 1.5..style = PaintingStyle.stroke;
      for (final metric in path.computeMetrics()) {
        double dist = 0;
        while (dist < metric.length) { canvas.drawPath(metric.extractPath(dist, dist+4), paint); dist += 8; }
      }
    } else {
      canvas.drawPath(path, Paint()..color = color..strokeWidth = isSecondary ? 1.5 : 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
      final fill = Path.from(path)..lineTo(tx(points.last.time), size.height)..lineTo(tx(points.first.time), size.height)..close();
      canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withOpacity(0.1), color.withOpacity(0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    }
  }

  double _interpolate(List<CurvePoint> points, double t) {
    if (points.isEmpty) return 0;
    for (int i = 1; i < points.length; i++) {
      if (points[i].time >= t) {
        final ratio = (t - points[i-1].time) / (points[i].time - points[i-1].time);
        return points[i-1].value + (points[i].value - points[i-1].value) * ratio;
      }
    }
    return points.last.value;
  }

  @override
  bool shouldRepaint(covariant _DualCurvePainter old) =>
      old.curve != curve ||
      old.compareCurve != compareCurve ||
      old.touchX != touchX ||
      old.isTouching != isTouching ||
      old.minVal != minVal ||
      old.maxVal != maxVal;
}

class _TimePreset {
  final String label; final String time; final int hour; final String emoji; final String description;
  const _TimePreset(this.label, this.time, this.hour, this.emoji, this.description);
}
