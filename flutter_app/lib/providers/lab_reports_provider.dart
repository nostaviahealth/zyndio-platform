
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lab_report.dart';
import '../data/health_data_repository.dart';
import 'patient_provider.dart';

final labReportsProvider = FutureProvider<List<LabReport>>((ref) async {
  final profileAsync = ref.watch(patientProfileProvider);
  
  // Use our robust Repository logic (Sync + Fallback)
  // We pass the profile ID if available, otherwise it falls back to Mock in the repo
  final profileId = profileAsync.value?.id;
  
  // Call the Repository
  // This ensures we get the "Rich Data" (100 markers) even if DB is empty or fails
  return HealthDataRepository.fetchReports(profileId);
});
