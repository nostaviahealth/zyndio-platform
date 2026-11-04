// APP-01 / APP-02 / APP-04 screens: code sign-in, consent, profile setup,
// and account deletion with a code.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/models/clinical_profile.dart';
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/providers/onboarding_provider.dart';
import 'package:zyndio_patient/screens/auth/code_sign_in_screen.dart';
import 'package:zyndio_patient/screens/auth/delete_account_screen.dart';
import 'package:zyndio_patient/screens/onboarding/consent_screen.dart';
import 'package:zyndio_patient/screens/onboarding/profile_setup_screen.dart';
import 'package:zyndio_patient/widgets/clinical_profile_form.dart';

import 'fakes.dart';

Widget _app(Widget child, {required List overrides}) => ProviderScope(
      overrides: [...overrides],
      child: MaterialApp(theme: BrandTheme.lightTheme, home: child),
    );

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(
    find.descendant(of: find.byKey(const Key('code-signin-code')), matching: find.byType(TextField)),
    code,
  );
  await tester.pump();
}

void main() {
  group('CodeSignInScreen (APP-01)', () {
    late FakeCodeAuthNotifier auth;
    Widget screen({bool selfSignup = false}) => _app(
          const CodeSignInScreen(),
          overrides: [
            authNotifierProvider.overrideWith(() => auth),
            selfSignupEnabledProvider.overrideWith((ref) async => selfSignup),
          ],
        );

    setUp(() => auth = FakeCodeAuthNotifier());

    testWidgets('asks for the enrolment email: no password, no sign-up by default', (tester) async {
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(find.text('Sign in to your care program'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
      expect(find.text('Password'), findsNothing);
      expect(find.text('Create an account'), findsNothing);
      expect(find.textContaining('Ask them to send you an invite'), findsOneWidget);
    });

    testWidgets('offers sign-up and password log-in only when the org turned self-sign-up on',
        (tester) async {
      await tester.pumpWidget(screen(selfSignup: true));
      await tester.pump();
      expect(find.text('Create an account'), findsOneWidget);
      expect(find.text('Log in with a password'), findsOneWidget);
    });

    testWidgets('rejects a malformed email without calling the server', (tester) async {
      await tester.pumpWidget(screen());
      await tester.enterText(find.byKey(const Key('code-signin-email')), 'not-an-email');
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(auth.requested, isEmpty);
    });

    testWidgets('sends the code and moves to code entry with a masked email', (tester) async {
      await tester.pumpWidget(screen());
      await tester.enterText(find.byKey(const Key('code-signin-email')), ' Jordan.Rivera@Example.test ');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(auth.requested, ['jordan.rivera@example.test']);
      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.textContaining('j•••••@example.test'), findsOneWidget);
    });

    testWidgets('a short code is caught locally and never spends a try', (tester) async {
      await tester.pumpWidget(screen());
      await tester.enterText(find.byKey(const Key('code-signin-email')), 'jordan@example.test');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      await _enterCode(tester, '417');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Enter the 6-digit code.'), findsOneWidget);
      expect(auth.verified, isEmpty);
    });

    testWidgets('verifies a full code; a wrong one shows the inline error', (tester) async {
      auth.verifyError = PatientAuthException('invalid_code');
      await tester.pumpWidget(screen());
      await tester.enterText(find.byKey(const Key('code-signin-email')), 'jordan@example.test');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      await _enterCode(tester, '482913');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(auth.verified, [('jordan@example.test', '482913')]);
      expect(find.text("That code isn't right. Check it and try again."), findsOneWidget);
    });

    testWidgets('lockout shows the real minutes left and disables Continue', (tester) async {
      auth.verifyError = PatientAuthException('locked', retryAfterSeconds: 14 * 60 + 30);
      await tester.pumpWidget(screen());
      await tester.enterText(find.byKey(const Key('code-signin-email')), 'jordan@example.test');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      await _enterCode(tester, '000000');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Too many attempts. Try again in 15 min, or contact your care team.'), findsOneWidget);

      await _enterCode(tester, '111111');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(auth.verified.length, 1, reason: 'locked: Continue does nothing');
    });
  });

  group('OnboardingConsentScreen (APP-02)', () {
    late FakeOnboardingRepository repo;
    final docs = [fakeDoc('terms'), fakeDoc('privacy'), fakeDoc('health_data')];

    Widget screen() => _app(
          const OnboardingConsentScreen(),
          overrides: [
            patientOnboardingRepositoryProvider.overrideWithValue(repo),
            onboardingStatusProvider.overrideWith((ref) async => repo.status),
          ],
        );

    setUp(() => repo = FakeOnboardingRepository(
          status: OnboardingStatus(linked: true, missingConsents: docs, profileComplete: false),
        ));

    testWidgets('lists the three required documents, marked placeholder', (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Notice'), findsOneWidget);
      expect(find.text('Consent to use my health data'), findsOneWidget);
      expect(find.text('Version 0.1 · placeholder text'), findsNWidgets(3));
    });

    testWidgets('nothing is recorded until every required document is ticked', (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Terms of Service'));
      await tester.pump();
      await tester.tap(find.text('Agree and continue'));
      await tester.pump();
      expect(find.text('Required to continue'), findsNWidgets(2));
      expect(repo.granted, isEmpty);
    });

    testWidgets('agreeing records each document at the version shown', (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      for (final title in ['Terms of Service', 'Privacy Notice', 'Consent to use my health data']) {
        await tester.tap(find.text(title));
        await tester.pump();
      }
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(repo.granted.single.map((d) => '${d.consentType}@${d.version}'),
          ['terms@0.1', 'privacy@0.1', 'health_data@0.1']);
    });

    testWidgets('Read opens the document text with the placeholder warning', (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('PLACEHOLDER - NOT THE FINAL TEXT for terms'), findsOneWidget);
      expect(find.textContaining('Placeholder text. Zyndio will supply'), findsOneWidget);
    });

    testWidgets('a stale version asks the patient to review again', (tester) async {
      repo.grantError = OnboardingException('consent_version_stale');
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      for (final title in ['Terms of Service', 'Privacy Notice', 'Consent to use my health data']) {
        await tester.tap(find.text(title));
        await tester.pump();
      }
      await tester.tap(find.text('Agree and continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining('was just updated'), findsOneWidget);
    });
  });

  group('OnboardingProfileScreen (APP-04)', () {
    late FakeOnboardingRepository repo;

    Widget screen() => _app(
          const OnboardingProfileScreen(),
          overrides: [
            patientOnboardingRepositoryProvider.overrideWithValue(repo),
            onboardingStatusProvider.overrideWith((ref) async => repo.status),
            clinicalProfileProvider.overrideWith((ref) async => repo.profile),
          ],
        );

    setUp(() => repo = FakeOnboardingRepository(
          status: const OnboardingStatus(linked: true, missingConsents: [], profileComplete: false),
          profile: const ClinicalProfile(displayName: 'Jordan Rivera'),
        ));

    testWidgets('prefills the care-team name and requires the other fields', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Jordan Rivera'), findsOneWidget);
      expect(find.text('Sex assigned at birth'), findsOneWidget);
      expect(find.text('Used to pick the right reference ranges for your lab results.'), findsOneWidget);
      expect(find.text('Used to work out your BMI.'), findsOneWidget);

      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your date of birth.'), findsOneWidget);
      expect(find.text('Choose one.'), findsOneWidget);
      expect(repo.saved, isEmpty);
    });
  });

  group('ClinicalProfileForm (APP-04)', () {
    Future<List<ClinicalProfile>> submit(WidgetTester tester, ClinicalProfile initial,
        {void Function()? before}) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final out = <ClinicalProfile>[];
      await tester.pumpWidget(MaterialApp(
        theme: BrandTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ClinicalProfileForm(
              initial: initial,
              submitLabel: 'Save',
              today: DateTime(2026, 11, 5),
              onSubmit: (p) async => out.add(p),
            ),
          ),
        ),
      ));
      before?.call();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      return out;
    }

    testWidgets('imperial height is entered in ft/in and saved in cm', (tester) async {
      final out = await submit(
        tester,
        ClinicalProfile(
          displayName: 'Jordan Rivera',
          dateOfBirth: DateTime(1980, 5, 1),
          sexAtBirth: SexAtBirth.female,
          heightCm: 170.2,
          unitSystem: UnitSystem.imperial,
        ),
      );
      expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '7'), findsOneWidget);
      expect(out.single.heightCm, 170.2);
      expect(out.single.unitSystem, UnitSystem.imperial);
    });

    testWidgets('an under-18 date of birth is refused (adult program)', (tester) async {
      final out = await submit(
        tester,
        ClinicalProfile(
          displayName: 'Jordan Rivera',
          dateOfBirth: DateTime(2008, 11, 6),
          sexAtBirth: SexAtBirth.male,
          heightCm: 180,
          unitSystem: UnitSystem.metric,
        ),
      );
      expect(find.text('You need to be 18 or older to join this program.'), findsOneWidget);
      expect(out, isEmpty);
    });

    testWidgets('an impossible height is refused', (tester) async {
      final out = await submit(
        tester,
        ClinicalProfile(
          displayName: 'Jordan Rivera',
          dateOfBirth: DateTime(1980, 5, 1),
          sexAtBirth: SexAtBirth.intersex,
          heightCm: 300,
          unitSystem: UnitSystem.metric,
        ),
      );
      expect(find.text('Enter a height between 50 and 272 cm.'), findsOneWidget);
      expect(out, isEmpty);
    });
  });

  group('DeleteAccountScreen with a code (APP-01, Apple 5.1.1(v))', () {
    testWidgets('a passwordless patient confirms with an emailed code', (tester) async {
      final auth = FakeCodeAuthNotifier();
      await tester.pumpWidget(_app(
        const DeleteAccountScreen(email: 'jordan@example.test', reauthWithCode: true),
        overrides: [authNotifierProvider.overrideWith(() => auth)],
      ));
      expect(find.byType(TextFormField), findsNothing, reason: 'no password field');
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(auth.requested, ['jordan@example.test']);

      await tester.enterText(
        find.descendant(of: find.byKey(const Key('delete-account-code')), matching: find.byType(TextField)),
        '482913',
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.text('Delete my account'), findsOneWidget);

      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(auth.deletedWithCode, ['482913']);
      expect(find.text('Your account is deleted'), findsOneWidget);
    });

    testWidgets('a spent code goes back to re-auth with the error', (tester) async {
      final auth = FakeCodeAuthNotifier()..deleteError = PatientAuthException('reauth_failed');
      await tester.pumpWidget(_app(
        const DeleteAccountScreen(email: 'jordan@example.test', reauthWithCode: true),
        overrides: [authNotifierProvider.overrideWith(() => auth)],
      ));
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: find.byKey(const Key('delete-account-code')), matching: find.byType(TextField)),
        '482913',
      );
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(find.text("Confirm it's you"), findsOneWidget);
      expect(find.textContaining('expired or was already used'), findsOneWidget);
    });
  });
}
