import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import 'patient_provider.dart';
import 'programme_journey_provider.dart';

/// A therapy from `patient_treatments` (POR-07 treatment context). The table
/// deliberately has no dose column, so the app never shows one.
class PatientTherapy {
  const PatientTherapy({required this.name, this.startedOn, this.status});

  final String name;
  final DateTime? startedOn;

  /// e.g. 'active', 'paused', 'stopped'.
  final String? status;

  bool get isActive => (status ?? '').toLowerCase() == 'active';

  static List<PatientTherapy> parse(Object? rows) {
    if (rows is! List) return const [];
    return [
      for (final r in rows)
        if (r is Map && '${r['name'] ?? ''}'.trim().isNotEmpty)
          PatientTherapy(
            name: '${r['name']}'.trim(),
            startedOn: DateTime.tryParse('${r['started_on'] ?? ''}'),
            status: r['status'] as String?,
          ),
    ];
  }
}

/// The signed-in patient's therapies (RLS: patient_id = auth.uid()). Errors
/// propagate so the screen shows its error state.
final patientTherapiesProvider = FutureProvider<List<PatientTherapy>>((ref) async {
  final patientId = ref.watch(patientProfileProvider).value?.id;
  final client = SupabaseConfig.client;
  if (patientId == null || client == null) return const [];
  final rows = await client
      .from('patient_treatments')
      .select('name, started_on, status')
      .eq('patient_id', patientId)
      .order('started_on', ascending: false);
  return PatientTherapy.parse(rows);
}, retry: (retryCount, error) => null);

/// An upcoming lab panel or scan.
class UpcomingTest {
  const UpcomingTest({required this.title, required this.detail, this.due});

  final String title;
  final String detail;
  final DateTime? due;
}

/// The patient's next programme test, from their records: before the
/// baseline scan, the baseline DEXASCAN; after it, the next Day 90 / 180 /
/// 365 scan and lab panel with its date (APP-14). Empty while the records
/// load, and once the first programme year is complete.
final upcomingTestsProvider = Provider<List<UpcomingTest>>((ref) {
  final journey = ref.watch(programmeJourneyProvider);
  if (journey == null) return const [];
  if (!journey.hasBaseline) {
    return const [
      UpcomingTest(
        title: 'Baseline DEXASCAN',
        detail: 'Your first body composition scan',
      ),
    ];
  }
  final next = journey.nextMilestone;
  if (next == null) return const [];
  return [
    UpcomingTest(
      title: '${next.label} DEXASCAN and lab panel',
      detail: 'Follow-up body composition scan and labs',
      due: next.target,
    ),
  ];
});
