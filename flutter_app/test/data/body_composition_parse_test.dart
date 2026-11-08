import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/data/body_composition.dart';

void main() {
  test('parse keeps stored measures and drops nothing into a sample scan', () {
    final scans = parseStoredBodyScans([
      {
        'scan_date': '2026-04-02',
        'device_vendor': 'Fictional Scanner',
        'device_model': 'Model A',
        'software_version': '1.0',
        'measures': {'weight_lb': 180, 'fat_mass_lb': 40},
      },
      {'scan_date': '2026-06-01', 'measures': null},
      'not a row',
    ]);

    expect(scans, hasLength(2));
    expect(scans.first.scanDate, '2026-04-02');
    expect(scans.first.deviceLine, 'Fictional Scanner · Model A · 1.0');
    expect(scans.first.measures.map((m) => '${m.name}=${m.value}').toList(),
        ['weight_lb=180', 'fat_mass_lb=40']);
    expect(scans.last.measures, isEmpty);
  });

  test('a non-list payload is an empty result, not a placeholder scan', () {
    expect(parseStoredBodyScans(null), isEmpty);
    expect(parseStoredBodyScans({'weight_lb': 1}), isEmpty);
  });
}
