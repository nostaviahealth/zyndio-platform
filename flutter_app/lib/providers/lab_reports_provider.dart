
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lab_report.dart';
import '../data/health_data_repository.dart';
import 'patient_provider.dart';

/// TC-039: fixed texts for lab-report error states. The underlying error
/// (backend / storage text) is never shown or printed.
const labReportsLoadFailedMessage = "We couldn't load your lab reports. Please try again.";
const labReportDeleteFailedMessage = "Couldn't delete this report. Please try again.";

final labReportsProvider = FutureProvider<List<LabReport>>((ref) async {
  final profileAsync = ref.watch(patientProfileProvider);
  
  // The signed-in patient's auth user id (what lab_reports RLS checks); null
  // when signed out, which yields an empty list. Query errors propagate so
  // the screen shows its error state instead of "No lab results yet" (TC-037).
  final patientId = profileAsync.value?.id;
  return HealthDataRepository.fetchReports(patientId);
},
    // No automatic retry: Riverpod 3's default retries ~38 s behind the loading
    // skeleton, hiding the error state. The error card's "Try again" refetches.
    retry: (retryCount, error) => null);
