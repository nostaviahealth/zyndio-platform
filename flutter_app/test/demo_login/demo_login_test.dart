// Demo login: off unless built with DEMO_LOGIN=true, never in release builds,
// and when on it signs into a fictional session with fictional data.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo_login/demo_login.dart';
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/providers/body_composition_provider.dart';
import 'package:zyndio_patient/providers/intelligence_provider.dart';
import 'package:zyndio_patient/providers/lab_reports_provider.dart';
import 'package:zyndio_patient/providers/onboarding_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';

void main() {
  test('off by default (no DEMO_LOGIN define in normal and store builds)', () {
    expect(kDemoLoginEnabled, isFalse);
  });

  test('the switch is compiled out of release builds whatever the define says', () {
    final src = File('lib/demo_login/demo_login.dart').readAsStringSync();
    expect(
      src.contains('const bool kDemoLoginEnabled = _demoLoginDefine && !kReleaseMode;'),
      isTrue,
      reason: 'kDemoLoginEnabled must stay gated on !kReleaseMode',
    );
  });

  test('the sign-in button and sign-out hook are both behind kDemoLoginEnabled', () {
    final signIn = File('lib/screens/auth/code_sign_in_screen.dart').readAsStringSync();
    expect(signIn.contains('if (kDemoLoginEnabled) ...['), isTrue);
    final auth = File('lib/providers/auth_provider.dart').readAsStringSync();
    expect(auth.contains('if (kDemoLoginEnabled && ref.read(demoSessionProvider))'), isTrue);
  });

  group('demoLoginOverrides', () {
    late ProviderContainer container;
    setUp(() {
      container = ProviderContainer(overrides: demoLoginOverrides());
      // The router watches auth state in the app; Riverpod 3 pauses providers
      // nobody listens to, so listen here the same way.
      container.listen(authStateProvider, (_, __) {});
    });
    tearDown(() => container.dispose());

    test('signed out until "Explore the demo", then the fictional demo user', () async {
      expect(await container.read(authStateProvider.future), isNull);
      container.read(demoSessionProvider.notifier).start();
      final user = await container.read(authStateProvider.future);
      expect(user?.id, demoUser.id);
      expect(user?.email, endsWith('@example.test'));
    });

    test('onboarding is complete so the demo lands on Today', () async {
      final status = await container.read(onboardingStatusProvider.future);
      expect(status?.nextRoute, isNull);
      expect(onboardingRedirect('/', AsyncValue.data(status)), isNull);
    });

    test('every tab has fictional data', () async {
      expect((await container.read(patientProfileProvider.future))?.name, 'Jordan Rivera');
      final labs = await container.read(labReportsProvider.future);
      expect(labs, hasLength(2));
      expect(labs.first.markers, isNotEmpty);
      final scans = await container.read(bodyCompositionScansProvider.future);
      expect(scans.single.measures, isNotEmpty);
      expect(container.read(aiInsightsProvider), isNotEmpty);
    });

    test('ending the session signs the demo user out', () async {
      container.read(demoSessionProvider.notifier).start();
      expect(await container.read(authStateProvider.future), isNotNull);
      container.read(demoSessionProvider.notifier).end();
      expect(await container.read(authStateProvider.future), isNull);
    });
  });
}
