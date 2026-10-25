/// Represents the output of a Digital Twin metabolic simulation.
class SimulationResult {
  final String verdict;
  final String riskLevel;
  final String summary;

  // --- Impact Metrics ---
  final MetricImpact glucose;
  final MetricImpact insulin;
  final MetricImpact sleep;
  final MetricImpact energy;
  final MetricImpact inflammation;

  // --- Prediction Curves ---
  final List<CurvePoint> glucoseCurve;
  final List<CurvePoint> energyCurve;
  final double baselineGlucose;
  final String timescale; // e.g., "3h", "7d", "1y", "10y"

  // --- Compare Mode (A/B) ---
  final List<CurvePoint> compareGlucoseCurve;
  final List<CurvePoint> compareEnergyCurve;
  final String compareLabel;   
  final String primaryLabel;   

  // --- Causal & Mitigation (Super Intelligence) ---
  final List<CausalDriver> causalDrivers;
  final Map<String, double> mitigationEffects; // e.g., {'+10m Walk': -15.0}

  // --- Recommendations & Reasoning ---
  final List<String> recommendations;
  final String reasoning;

  SimulationResult({
    required this.verdict,
    required this.riskLevel,
    required this.summary,
    required this.glucose,
    required this.insulin,
    required this.sleep,
    required this.energy,
    required this.inflammation,
    this.glucoseCurve = const [],
    this.energyCurve = const [],
    this.baselineGlucose = 95,
    this.timescale = '3h',
    this.compareGlucoseCurve = const [],
    this.compareEnergyCurve = const [],
    this.compareLabel = '',
    this.primaryLabel = '',
    this.causalDrivers = const [],
    this.mitigationEffects = const {},
    required this.recommendations,
    required this.reasoning,
  });

  bool get isComparison => compareGlucoseCurve.isNotEmpty;

  factory SimulationResult.fromJson(Map<String, dynamic> json) {
    return SimulationResult(
      verdict: json['verdict'] ?? 'Unknown Impact',
      riskLevel: json['risk_level'] ?? 'moderate',
      summary: json['summary'] ?? '',
      glucose: MetricImpact.fromJson(json['glucose'] ?? {}),
      insulin: MetricImpact.fromJson(json['insulin'] ?? {}),
      sleep: MetricImpact.fromJson(json['sleep'] ?? {}),
      energy: MetricImpact.fromJson(json['energy'] ?? {}),
      inflammation: MetricImpact.fromJson(json['inflammation'] ?? {}),
      glucoseCurve: _parseCurve(json['glucose_curve']),
      energyCurve: _parseCurve(json['energy_curve']),
      baselineGlucose: (json['baseline_glucose'] ?? 95).toDouble(),
      timescale: json['timescale'] ?? '3h',
      compareGlucoseCurve: _parseCurve(json['compare_glucose_curve']),
      compareEnergyCurve: _parseCurve(json['compare_energy_curve']),
      compareLabel: json['compare_label'] ?? '',
      primaryLabel: json['primary_label'] ?? '',
      causalDrivers: (json['causal_drivers'] as List?)
              ?.map((e) => CausalDriver.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      mitigationEffects: (json['mitigation_effects'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
          {},
      recommendations: (json['recommendations'] as List?)?.map((e) => e.toString()).toList() ?? [],
      reasoning: json['reasoning'] ?? '',
    );
  }

  static List<CurvePoint> _parseCurve(dynamic data) {
    if (data == null || data is! List) return [];
    return data.map((e) => CurvePoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'simulation',
      'verdict': verdict,
      'risk_level': riskLevel,
      'summary': summary,
      'glucose': glucose.toJson(),
      'insulin': insulin.toJson(),
      'sleep': sleep.toJson(),
      'energy': energy.toJson(),
      'inflammation': inflammation.toJson(),
      'glucose_curve': glucoseCurve.map((e) => e.toJson()).toList(),
      'energy_curve': energyCurve.map((e) => e.toJson()).toList(),
      'baseline_glucose': baselineGlucose,
      'timescale': timescale,
      'compare_glucose_curve': compareGlucoseCurve.map((e) => e.toJson()).toList(),
      'compare_energy_curve': compareEnergyCurve.map((e) => e.toJson()).toList(),
      'compare_label': compareLabel,
      'primary_label': primaryLabel,
      'causal_drivers': causalDrivers.map((e) => e.toJson()).toList(),
      'mitigation_effects': mitigationEffects,
      'recommendations': recommendations,
      'reasoning': reasoning,
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Digital Twin Simulation');
    buffer.writeln('_Risk Level: ${riskLevel.toUpperCase()}_\n');
    buffer.writeln('**Verdict:** $verdict\n');
    if (summary.isNotEmpty) {
      buffer.writeln('$summary\n');
    }

    buffer.writeln('## Projected Impact ($timescale)');
    buffer.writeln('- **Glucose:** ${glucose.prediction} (${glucose.severity})');
    buffer.writeln('- **Insulin:** ${insulin.prediction} (${insulin.severity})');
    buffer.writeln('- **Energy:** ${energy.prediction} (${energy.severity})');
    buffer.writeln('- **Sleep:** ${sleep.prediction} (${sleep.severity})');
    buffer.writeln('- **Inflammation:** ${inflammation.prediction} (${inflammation.severity})\n');

    if (causalDrivers.isNotEmpty) {
      buffer.writeln('## Causal Drivers');
      for (final driver in causalDrivers) {
        buffer.writeln('- **${driver.label}:** ${driver.value} (_${driver.impact}_ from ${driver.source})');
      }
      buffer.writeln('');
    }

    if (recommendations.isNotEmpty) {
      buffer.writeln('## Recommendations');
      for (final rec in recommendations) {
        buffer.writeln('- $rec');
      }
      buffer.writeln('');
    }

    if (reasoning.isNotEmpty) {
      buffer.writeln('## Clinical Reasoning');
      buffer.writeln('$reasoning\n');
    }

    return buffer.toString().trim();
  }
}


/// A biological driver that influences a prediction.
class CausalDriver {
  final String label;
  final String value;
  final String impact; // positive | negative | neutral
  final String source; // lab | wearable | profile

  CausalDriver({
    required this.label,
    required this.value,
    this.impact = 'neutral',
    this.source = 'profile',
  });

  factory CausalDriver.fromJson(Map<String, dynamic> json) {
    return CausalDriver(
      label: json['label'] ?? '',
      value: json['value'] ?? '',
      impact: json['impact'] ?? 'neutral',
      source: json['source'] ?? 'profile',
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'impact': impact,
        'source': source,
      };
}

/// A single impact metric within a simulation.
class MetricImpact {
  final String label;
  final String prediction;
  final String severity;
  final String detail;

  MetricImpact({
    required this.label,
    required this.prediction,
    required this.severity,
    required this.detail,
  });

  factory MetricImpact.fromJson(Map<String, dynamic> json) {
    return MetricImpact(
      label: json['label'] ?? '',
      prediction: json['prediction'] ?? 'N/A',
      severity: json['severity'] ?? 'neutral',
      detail: json['detail'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'prediction': prediction,
        'severity': severity,
        'detail': detail,
      };
}

/// A single point on a prediction curve (time in minutes, value).
class CurvePoint {
  final double time;
  final double value;

  CurvePoint({required this.time, required this.value});

  factory CurvePoint.fromJson(Map<String, dynamic> json) {
    return CurvePoint(
      time: (json['t'] ?? 0).toDouble(),
      value: (json['v'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        't': time,
        'v': value,
      };
}

