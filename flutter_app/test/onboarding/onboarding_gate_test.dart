// APP-02 / APP-04: the onboarding gate the router applies after sign-in, and
// the clinical-profile model behind it.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/models/clinical_profile.dart';
import 'package:zyndio_patient/providers/onboarding_provider.dart';

Map<String, dynamic> _doc(String type) => {
      'consent_type': type,
      'version': '0.1',
      'document': 'zyndio_$type',
      'title': type,
      'summary': 'Version 0.1 · placeholder text',
      'body': 'PLACEHOLDER',
      'is_placeholder': true,
    };

OnboardingStatus _status({
  bool linked = true,
  List<String> missing = const [],
  bool profile = false,
  bool documentsReady = true,
}) =>
    OnboardingStatus.fromJson({
      'linked': linked,
      'missing_consents': [for (final t in missing) _doc(t)],
      'profile_complete': profile,
      'documents_ready': documentsReady,
    });

AsyncValue<OnboardingStatus?> _data(OnboardingStatus s) => AsyncValue.data(s);

void main() {
  group('OnboardingStatus.nextRoute', () {
    test('unlinked account links its clinic record first', () {
      expect(_status(linked: false, missing: ['terms']).nextRoute, '/link-record');
    });
    test('missing consents come before the profile', () {
      expect(_status(missing: ['terms', 'privacy', 'health_data']).nextRoute, onboardingConsentPath);
    });
    test('then the profile', () {
      expect(_status().nextRoute, onboardingProfilePath);
    });
    test('done when consented and profiled', () {
      expect(_status(profile: true).nextRoute, isNull);
    });
    test('placeholder documents keep the patient on the consent step', () {
      expect(_status(profile: true, documentsReady: false).nextRoute, onboardingConsentPath);
    });
    test('parses the placeholder documents the server hands over', () {
      final s = _status(missing: ['terms']);
      expect(s.missingConsents.single.version, '0.1');
      expect(s.missingConsents.single.isPlaceholder, isTrue);
    });
  });

  group('onboardingRedirect', () {
    test('a patient with missing consents is held on the consent step', () {
      final s = _data(_status(missing: ['terms']));
      expect(onboardingRedirect('/', s), onboardingConsentPath);
      expect(onboardingRedirect('/biomarkers', s), onboardingConsentPath);
      expect(onboardingRedirect('/settings', s), onboardingConsentPath);
      expect(onboardingRedirect(onboardingConsentPath, s), isNull);
    });

    test('the profile step cannot be used to skip consent', () {
      expect(onboardingRedirect(onboardingProfilePath, _data(_status(missing: ['privacy']))),
          onboardingConsentPath);
    });

    test('after consent, the patient is held on the profile step', () {
      final s = _data(_status());
      expect(onboardingRedirect('/', s), onboardingProfilePath);
      expect(onboardingRedirect(onboardingConsentPath, s), onboardingProfilePath);
      expect(onboardingRedirect(onboardingProfilePath, s), isNull);
    });

    test('account deletion and record linking stay reachable while gated', () {
      final s = _data(_status(missing: ['terms']));
      expect(onboardingRedirect('/delete-account', s), isNull);
      expect(onboardingRedirect('/link-record', s), isNull);
    });

    test('an unlinked account is sent to link its record', () {
      final s = _data(_status(linked: false));
      expect(onboardingRedirect('/', s), '/link-record');
      expect(onboardingRedirect(onboardingConsentPath, s), '/link-record');
      expect(onboardingRedirect('/link-record', s), isNull);
    });

    test('once done, the app is open and onboarding pages go home', () {
      final s = _data(_status(profile: true));
      expect(onboardingRedirect('/', s), isNull);
      expect(onboardingRedirect('/progress', s), isNull);
      expect(onboardingRedirect(onboardingConsentPath, s), '/');
      expect(onboardingRedirect(onboardingProfilePath, s), '/');
    });

    test('fails closed: a status error holds the patient on the consent step', () {
      final err = AsyncValue<OnboardingStatus?>.error(Exception('offline'), StackTrace.empty);
      expect(onboardingRedirect('/', err), onboardingConsentPath);
      expect(onboardingRedirect('/delete-account', err), isNull);
    });

    test('a loading or missing status stays off clinical pages', () {
      expect(onboardingRedirect('/', const AsyncValue<OnboardingStatus?>.loading()), onboardingConsentPath);
      expect(onboardingRedirect('/', const AsyncValue<OnboardingStatus?>.data(null)), onboardingConsentPath);
      expect(onboardingRedirect(onboardingConsentPath, const AsyncValue<OnboardingStatus?>.loading()), isNull);
      expect(onboardingRedirect('/delete-account', const AsyncValue<OnboardingStatus?>.data(null)), isNull);
    });
  });

  group('ClinicalProfile', () {
    test('height conversions round-trip to the nearest inch / 0.1 cm', () {
      expect(feetInchesToCm(5, 7), 170.2);
      expect(feetInchesToCm(6, 0), 182.9);
      expect(cmToFeetInches(170.2), (feet: 5, inches: 7));
      expect(cmToFeetInches(182.88), (feet: 6, inches: 0));
      // 5 ft 11.6 in rounds up into 6 ft 0 in, never "5 ft 12 in".
      expect(cmToFeetInches(181.9), (feet: 6, inches: 0));
    });

    test('age and the adult-only cutoff', () {
      final today = DateTime(2026, 11, 5);
      expect(ageOn(DateTime(2008, 11, 5), today), 18);
      expect(ageOn(DateTime(2008, 11, 6), today), 17);
      expect(latestAllowedDob(today), DateTime(2008, 11, 5));
      // 29 Feb today -> 28 Feb eighteen years ago (not a leap year).
      expect(latestAllowedDob(DateTime(2028, 2, 29)), DateTime(2010, 2, 28));
    });

    test('reads my_patient_profile and writes update_patient_profile params', () {
      final p = ClinicalProfile.fromJson({
        'display_name': 'Jordan Rivera',
        'date_of_birth': '1980-05-01',
        'sex_at_birth': 'female',
        'height_cm': 165.0,
        'unit_system': 'imperial',
      });
      expect(p.isComplete, isTrue);
      expect(p.sexAtBirth, SexAtBirth.female);
      expect(p.toRpcParams(), {
        'p_display_name': 'Jordan Rivera',
        'p_date_of_birth': '1980-05-01',
        'p_sex_at_birth': 'female',
        'p_height_cm': 165.0,
        'p_unit_system': 'imperial',
      });
    });

    test('a profile with only the staff-entered name is incomplete', () {
      final p = ClinicalProfile.fromJson({'display_name': 'Jordan Rivera'});
      expect(p.isComplete, isFalse);
      expect(p.dateOfBirth, isNull);
      expect(SexAtBirth.fromWire('unknown'), isNull);
    });
  });
}
