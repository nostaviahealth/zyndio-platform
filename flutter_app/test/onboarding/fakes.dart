import 'package:zyndio_patient/models/clinical_profile.dart';
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/providers/onboarding_provider.dart';

/// AuthNotifier with the APP-01 code calls stubbed.
class FakeCodeAuthNotifier extends AuthNotifier {
  final List<String> requested = [];
  final List<(String, String)> verified = [];
  final List<String> deletedWithCode = [];
  Object? verifyError;
  Object? deleteError;

  @override
  Future<void> requestLoginCode(String email) async => requested.add(email);

  @override
  Future<void> verifyLoginCode(String email, String code) async {
    verified.add((email, code));
    if (verifyError != null) throw verifyError!;
  }

  @override
  Future<void> deleteAccountWithCode(String code) async {
    deletedWithCode.add(code);
    if (deleteError != null) throw deleteError!;
  }
}

class FakeOnboardingRepository implements PatientOnboardingRepository {
  FakeOnboardingRepository({required this.status, this.profile});

  OnboardingStatus status;
  ClinicalProfile? profile;
  final List<List<ConsentDocument>> granted = [];
  final List<ClinicalProfile> saved = [];
  Object? grantError;

  @override
  Future<OnboardingStatus> fetchStatus() async => status;

  @override
  Future<void> grantConsents(List<ConsentDocument> documents) async {
    granted.add(documents);
    if (grantError != null) throw grantError!;
  }

  @override
  Future<ClinicalProfile> fetchProfile() async =>
      profile ?? const ClinicalProfile(displayName: '');

  @override
  Future<ClinicalProfile> updateProfile(ClinicalProfile p) async {
    saved.add(p);
    return profile = p;
  }
}

ConsentDocument fakeDoc(String type, {String version = '0.1'}) => ConsentDocument(
      consentType: type,
      version: version,
      document: 'zyndio_$type',
      title: switch (type) {
        'terms' => 'Terms of Service',
        'privacy' => 'Privacy Notice',
        _ => 'Consent to use my health data',
      },
      summary: 'Version $version · placeholder text',
      body: 'PLACEHOLDER - NOT THE FINAL TEXT for $type.',
      isPlaceholder: true,
    );
