import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/logic/clock.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_controller.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_state.dart';

void main() {
  group('SignInController', () {
    test('T-AUTH-04: an unknown but well-formed email takes the same UI path as a known one', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      controller.updateEmail('nobody@example.com');
      controller.sendCode();

      expect(container.read(signInControllerProvider).stage, SignInStage.codeEntry);
      expect(container.read(signInControllerProvider).hasError, isFalse);
    });

    test(
      'T-AUTH-04: there is no self-sign-up — no code is ever issued to an unknown email',
      tags: ['demo_flow'],
      () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      container.read(signInControllerProvider.notifier)
        ..updateEmail('nobody@example.com')
        ..sendCode();

      expect(backend.debugLastIssuedCode('nobody@example.com'), isNull);
    });

    test('malformed email shows an inline error and stays on the email step', () {
      final backend = DemoBackend(clock: const SystemClock());
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      controller.updateEmail('not-an-email');
      controller.sendCode();

      final state = container.read(signInControllerProvider);
      expect(state.stage, SignInStage.emailEntry);
      expect(state.hasError, isTrue);
    });

    test(
      'a successful verify stores the session for downstream screens',
      tags: ['demo_flow'],
      () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      controller.updateEmail(demoPatient.email);
      controller.sendCode();
      final code = backend.debugLastIssuedCode(demoPatient.email)!;
      controller.updateCode(code);
      final result = controller.submitCode();

      expect(result, CodeVerifyResult.success);
      expect(container.read(signInControllerProvider).session, isNotNull);
      expect(container.read(currentSessionProvider), isNotNull);
    });

    test('a locked verify sets isLocked', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      controller.updateEmail(demoPatient.email);
      controller.sendCode();
      for (var i = 0; i < 5; i++) {
        controller.updateCode('000000');
        controller.submitCode();
      }

      expect(container.read(signInControllerProvider).isLocked, isTrue);
    });
  });
}
