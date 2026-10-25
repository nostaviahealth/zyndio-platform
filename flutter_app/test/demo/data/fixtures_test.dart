import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';

void main() {
  group('demoPatient', () {
    test('matches the fictional identity used across every screen', () {
      expect(demoPatient.name, 'Jordan Rivera');
      expect(demoPatient.email, 'jordan.rivera@example.com');
      expect(demoPatient.labName, 'Fictional Reference Lab');
    });
  });

  group('hba1cTrend', () {
    test('matches the golden 4-point trend', () {
      expect(hba1cTrend.map((p) => p.percent).toList(), [6.2, 5.9, 5.7, 5.5]);
    });

    test('is sorted oldest to newest', () {
      for (var i = 1; i < hba1cTrend.length; i++) {
        expect(hba1cTrend[i].date.isAfter(hba1cTrend[i - 1].date), isTrue);
      }
    });

    test('latest reading is within the default range', () {
      expect(hba1cTrend.last.percent, lessThan(hba1cDefaultRangeCeiling));
    });
  });

  group('biomarkerFixture', () {
    double baselineOf(String name) =>
        biomarkerFixture.firstWhere((r) => r.name == name).baseline;
    double followUpOf(String name) =>
        biomarkerFixture.firstWhere((r) => r.name == name).followUp;

    test('matches the golden baseline -> follow-up numbers', () {
      expect(baselineOf('Total weight'), 228);
      expect(followUpOf('Total weight'), 194);
      expect(baselineOf('Fat mass'), 82);
      expect(followUpOf('Fat mass'), 55);
      expect(baselineOf('Lean mass'), 137);
      expect(followUpOf('Lean mass'), 133);
      expect(baselineOf('HbA1c'), 6.2);
      expect(followUpOf('HbA1c'), 5.5);
      expect(baselineOf('Fasting insulin'), 18.1);
      expect(followUpOf('Fasting insulin'), 9.4);
      expect(baselineOf('ApoB'), 106);
      expect(followUpOf('ApoB'), 84);
      expect(baselineOf('hsCRP'), 3.8);
      expect(followUpOf('hsCRP'), 1.7);
    });

    test('has exactly the 7 golden-fixture measures', () {
      expect(biomarkerFixture.length, 7);
    });
  });
}
