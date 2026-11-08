import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/programme_journey.dart';
import 'body_composition_provider.dart';
import 'lab_reports_provider.dart';
import 'my_plan_provider.dart';
import 'protocol_provider.dart';

/// Today's date for the programme journey. Overridden in tests.
final programmeTodayProvider = Provider<DateTime>((ref) => DateTime.now());

/// The patient's programme journey, or null while its sources load or when
/// any of them failed (the tabs that own those records show their own error
/// states, so the journey card simply stays out of the way).
final programmeJourneyProvider = Provider<ProgrammeJourney?>((ref) {
  final scans = ref.watch(bodyCompositionScansProvider);
  final labs = ref.watch(labReportsProvider);
  final therapies = ref.watch(patientTherapiesProvider);
  final plan = ref.watch(protocolProvider).selectedProtocol;
  if (!scans.hasValue || !labs.hasValue || !therapies.hasValue) return null;
  if (scans.hasError || labs.hasError || therapies.hasError) return null;

  return buildProgrammeJourney(
    scanDates: [
      for (final s in scans.value!)
        if (parseCalendarDate(s.scanDate) case final d?) d,
    ],
    hasLabResults: labs.value!.any((r) => r.markers.isNotEmpty),
    hasCarePlan: therapies.value!.isNotEmpty || plan != null,
    today: ref.watch(programmeTodayProvider),
  );
});
