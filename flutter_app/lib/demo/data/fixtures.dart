/// Fictional demo patient and lab data. Copy/values only — never real PII,
/// never the internal docs these numbers are drawn from.
library;

class DemoPatient {
  const DemoPatient({
    required this.name,
    required this.email,
    required this.labName,
  });

  final String name;
  final String email;
  final String labName;
}

const demoPatient = DemoPatient(
  name: 'Jordan Rivera',
  email: 'jordan.rivera@example.com',
  labName: 'Fictional Reference Lab',
);

/// Additional seeded fictional patients, used to prove per-patient isolation
/// (lockout, codes, consent, lab/file data never leak across accounts).
const List<DemoPatient> secondaryDemoPatients = [
  DemoPatient(
    name: 'Sam Okafor',
    email: 'sam.okafor@example.com',
    labName: 'Fictional Reference Lab',
  ),
];

/// Every seeded fictional patient (primary + secondary), accounts keyed by
/// email. There is no self-sign-up API — these are the only accounts the
/// demo backend ever knows about.
List<DemoPatient> get allDemoPatients => [demoPatient, ...secondaryDemoPatients];

/// A single HbA1c reading on the trends chart.
class HbA1cPoint {
  const HbA1cPoint({required this.date, required this.percent});

  final DateTime date;
  final double percent;
}

/// HbA1c trend, oldest first. Latest (5.5%) is within the default range.
final List<HbA1cPoint> hba1cTrend = [
  HbA1cPoint(date: DateTime(2026, 4, 2), percent: 6.2),
  HbA1cPoint(date: DateTime(2026, 6, 4), percent: 5.9),
  HbA1cPoint(date: DateTime(2026, 8, 6), percent: 5.7),
  HbA1cPoint(date: DateTime(2026, 10, 14), percent: 5.5),
];

/// General default range ceiling for HbA1c (%); confirmed by the care team,
/// not a diagnosis.
const double hba1cDefaultRangeCeiling = 5.7;

class BiomarkerRow {
  const BiomarkerRow({
    required this.name,
    required this.baseline,
    required this.followUp,
    required this.unit,
  });

  final String name;
  final double baseline;
  final double followUp;
  final String unit;
}

/// Baseline → follow-up biomarker table for the lab review screen.
const List<BiomarkerRow> biomarkerFixture = [
  BiomarkerRow(name: 'Total weight', baseline: 228, followUp: 194, unit: 'lb'),
  BiomarkerRow(name: 'Fat mass', baseline: 82, followUp: 55, unit: 'lb'),
  BiomarkerRow(name: 'Lean mass', baseline: 137, followUp: 133, unit: 'lb'),
  BiomarkerRow(name: 'HbA1c', baseline: 6.2, followUp: 5.5, unit: '%'),
  BiomarkerRow(
    name: 'Fasting insulin',
    baseline: 18.1,
    followUp: 9.4,
    unit: 'uIU/mL',
  ),
  BiomarkerRow(name: 'ApoB', baseline: 106, followUp: 84, unit: 'mg/dL'),
  BiomarkerRow(name: 'hsCRP', baseline: 3.8, followUp: 1.7, unit: 'mg/L'),
];
