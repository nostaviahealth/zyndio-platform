
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lab_report.dart';
import '../data/health_data_repository.dart';
import 'patient_provider.dart';

final labReportsProvider = FutureProvider<List<LabReport>>((ref) async {
  final profileAsync = ref.watch(patientProfileProvider);
  
  // The signed-in patient's auth user id (what lab_reports RLS checks); null
  // when signed out, which yields an empty list. Query errors propagate so
  // the screen shows its error state instead of "No lab results yet" (TC-037).
  final patientId = profileAsync.value?.id;
  return HealthDataRepository.fetchReports(patientId);
});
