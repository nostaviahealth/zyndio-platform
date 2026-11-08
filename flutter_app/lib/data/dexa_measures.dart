/// How the Progress tab presents the measures stored on a DEXA scan.
///
/// The key list mirrors what a DEXAscan body-composition report contains
/// (overall score, mass and fat, muscle index, visceral fat, adipose / lean
/// indices, bone density, left/right symmetry) and the six fields the outcomes
/// engine already uses (weight_lb, fat_mass_lb, lean_mass_lb, body_fat_pct,
/// appendicular_lean_mass_lb, visceral_fat). The partner webhook contract in
/// docs/integrations/dexa-webhook-fields.md uses the same keys.
///
/// Values are shown exactly as stored with a unit; this file adds no ranges,
/// categories or interpretation (non-diagnostic, APP-06). Keys it does not
/// recognise are still shown, under "Other measures", so nothing the partner
/// sent is hidden.
library;

class DexaMeasureDef {
  const DexaMeasureDef(this.key, this.label, this.unit, this.section);

  final String key;
  final String label;
  final String unit;
  final DexaSection section;
}

enum DexaSection {
  overview('Overview'),
  muscle('Muscle'),
  fat('Fat'),
  bone('Bone'),
  symmetry('Left / right balance'),
  other('Other measures');

  const DexaSection(this.title);
  final String title;
}

const List<DexaMeasureDef> dexaMeasureDefs = [
  // Overview
  DexaMeasureDef('health_score', 'Overall health score', '/100', DexaSection.overview),
  DexaMeasureDef('total_mass_lb', 'Total mass', 'lb', DexaSection.overview),
  DexaMeasureDef('weight_lb', 'Weight', 'lb', DexaSection.overview),
  DexaMeasureDef('body_fat_pct', 'Body fat', '%', DexaSection.overview),
  DexaMeasureDef('lean_mass_lb', 'Lean mass', 'lb', DexaSection.overview),
  // Muscle
  DexaMeasureDef('almi_kg_m2', 'Muscle index (ALMI)', 'kg/m²', DexaSection.muscle),
  DexaMeasureDef('almi_percentile', 'ALMI percentile', '', DexaSection.muscle),
  DexaMeasureDef('almi_z_score', 'ALMI Z-score', '', DexaSection.muscle),
  DexaMeasureDef('almi_t_score', 'ALMI T-score', '', DexaSection.muscle),
  DexaMeasureDef('appendicular_lean_mass_lb', 'Arms and legs lean mass', 'lb', DexaSection.muscle),
  DexaMeasureDef('lean_mass_index_kg_m2', 'Lean mass index', 'kg/m²', DexaSection.muscle),
  // Fat
  DexaMeasureDef('fat_mass_lb', 'Total fat mass', 'lb', DexaSection.fat),
  DexaMeasureDef('trunk_fat_mass_lb', 'Trunk fat mass', 'lb', DexaSection.fat),
  DexaMeasureDef('trunk_fat_pct', 'Trunk fat', '%', DexaSection.fat),
  DexaMeasureDef('vat_area_cm2', 'Visceral fat area', 'cm²', DexaSection.fat),
  DexaMeasureDef('visceral_fat', 'Visceral fat', '', DexaSection.fat),
  DexaMeasureDef('visceral_fat_mass_lb', 'Visceral fat mass', 'lb', DexaSection.fat),
  DexaMeasureDef('fat_mass_index_kg_m2', 'Fat mass index', 'kg/m²', DexaSection.fat),
  DexaMeasureDef('android_gynoid_ratio', 'Android / gynoid ratio', '', DexaSection.fat),
  // Bone
  DexaMeasureDef('bone_t_score', 'Bone T-score', '', DexaSection.bone),
  DexaMeasureDef('bone_z_score', 'Bone Z-score', '', DexaSection.bone),
  DexaMeasureDef('bone_mineral_density_g_cm2', 'Bone mineral density', 'g/cm²', DexaSection.bone),
  DexaMeasureDef('bone_mineral_content_lb', 'Bone mineral content', 'lb', DexaSection.bone),
  // Symmetry
  DexaMeasureDef('arm_lean_difference_pct', 'Arms lean difference', '%', DexaSection.symmetry),
  DexaMeasureDef('leg_lean_difference_pct', 'Legs lean difference', '%', DexaSection.symmetry),
];

/// Stored keys that are metadata about another measure, not measures.
const _hiddenKeys = {'visceral_fat_unit'};

class DexaRow {
  const DexaRow(this.label, this.value);
  final String label;
  final String value;
}

class DexaGroup {
  const DexaGroup(this.section, this.rows);
  final DexaSection section;
  final List<DexaRow> rows;
}

/// Groups stored measures into report-style sections, in report order.
/// Empty sections are left out; unknown keys go to [DexaSection.other].
List<DexaGroup> groupDexaMeasures(List<({String name, String value})> measures) {
  final byKey = {for (final m in measures) m.name: m.value};
  final known = {for (final d in dexaMeasureDefs) d.key: d};
  final rows = <DexaSection, List<DexaRow>>{};

  for (final d in dexaMeasureDefs) {
    final raw = byKey[d.key];
    if (raw == null || raw.trim().isEmpty) continue;
    var unit = d.unit;
    if (d.key == 'visceral_fat') unit = (byKey['visceral_fat_unit'] ?? '').trim();
    rows.putIfAbsent(d.section, () => []).add(DexaRow(d.label, _withUnit(raw.trim(), unit)));
  }
  for (final m in measures) {
    if (known.containsKey(m.name) || _hiddenKeys.contains(m.name)) continue;
    if (m.value.trim().isEmpty) continue;
    rows.putIfAbsent(DexaSection.other, () => []).add(DexaRow(m.name, m.value.trim()));
  }
  return [
    for (final s in DexaSection.values)
      if (rows[s] != null) DexaGroup(s, rows[s]!),
  ];
}

String _withUnit(String value, String unit) {
  if (unit.isEmpty) return value;
  if (unit == '%' || unit.startsWith('/')) return '$value$unit';
  return '$value $unit';
}
