import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/clinical_profile.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/clinical_profile_form.dart';
import '../onboarding/profile_setup_screen.dart';

/// APP-04: edit the profile collected in onboarding - name, date of birth,
/// sex at birth, height and units. Saved to the clinic record
/// (`update_patient_profile`); the app-account name/age (patient_accounts,
/// shown on Today) is kept in step from the same values.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  bool _saving = false;

  Future<void> _save(ClinicalProfile profile) async {
    final repo = ref.read(patientOnboardingRepositoryProvider);
    if (repo == null) return;
    setState(() => _saving = true);
    try {
      final saved = await repo.updateProfile(profile);
      ref.invalidate(clinicalProfileProvider);
      ref.invalidate(onboardingStatusProvider);
      // Best effort: the app-account copy only feeds Today's greeting/age.
      try {
        await ref.read(patientProfileProvider.notifier).updateProfile(
              name: saved.displayName,
              age: saved.dateOfBirth == null ? null : ageOn(saved.dateOfBirth!, DateTime.now()),
            );
      } catch (e) {
        debugPrint('EditProfile: patient_accounts sync failed: $e');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(profileSaveErrorCopy(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(clinicalProfileProvider);
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: context.nc.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("We couldn't load your profile.",
                    style: TextStyle(color: context.nc.textPrimary)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => ref.invalidate(clinicalProfileProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (p) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ClinicalProfileForm(
            initial: p,
            submitLabel: 'Save changes',
            saving: _saving,
            onSubmit: _save,
          ),
        ),
      ),
    );
  }
}
