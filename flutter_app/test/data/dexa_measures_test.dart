// The Progress tab groups a DEXA scan's stored measures the way a DEXAscan
// report does, with units, and never adds a value, range or category that
// was not stored. Fictional numbers only.
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/data/dexa_measures.dart';

List<({String name, String value})> m(Map<String, String> map) =>
    [for (final e in map.entries) (name: e.key, value: e.value)];

void main() {
  test('groups known keys into report sections, in report order, with units', () {
    final groups = groupDexaMeasures(m({
      'bone_t_score': '-0.9',
      'body_fat_pct': '27.1',
      'almi_kg_m2': '6.10',
      'health_score': '81',
      'fat_mass_lb': '41.2',
      'arm_lean_difference_pct': '4.0',
    }));
    expect(groups.map((g) => g.section), [
      DexaSection.overview,
      DexaSection.muscle,
      DexaSection.fat,
      DexaSection.bone,
      DexaSection.symmetry,
    ]);
    final overview = groups.first.rows;
    expect(overview.map((r) => '${r.label}=${r.value}'),
        ['Overall health score=81/100', 'Body fat=27.1%']);
    expect(groups[1].rows.single.value, '6.10 kg/m²');
    expect(groups[2].rows.single.value, '41.2 lb');
    expect(groups[3].rows.single.value, '-0.9');
  });

  test('empty sections are left out and nothing is invented', () {
    final groups = groupDexaMeasures(m({'weight_lb': '180.4'}));
    expect(groups.length, 1);
    expect(groups.single.rows.single.value, '180.4 lb');
  });

  test('unknown keys are still shown, under Other measures, as stored', () {
    final groups = groupDexaMeasures(m({'body_fat_pct': '30.0', 'vendor_custom_index': '7'}));
    expect(groups.last.section, DexaSection.other);
    expect(groups.last.rows.single.label, 'vendor_custom_index');
    expect(groups.last.rows.single.value, '7');
  });

  test('visceral_fat uses the stored unit, and the unit key itself is not a row', () {
    final groups = groupDexaMeasures(m({'visceral_fat': '0.9', 'visceral_fat_unit': 'lb'}));
    expect(groups.single.rows.single.value, '0.9 lb');
    expect(groups.any((g) => g.section == DexaSection.other), isFalse);
  });

  test('blank values are skipped rather than shown as empty rows', () {
    expect(groupDexaMeasures(m({'vat_area_cm2': '  '})), isEmpty);
  });

  test('every catalog key is unique', () {
    final keys = dexaMeasureDefs.map((d) => d.key).toList();
    expect(keys.toSet().length, keys.length);
  });
}
