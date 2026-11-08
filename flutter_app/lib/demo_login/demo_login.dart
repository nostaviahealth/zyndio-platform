// Demo login: look around the real app with fictional data, no server.
//
// Only in builds made with --dart-define=DEMO_LOGIN=true AND not in release
// mode. kReleaseMode is a compile-time constant, so a store build compiles
// this out even if the define slips into its build settings. The production
// sign-in path, the backend-ready check and every real data source are
// untouched; demo builds swap in the providers below at the app root.
//
// All people, results and scans here are fictional.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import '../data/body_composition.dart';
import '../models/lab_report.dart';
import '../models/patient_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/body_composition_provider.dart';
import '../providers/intelligence_provider.dart';
import '../providers/lab_reports_provider.dart';
import '../providers/onboarding_provider.dart';
import '../providers/patient_provider.dart';
import '../providers/wearable_sync_provider.dart';
import '../providers/protocol_provider.dart';
import '../providers/feature_flags_provider.dart';
import '../providers/longevity_provider.dart';
import '../providers/my_plan_provider.dart';
import '../data/protocol_repository.dart';

const bool _demoLoginDefine = bool.fromEnvironment('DEMO_LOGIN', defaultValue: false);

/// True only in non-release builds made with DEMO_LOGIN=true.
const bool kDemoLoginEnabled = _demoLoginDefine && !kReleaseMode;

/// Whether the person tapped "Explore the demo" (and hasn't signed out).
class DemoSession extends Notifier<bool> {
  @override
  bool build() => false;
  void start() => state = true;
  void end() => state = false;
}

final demoSessionProvider = NotifierProvider<DemoSession, bool>(DemoSession.new);

const _demoUserId = '00000000-0000-0000-0000-00000000de30';

final User demoUser = User(
  id: _demoUserId,
  appMetadata: const {'provider': 'demo'},
  userMetadata: const {'full_name': 'Jordan Rivera'},
  aud: 'authenticated',
  email: 'jordan.rivera@example.test',
  createdAt: '2026-01-05T09:00:00Z',
  emailConfirmedAt: '2026-01-05T09:05:00Z',
);

class _DemoProfileNotifier extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async => PatientProfile(
        id: _demoUserId,
        userId: _demoUserId,
        name: 'Jordan Rivera',
        email: 'jordan.rivera@example.test',
        age: 44,
        subscriptionPlan: 'free',
        createdAt: DateTime(2026, 1, 5),
      );
}

/// Fictional wearable day so Today shows metrics, not the connect prompt.
/// Refresh keeps the sample instead of trying a real device sync.
class _DemoWearableNotifier extends WearableSyncNotifier {
  @override
  Future<WearableSyncState> build() async => WearableSyncState(
        isSyncing: false,
        lastSynced: DateTime.now().subtract(const Duration(minutes: 12)),
        snapshot: const WearableSnapshot(
          sleepHours: 7.4,
          sleepEfficiency: 91,
          sleepScore: 84,
          recoveryScore: 72,
          hrv: 58,
          hrvBaseline: 54,
          rhr: 56,
          rhrBaseline: 58,
          steps: 8432,
          exerciseMinutes: 41,
          activeEnergy: 512,
          respiratoryRate: 14.2,
          bloodOxygen: 97,
          vo2Max: 44.1,
          heartRateAvg: 68,
        ),
      );

  @override
  Future<void> sync({DateTime? date}) async {}
}

/// A fictional care-team plan so My Plan has content in the demo. Built on
/// the repository's sample plan, retitled for the demo patient's labs.
ProtocolData demoPlan() {
  final base = ProtocolData.mock;
  return ProtocolData(
    id: 'admin-demo-plan',
    title: 'Metabolic & heart health',
    subtitle: '12 weeks · Phase 1 of 2',
    description: 'Lower LDL and ApoB while keeping HbA1c in range.',
    currentPhase: base.currentPhase,
    availablePhases: base.availablePhases,
    isPremium: false,
    diet: base.diet,
    lifestyle: base.lifestyle,
    fitness: base.fitness,
    supplements: base.supplements,
    debugGoal: const {},
    targetMetrics: const ['LDL Cholesterol', 'ApoB', 'HbA1c'],
  );
}

class _DemoProtocolNotifier extends ProtocolNotifier {
  @override
  ProtocolState build() {
    final plan = demoPlan();
    return ProtocolState(allProtocols: [plan], selectedProtocolId: plan.id);
  }

  @override
  Future<void> fetchLibrary() async {}

  @override
  Future<void> selectProtocol(String id) async {}
}

LabMarker _m(String name, String value,
        {String unit = '', double? low, double? high, String status = 'In-range'}) =>
    LabMarker(
      name: name,
      value: value,
      range: low != null && high != null ? '$low-$high' : '',
      status: status,
      unit: unit,
      minRange: low,
      maxRange: high,
    );

/// Two fictional panels so Biomarkers shows current values and a trend.
List<LabReport> demoLabReports() => [
      LabReport(
        id: 'demo-r2',
        date: '2026-10-14',
        title: 'Longevity panel',
        summary: 'Fictional demo results.',
        labName: 'Demo Lab',
        markers: [
          _m('Intracellular NAD+', '41', unit: 'µM'),
          _m('Klotho', '1210', unit: 'pg/mL'),
          _m('HbA1c', '5.3', unit: '%', low: 4.0, high: 5.6),
          _m('Glucose', '91', unit: 'mg/dL', low: 65, high: 99),
          _m('Fasting Insulin', '6.1', unit: 'µIU/mL', low: 2.6, high: 24.9),
          _m('LDL Cholesterol', '134', unit: 'mg/dL', low: 0, high: 129, status: 'High'),
          _m('HDL Cholesterol', '58', unit: 'mg/dL', low: 40, high: 100),
          _m('Triglycerides', '96', unit: 'mg/dL', low: 0, high: 149),
          _m('ApoB', '92', unit: 'mg/dL', low: 0, high: 90, status: 'High'),
          _m('hs-CRP', '0.8', unit: 'mg/L', low: 0, high: 3.0),
          _m('Vitamin D', '38', unit: 'ng/mL', low: 30, high: 100),
          _m('Testosterone', '612', unit: 'ng/dL', low: 300, high: 1000),
          _m('TSH', '1.9', unit: 'mIU/L', low: 0.45, high: 4.5),
        ],
      ),
      LabReport(
        id: 'demo-r1',
        date: '2026-06-02',
        title: 'Baseline panel',
        summary: 'Fictional demo results.',
        labName: 'Demo Lab',
        markers: [
          _m('Intracellular NAD+', '27', unit: 'µM'),
          _m('Klotho', '945', unit: 'pg/mL'),
          _m('hs-CRP', '1.3', unit: 'mg/L', low: 0, high: 3.0),
          _m('HbA1c', '5.6', unit: '%', low: 4.0, high: 5.6),
          _m('Glucose', '98', unit: 'mg/dL', low: 65, high: 99),
          _m('LDL Cholesterol', '151', unit: 'mg/dL', low: 0, high: 129, status: 'High'),
          _m('ApoB', '104', unit: 'mg/dL', low: 0, high: 90, status: 'High'),
          _m('Vitamin D', '24', unit: 'ng/mL', low: 30, high: 100, status: 'Low'),
        ],
      ),
    ];

/// One fictional DEXA scan using the report-style keys (dexa_measures.dart).
List<StoredBodyScan> demoBodyScans() => const [
      StoredBodyScan(
        scanDate: '2026-10-02',
        deviceVendor: 'Demo DEXA',
        deviceModel: 'Model D',
        softwareVersion: '1.0',
        measures: [
          (name: 'health_score', value: '84'),
          (name: 'total_mass_lb', value: '176.2'),
          (name: 'body_fat_pct', value: '22.4'),
          (name: 'lean_mass_lb', value: '130.1'),
          (name: 'almi_kg_m2', value: '8.42'),
          (name: 'almi_percentile', value: '58'),
          (name: 'appendicular_lean_mass_lb', value: '58.7'),
          (name: 'lean_mass_index_kg_m2', value: '18.9'),
          (name: 'fat_mass_lb', value: '39.5'),
          (name: 'trunk_fat_pct', value: '21.0'),
          (name: 'vat_area_cm2', value: '82'),
          (name: 'visceral_fat_mass_lb', value: '1.4'),
          (name: 'fat_mass_index_kg_m2', value: '5.7'),
          (name: 'android_gynoid_ratio', value: '0.92'),
          (name: 'bone_t_score', value: '0.4'),
          (name: 'bone_z_score', value: '0.6'),
          (name: 'bone_mineral_density_g_cm2', value: '1.214'),
          (name: 'arm_lean_difference_pct', value: '3.1'),
          (name: 'leg_lean_difference_pct', value: '1.2'),
        ],
      ),
      // Fictional Day 90 follow-up, so the programme track shows each step.
      StoredBodyScan(
        scanDate: '2026-07-09',
        deviceVendor: 'Demo DEXA',
        deviceModel: 'Model D',
        softwareVersion: '1.0',
        measures: [
          (name: 'health_score', value: '80'),
          (name: 'total_mass_lb', value: '180.3'),
          (name: 'body_fat_pct', value: '25.1'),
          (name: 'lean_mass_lb', value: '129.4'),
          (name: 'fat_mass_lb', value: '45.3'),
          (name: 'vat_area_cm2', value: '98'),
          (name: 'visceral_fat_mass_lb', value: '1.6'),
        ],
      ),
      // Fictional baseline six months earlier, for the before/after cards.
      StoredBodyScan(
        scanDate: '2026-04-08',
        deviceVendor: 'Demo DEXA',
        deviceModel: 'Model D',
        softwareVersion: '1.0',
        measures: [
          (name: 'health_score', value: '76'),
          (name: 'total_mass_lb', value: '184.9'),
          (name: 'body_fat_pct', value: '28.4'),
          (name: 'lean_mass_lb', value: '128.1'),
          (name: 'almi_kg_m2', value: '8.31'),
          (name: 'appendicular_lean_mass_lb', value: '57.9'),
          (name: 'lean_mass_index_kg_m2', value: '18.6'),
          (name: 'fat_mass_lb', value: '52.5'),
          (name: 'trunk_fat_pct', value: '27.2'),
          (name: 'vat_area_cm2', value: '118'),
          (name: 'visceral_fat_mass_lb', value: '1.8'),
          (name: 'fat_mass_index_kg_m2', value: '7.6'),
          (name: 'android_gynoid_ratio', value: '1.04'),
          (name: 'bone_mineral_density_g_cm2', value: '1.192'),
        ],
      ),
    ];

const List<String> demoInsights = [
  'Your HbA1c improved from 5.6% to 5.3% since your baseline panel.',
  'LDL and ApoB are still above range. Your care team may review them at your next visit.',
  'Vitamin D is back in range after starting supplementation.',
];

/// Provider swaps for a demo build. Applied at the app root only when
/// [kDemoLoginEnabled]; before "Explore the demo" is tapped the person is
/// signed out and sees the normal sign-in screen.
List<Override> demoLoginOverrides() => [
      authStateProvider.overrideWith(
        (ref) => Stream.value(ref.watch(demoSessionProvider) ? demoUser : null),
      ),
      onboardingStatusProvider.overrideWith(
        (ref) async => const OnboardingStatus(
          linked: true,
          missingConsents: [],
          profileComplete: true,
          documentsReady: true,
        ),
      ),
      selfSignupEnabledProvider.overrideWith((ref) async => false),
      patientProfileProvider.overrideWith(_DemoProfileNotifier.new),
      labReportsProvider.overrideWith((ref) async => demoLabReports()),
      bodyCompositionScansProvider.overrideWith((ref) async => demoBodyScans()),
      aiInsightsProvider.overrideWithValue(demoInsights),
      wearableSyncProvider.overrideWith(_DemoWearableNotifier.new),
      protocolProvider.overrideWith(_DemoProtocolNotifier.new),
      // Demo shows the full client design: score ring, Recovery, Appointments.
      featureFlagsProvider.overrideWithValue(const FeatureFlags(
        longevityScoreEnabled: true,
        recoveryScoreEnabled: true,
        appointmentsEnabled: true,
      )),
      patientTherapiesProvider.overrideWith((ref) async => [
            PatientTherapy(name: 'GLP-1 Therapy · Tirzepatide', startedOn: DateTime(2026, 8, 5), status: 'active'),
            PatientTherapy(name: 'NAD+ Therapy', startedOn: DateTime(2026, 8, 12), status: 'active'),
          ]),
      longevityScoreProvider.overrideWithValue(
        const LongevityScore(score: 84, trendPercent: 12),
      ),
    ];
