import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/clinical_profile.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/clinical_profile_form.dart';
import '../../widgets/tc025/tc025_widgets.dart';
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
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final profile = ref.watch(clinicalProfileProvider);
    return ZyndioDetailScaffold(
      title: 'Edit Profile',
      onBack: () => context.pop(),
      body: profile.when(
        loading: () => Center(child: CircularProgressIndicator(color: c.brandPrimary)),
        error: (e, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: zyndioCard(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.statusCriticalSubtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.cloudOff, size: 20, color: c.statusCritical),
                ),
                const SizedBox(height: 16),
                Text(
                  "We couldn't load your profile.",
                  style: ZyndioType.headline.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 16),
                ZyndioOutlineButton(
                  label: 'Try again',
                  onTap: () => ref.invalidate(clinicalProfileProvider),
                ),
              ],
            ),
          ),
        ),
        data: (p) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
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
