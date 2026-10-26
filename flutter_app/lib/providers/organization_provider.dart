import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'patient_provider.dart';

final selectedOrganizationProvider = Provider<String>((ref) {
  final profile = ref.watch(patientProfileProvider).value;
  return profile?.organization ?? 'Default';
});
