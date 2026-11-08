// Baseline-vs-latest comparison for the Progress tab (client mockup: four
// cards per segment, each "baseline → latest" with the change).
//
// Values come only from stored scan measures (dexa_measures.dart keys). No
// ranges, categories or "good/bad" direction are added here; the change is a
// neutral arrow and size, coloured neutrally by the UI.
library;

import 'body_composition.dart';

class DexaCompareMetric {
  const DexaCompareMetric(this.label, this.keys, this.unit, {this.decimals = 1});

  final String label;

  /// First key present in a scan wins (lets a card fall back, e.g. visceral
  /// fat mass, then visceral fat area).
  final List<String> keys;
  final String unit;
  final int decimals;
}

/// The segment pills on Progress, in mockup order, and their four cards.
const Map<String, List<DexaCompareMetric>> dexaSegments = {
  'Total': [
    DexaCompareMetric('Total Body Fat', ['body_fat_pct'], '%'),
    DexaCompareMetric('Visceral Fat', ['visceral_fat_mass_lb', 'vat_area_cm2'], 'lb'),
    DexaCompareMetric('Lean Mass', ['lean_mass_lb'], 'lb'),
    DexaCompareMetric('Bone Density', ['bone_mineral_density_g_cm2'], 'g/cm²', decimals: 2),
  ],
  'Lean Mass': [
    DexaCompareMetric('Lean Mass', ['lean_mass_lb'], 'lb'),
    DexaCompareMetric('Arms & Legs', ['appendicular_lean_mass_lb'], 'lb'),
    DexaCompareMetric('Muscle Index', ['almi_kg_m2'], 'kg/m²', decimals: 2),
    DexaCompareMetric('Lean Mass Index', ['lean_mass_index_kg_m2'], 'kg/m²'),
  ],
  'Fat Mass': [
    DexaCompareMetric('Fat Mass', ['fat_mass_lb'], 'lb'),
    DexaCompareMetric('Body Fat', ['body_fat_pct'], '%'),
    DexaCompareMetric('Trunk Fat', ['trunk_fat_pct'], '%'),
    DexaCompareMetric('Fat Mass Index', ['fat_mass_index_kg_m2'], 'kg/m²'),
  ],
  'Visceral Fat': [
    DexaCompareMetric('Visceral Fat Area', ['vat_area_cm2'], 'cm²', decimals: 0),
    DexaCompareMetric('Visceral Fat Mass', ['visceral_fat_mass_lb'], 'lb'),
    DexaCompareMetric('Android / Gynoid', ['android_gynoid_ratio'], '', decimals: 2),
    DexaCompareMetric('Trunk Fat', ['trunk_fat_pct'], '%'),
  ],
};

class DexaCompareRow {
  const DexaCompareRow({
    required this.label,
    required this.latest,
    this.baseline,
    this.change,
  });

  final String label;

  /// Formatted with unit, e.g. "22.1%" or "58.1 lb".
  final String latest;
  final String? baseline;

  /// e.g. "↓ 6.3%" (relative change), "Stable", or null with one scan.
  final String? change;
}

/// Oldest and newest scans by `scan_date` (ISO dates sort as strings).
({StoredBodyScan? baseline, StoredBodyScan? latest}) baselineAndLatest(List<StoredBodyScan> scans) {
  if (scans.isEmpty) return (baseline: null, latest: null);
  final sorted = [...scans]..sort((a, b) => a.scanDate.compareTo(b.scanDate));
  final latest = sorted.last;
  final baseline = sorted.length > 1 ? sorted.first : null;
  return (baseline: baseline, latest: latest);
}

double? _value(StoredBodyScan scan, String key) {
  for (final m in scan.measures) {
    if (m.name == key) return double.tryParse(m.value.trim());
  }
  return null;
}

String _fmt(double v, DexaCompareMetric m, String unit) {
  final n = v.toStringAsFixed(m.decimals);
  if (unit.isEmpty) return n;
  if (unit == '%') return '$n%';
  return '$n $unit';
}

/// Rows for one segment. A metric is skipped when the latest scan lacks it.
List<DexaCompareRow> compareSegment(String segment, StoredBodyScan latest, StoredBodyScan? baseline) {
  final metrics = dexaSegments[segment] ?? const [];
  final out = <DexaCompareRow>[];
  for (final m in metrics) {
    String? key;
    double? now;
    for (final k in m.keys) {
      now = _value(latest, k);
      if (now != null) {
        key = k;
        break;
      }
    }
    if (key == null || now == null) continue;
    final unit = key == 'vat_area_cm2' ? 'cm²' : m.unit;
    final then = baseline == null ? null : _value(baseline, key);
    String? change;
    if (then != null) {
      final a = then.toStringAsFixed(m.decimals);
      final b = now.toStringAsFixed(m.decimals);
      if (a == b || then == 0) {
        change = a == b ? 'Stable' : null;
      } else if (unit == '%') {
        // Percent measures change in points (28.4% -> 22.1% is "↓ 6.3%").
        change = '${now > then ? '↑' : '↓'} ${(now - then).abs().toStringAsFixed(m.decimals)}%';
      } else {
        final pct = ((now - then).abs() / then.abs() * 100);
        change = '${now > then ? '↑' : '↓'} ${pct.toStringAsFixed(1)}%';
      }
    }
    out.add(DexaCompareRow(
      label: m.label,
      latest: _fmt(now, m, unit),
      baseline: then == null ? null : _fmt(then, m, unit),
      change: change,
    ));
  }
  return out;
}
