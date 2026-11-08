import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../main.dart';
import '../models/clinical_profile.dart';
import 'auth_provider.dart';

/// APP-02: one Zyndio document the patient must agree to (terms, privacy
/// notice, consent to use health data), at the version currently in force.
/// Until Zyndio supplies the real text the server serves placeholder wording
/// with [isPlaceholder] set.
@immutable
class ConsentDocument {
  const ConsentDocument({
    required this.consentType,
    required this.version,
    required this.document,
    required this.title,
    required this.summary,
    required this.body,
    required this.isPlaceholder,
  });

  final String consentType;
  final String version;
  final String document;
  final String title;
  final String summary;
  final String body;
  final bool isPlaceholder;

  factory ConsentDocument.fromJson(Map<String, dynamic> json) => ConsentDocument(
        consentType: json['consent_type'] as String,
        version: json['version'] as String,
        document: (json['document'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        summary: (json['summary'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        isPlaceholder: json['is_placeholder'] == true,
      );
}

/// APP-02 + APP-04: what the signed-in patient still has to do before the
/// app opens, from `patient_onboarding_status()`.
@immutable
class OnboardingStatus {
  const OnboardingStatus({
    required this.linked,
    required this.missingConsents,
    required this.profileComplete,
    required this.documentsReady,
  });

  final bool linked;
  final List<ConsentDocument> missingConsents;
  final bool profileComplete;

  /// False while the current required documents are still placeholders.
  final bool documentsReady;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) => OnboardingStatus(
        linked: json['linked'] == true,
        missingConsents: [
          for (final e in (json['missing_consents'] as List? ?? const []))
            ConsentDocument.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        profileComplete: json['profile_complete'] == true,
        documentsReady: json['documents_ready'] == true,
      );

  /// The onboarding step to show, or null once everything is done. An
  /// unlinked account (self-signup with no clinic record yet) has to link
  /// first: consents and profile live on the clinic record. Placeholder
  /// documents keep the patient on the consent step.
  String? get nextRoute {
    if (!linked) return '/link-record';
    if (!documentsReady || missingConsents.isNotEmpty) return onboardingConsentPath;
    if (!profileComplete) return onboardingProfilePath;
    return null;
  }
}

const onboardingConsentPath = '/onboarding/consent';
const onboardingProfilePath = '/onboarding/profile';

/// Pages a patient may be on while onboarding is unfinished, besides the
/// step itself: linking a record and deleting the account (Apple 5.1.1(v)
/// must be reachable at any point).
const onboardingAllowedPaths = {
  '/link-record',
  '/delete-account',
  onboardingConsentPath,
  onboardingProfilePath,
};

/// Pure APP-02 gate for the router. [status] is the provider's state:
/// loading, a null status, and an error all stay off clinical pages. The
/// consent, link, and delete-account routes stay reachable.
String? onboardingRedirect(String location, AsyncValue<OnboardingStatus?> status) {
  if ((status.isLoading && !status.hasValue) || (status.hasError && !status.hasValue) || status.value == null) {
    return onboardingAllowedPaths.contains(location) ? null : onboardingConsentPath;
  }
  final s = status.value;
  if (s == null) return onboardingConsentPath;
  final next = s.nextRoute;
  if (next == null) {
    return location.startsWith('/onboarding/') ? '/' : null;
  }
  if (location == next) return null;
  // While a step is outstanding, the other onboarding pages aren't a way
  // around it (e.g. profile before consent), but linking / deleting are.
  if (location.startsWith('/onboarding/')) return next;
  if (onboardingAllowedPaths.contains(location)) return null;
  return next;
}

/// Server calls behind onboarding, consent and the clinical profile.
abstract class PatientOnboardingRepository {
  Future<OnboardingStatus> fetchStatus();
  Future<void> grantConsents(List<ConsentDocument> documents);
  Future<ClinicalProfile> fetchProfile();
  Future<ClinicalProfile> updateProfile(ClinicalProfile profile);
}

/// Raised for a refused write. [code] is the server's message, e.g.
/// `consent_version_stale`, `invalid_date_of_birth`.
class OnboardingException implements Exception {
  OnboardingException(this.code);
  final String code;
  @override
  String toString() => 'OnboardingException: $code';
}

class SupabasePatientOnboardingRepository implements PatientOnboardingRepository {
  SupabasePatientOnboardingRepository(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> _rpcMap(String fn, [Map<String, dynamic>? params]) async {
    try {
      final res = await _client.rpc(fn, params: params);
      if (res is Map) return Map<String, dynamic>.from(res);
      throw OnboardingException('internal_error');
    } on PostgrestException catch (e) {
      throw OnboardingException(e.message);
    }
  }

  @override
  Future<OnboardingStatus> fetchStatus() async =>
      OnboardingStatus.fromJson(await _rpcMap('patient_onboarding_status'));

  @override
  Future<void> grantConsents(List<ConsentDocument> documents) async {
    try {
      await _client.rpc('grant_patient_consents', params: {
        'p_items': [
          for (final d in documents) {'consent_type': d.consentType, 'version': d.version},
        ],
      });
    } on PostgrestException catch (e) {
      throw OnboardingException(e.message);
    }
  }

  @override
  Future<ClinicalProfile> fetchProfile() async =>
      ClinicalProfile.fromJson(await _rpcMap('my_patient_profile'));

  @override
  Future<ClinicalProfile> updateProfile(ClinicalProfile profile) async =>
      ClinicalProfile.fromJson(await _rpcMap('update_patient_profile', profile.toRpcParams()));
}

/// Null when Supabase isn't configured (demo mode): nothing is gated then.
final patientOnboardingRepositoryProvider = Provider<PatientOnboardingRepository?>((ref) {
  if (!ref.watch(supabaseInitializedProvider)) return null;
  final client = SupabaseConfig.client;
  return client == null ? null : SupabasePatientOnboardingRepository(client);
});

/// The signed-in patient's onboarding status; null when signed out or in
/// demo mode. Invalidate after granting consents or saving the profile.
final onboardingStatusProvider = FutureProvider<OnboardingStatus?>((ref) async {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return null;
  final repo = ref.watch(patientOnboardingRepositoryProvider);
  if (repo == null) return null;
  return repo.fetchStatus();
});

/// The clinical profile for Settings > Edit profile.
final clinicalProfileProvider = FutureProvider<ClinicalProfile?>((ref) async {
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return null;
  final repo = ref.watch(patientOnboardingRepositoryProvider);
  if (repo == null) return null;
  return repo.fetchProfile();
});
