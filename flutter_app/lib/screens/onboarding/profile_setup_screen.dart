import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../demo/widgets/step_progress.dart';
import '../../models/clinical_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../widgets/clinical_profile_form.dart';
import '../auth/widgets/patient_auth_chrome.dart';

/// User-facing copy for an `update_patient_profile` refusal.
String profileSaveErrorCopy(Object error) {
  if (error is OnboardingException) {
    switch (error.code) {
      case 'invalid_display_name':
        return 'Check your name and try again.';
      case 'invalid_date_of_birth':
        return 'Check your date of birth. You need to be $kMinPatientAge or older.';
      case 'invalid_sex_at_birth':
        return 'Choose your sex assigned at birth.';
      case 'invalid_height':
        return 'Check your height and try again.';
    }
  }
  return "We couldn't save your profile. Check your connection and try again.";
}

/// APP-04 onboarding step 2: name, date of birth, sex at birth, height and
/// units. The name comes prefilled from what the care team entered.
class OnboardingProfileScreen extends ConsumerStatefulWidget {
  const OnboardingProfileScreen({super.key});

  @override
  ConsumerState<OnboardingProfileScreen> createState() => _OnboardingProfileScreenState();
}

class _OnboardingProfileScreenState extends ConsumerState<OnboardingProfileScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _save(ClinicalProfile profile) async {
    final repo = ref.read(patientOnboardingRepositoryProvider);
    if (repo == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repo.updateProfile(profile);
      ref.invalidate(clinicalProfileProvider);
      ref.invalidate(onboardingStatusProvider);
    } catch (e) {
      if (mounted) setState(() => _error = profileSaveErrorCopy(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    final existing = ref.watch(clinicalProfileProvider);
    return PatientAuthShell(
      title: 'About you',
      subtitle: 'Your care team uses this to read your lab results and track your progress.',
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Step 2 of 2', style: ZyndioType.footnote.copyWith(color: c.textTertiary)),
          const SizedBox(height: 8),
          const StepProgress(value: 1),
        ],
      ),
      banner: _error == null ? null : AuthStatusBanner(message: _error!),
      body: existing.isLoading && !existing.hasValue
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          : ClinicalProfileForm(
              initial: existing.value,
              submitLabel: 'Continue',
              saving: _saving,
              onSubmit: _save,
            ),
      footer: AuthSecondaryButton(
        label: 'Sign out',
        outlined: false,
        onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
      ),
    );
  }
}
