// ─────────────────────────────────────────────────────────────────────────────
//  BioAge Calculator
//  Algorithm: Biological Age from Blood Biomarkers
//
//  Scientific basis:
//    Based on the Biomarker Deviation method, adapted from:
//    - Levine et al., 2018 (PhenoAge, Clinical Chemistry)
//    - Klemera & Doubal, 2006 (Mechanisms of Ageing and Development)
//
//  Method:
//    1. Identify key longevity-related biomarkers from the user's lab reports.
//    2. For each available marker, compute a *deviation score* from the optimal range:
//         - 0.0 = perfectly in the optimal zone
//         - up to ±2.0 = significantly outside optimal range
//    3. Aggregate the deviation into an "aging surplus / deficit" in years.
//    4. Apply this as a delta to the user's chronological age.
//    5. If fewer than MINIMUM_MARKERS_REQUIRED markers are found, return null.
//
//  Result:
//    An estimated biological age (int) in years, or null if data is insufficient.
// ─────────────────────────────────────────────────────────────────────────────

import '../models/lab_report.dart';

/// Minimum number of biomarkers required to make a meaningful calculation.
const int _kMinMarkers = 3;

/// Max age adjustment an individual marker can contribute (in years).
const double _kMaxYearsPerMarker = 2.5;

class _MarkerConfig {
  final String name;
  final List<String> aliases;
  final double optimalMin;
  final double optimalMax;
  /// If true, values below optimalMin are "bad". If false, values above optimalMax are "bad".
  final bool higherIsBetter;
  /// How many years does 1 unit of deviation from the optimal range add to bio-age?
  /// This is calibrated so all markers contribute roughly equally.
  final double agingWeightPerUnit;

  const _MarkerConfig({
    required this.name,
    required this.aliases,
    required this.optimalMin,
    required this.optimalMax,
    this.higherIsBetter = false,
    required this.agingWeightPerUnit,
  });
}

/// Biomarker lookup table with longevity-relevant weights.
/// References:
///  - Glucose aging weight from Nguyen et al., 2023 (glucose variability & biological aging)
///  - HbA1c from Levine et al. PhenoAge panel
///  - HDL from Levine et al. PhenoAge panel (protective factor)
///  - LDL from AHA guidelines & aging research
///  - Triglycerides from metabolic syndrome literature
///  - Creatinine (kidney function) from Levine et al. PhenoAge panel
///  - ALT (liver function) from Levine et al. PhenoAge panel
///  - Hemoglobin from Levine et al. PhenoAge panel
///  - TSH (thyroid) from longevity endocrinology literature
///  - Vitamin D from GrassrootsHealth & longevity cohort studies
const List<_MarkerConfig> _kMarkers = [
  _MarkerConfig(
    name: 'Glucose',
    aliases: ['blood glucose', 'fasting glucose', 'fbs', 'blood sugar', 'glucose'],
    optimalMin: 70,
    optimalMax: 85,
    agingWeightPerUnit: 0.12, // ~1.2 years per 10 mg/dL above optimal
  ),
  _MarkerConfig(
    name: 'HbA1c',
    aliases: ['hemoglobin a1c', 'glycated hemoglobin', 'a1c', 'hba1c'],
    optimalMin: 4.5,
    optimalMax: 5.4,
    agingWeightPerUnit: 1.5, // each % above optimal = ~1.5 years aging
  ),
  _MarkerConfig(
    name: 'HDL Cholesterol',
    aliases: ['hdl', 'hdl-c', 'high density lipoprotein'],
    optimalMin: 60,
    optimalMax: 100,
    higherIsBetter: true,
    agingWeightPerUnit: 0.08, // per mg/dL below 60 = small aging effect
  ),
  _MarkerConfig(
    name: 'LDL Cholesterol',
    aliases: ['ldl', 'ldl-c', 'low density lipoprotein', 'ldl cholesterol'],
    optimalMin: 0,
    optimalMax: 100,
    agingWeightPerUnit: 0.06, // per mg/dL above 100
  ),
  _MarkerConfig(
    name: 'Triglycerides',
    aliases: ['tg', 'trigs', 'triglycerides'],
    optimalMin: 0,
    optimalMax: 100,
    agingWeightPerUnit: 0.04, // per mg/dL above 100
  ),
  _MarkerConfig(
    name: 'Creatinine',
    aliases: ['serum creatinine', 'creatinine', 'cr'],
    optimalMin: 0.6,
    optimalMax: 1.0,
    agingWeightPerUnit: 2.5, // per mg/dL above 1.0 (kidney decline = accelerated aging)
  ),
  _MarkerConfig(
    name: 'ALT',
    aliases: ['alanine aminotransferase', 'alt', 'sgpt'],
    optimalMin: 0,
    optimalMax: 25,
    agingWeightPerUnit: 0.06, // per U/L above 25 (liver health)
  ),
  _MarkerConfig(
    name: 'Hemoglobin',
    aliases: ['hemoglobin', 'hgb', 'hb', 'haemoglobin'],
    optimalMin: 13.5,
    optimalMax: 17.5,
    higherIsBetter: true,
    agingWeightPerUnit: 0.4, // per g/dL below 13.5 (oxygen delivery)
  ),
  _MarkerConfig(
    name: 'TSH',
    aliases: ['thyroid stimulating hormone', 'tsh'],
    optimalMin: 1.0,
    optimalMax: 2.5,
    agingWeightPerUnit: 0.8, // per mIU/L outside optimal range
  ),
  _MarkerConfig(
    name: 'Vitamin D',
    aliases: ['25-oh vitamin d', '25-hydroxyvitamin d', 'vit d', 'vitamin d', 'vitamin d3'],
    optimalMin: 50,
    optimalMax: 80,
    higherIsBetter: true,
    agingWeightPerUnit: 0.08, // per ng/mL below 50 (immune & longevity)
  ),
];

/// Calculates an estimated biological age from a list of lab reports.
///
/// Returns null if insufficient markers are available to make a calculation.
int? calculateBioAgeFromLabs(List<LabReport> reports, int chronologicalAge) {
  if (reports.isEmpty) return null;

  // Flatten all markers into one lookup map: normalizedName → numericValue
  final Map<String, double> markerValues = {};
  for (final report in reports) {
    for (final marker in report.markers) {
      final key = marker.name.trim().toLowerCase();
      final val = double.tryParse(marker.value.replaceAll(RegExp(r'[^0-9.]'), ''));
      if (val != null) {
        markerValues[key] = val;
      }
    }
  }

  if (markerValues.isEmpty) return null;

  double totalAgingDelta = 0.0;
  int markersFound = 0;

  for (final config in _kMarkers) {
    // Try to find marker by primary name or any alias
    double? value;
    final allKeys = [config.name.toLowerCase(), ...config.aliases.map((a) => a.toLowerCase())];
    for (final key in allKeys) {
      if (markerValues.containsKey(key)) {
        value = markerValues[key];
        break;
      }
    }

    if (value == null) continue;
    markersFound++;

    double deviationYears;
    if (config.higherIsBetter) {
      // Low values age you
      final deficit = (config.optimalMin - value).clamp(0.0, double.infinity);
      deviationYears = deficit * config.agingWeightPerUnit;
    } else {
      // High values age you (below optimalMax is fine)
      final excess = (value - config.optimalMax).clamp(0.0, double.infinity);
      deviationYears = excess * config.agingWeightPerUnit;

      // Additionally, for markers with an optimalMin that can go too low (like TSH, glucose)
      if (config.optimalMin > 0 && value < config.optimalMin) {
        final deficit = (config.optimalMin - value).clamp(0.0, double.infinity);
        deviationYears = deficit * config.agingWeightPerUnit;
      }
    }

    // Cap each marker's contribution
    totalAgingDelta += deviationYears.clamp(0.0, _kMaxYearsPerMarker);
  }

  if (markersFound < _kMinMarkers) return null;

  // Apply the delta to chronological age, clamped to realistic bounds
  final computed = (chronologicalAge + totalAgingDelta).round();
  return computed.clamp(chronologicalAge - 20, chronologicalAge + 30);
}
