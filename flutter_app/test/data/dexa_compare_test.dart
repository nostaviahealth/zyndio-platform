// Baseline-vs-latest cards on Progress: values only from stored measures,
// percent measures change in points, others in relative percent. Fictional.
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/data/body_composition.dart';
import 'package:zyndio_patient/data/dexa_compare.dart';

StoredBodyScan scan(String date, Map<String, String> m) => StoredBodyScan(
      scanDate: date,
      deviceVendor: 'V',
      deviceModel: 'M',
      softwareVersion: '1',
      measures: [for (final e in m.entries) (name: e.key, value: e.value)],
    );

void main() {
  final base = scan('2026-04-08', {'body_fat_pct': '28.4', 'visceral_fat_mass_lb': '1.8', 'lean_mass_lb': '128.1'});
  final latest = scan('2026-10-02', {'body_fat_pct': '22.1', 'visceral_fat_mass_lb': '1.4', 'lean_mass_lb': '128.1', 'bone_mineral_density_g_cm2': '1.14'});

  test('baseline is the oldest scan, latest the newest, whatever the order', () {
    final p = baselineAndLatest([latest, base]);
    expect(p.baseline?.scanDate, '2026-04-08');
    expect(p.latest?.scanDate, '2026-10-02');
    expect(baselineAndLatest([latest]).baseline, isNull);
  });

  test('Total: percent change in points, mass change relative, equal is Stable', () {
    final rows = compareSegment('Total', latest, base);
    final byLabel = {for (final r in rows) r.label: r};
    expect(byLabel['Total Body Fat']!.change, '↓ 6.3%'); // 28.4 -> 22.1 points
    expect(byLabel['Visceral Fat']!.change, '↓ 22.2%'); // relative
    expect(byLabel['Lean Mass']!.change, 'Stable');
    // Bone density has no baseline value: shown without a change.
    expect(byLabel['Bone Density']!.baseline, isNull);
    expect(byLabel['Bone Density']!.change, isNull);
    expect(byLabel['Bone Density']!.latest, '1.14 g/cm²');
  });

  test('one scan: latest values only, no invented change', () {
    final rows = compareSegment('Total', latest, null);
    expect(rows.every((r) => r.baseline == null && r.change == null), isTrue);
  });

  test('metrics the latest scan lacks are skipped; visceral falls back to area', () {
    final s = scan('2026-10-02', {'vat_area_cm2': '82'});
    final rows = compareSegment('Total', s, null);
    expect(rows.single.label, 'Visceral Fat');
    expect(rows.single.latest, '82.0 cm²');
  });

  test('every segment has four cards defined, in mockup order', () {
    expect(dexaSegments.keys.toList(), ['Total', 'Lean Mass', 'Fat Mass', 'Visceral Fat']);
    expect(dexaSegments.values.every((m) => m.length == 4), isTrue);
  });
}
