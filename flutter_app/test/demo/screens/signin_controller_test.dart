import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/logic/clock.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_controller.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_state.dart';

/// Counts verifyCode calls that actually reach the (offline) server, so a
/// test can prove the controller never sent an incomplete code. Everything
/// else is the real DemoBackend, including its attempt counter and lockout.
class _CountingBackend extends DemoBackend {
  _CountingBackend({required super.clock});

  int verifyCalls = 0;

  @override
  (CodeVerifyResult, DemoSession?) verifyCode(String email, String code) {
    verifyCalls++;
    return super.verifyCode(email, code);
  }
}

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

    test('TC-029: a wrong (invalid) code sets a clear inline error, no session', () {
      // Fail-first: before TC-029, submitCode handled only locked/success, so
      // an invalid result set no errorText and the code field showed nothing.
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      controller.updateEmail(demoPatient.email);
      controller.sendCode();
      controller.updateCode('000000'); // not the issued code
      final result = controller.submitCode();

      expect(result, CodeVerifyResult.invalid);
      final state = container.read(signInControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.errorText, contains("isn't right"));
      expect(state.session, isNull);
      expect(container.read(currentSessionProvider), isNull);
    });

    test('TC-029: an expired code sets a clear inline error telling how to get a new one', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      controller.updateEmail(demoPatient.email);
      controller.sendCode();
      // Expiry is checked before the code is matched, so any entry hits it.
      clock.advance(const Duration(minutes: 10, seconds: 1));
      controller.updateCode('123456');
      final result = controller.submitCode();

      expect(result, CodeVerifyResult.expired);
      final state = container.read(signInControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.errorText, contains('expired'));
      expect(state.errorText, contains('Send a new code'));
      expect(container.read(currentSessionProvider), isNull);
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

    test('TC-029 review (Clara H2): an empty, short or non-numeric code shows "Enter the 6-digit code" and never reaches the server', () {
      // Fail-first: before the fix every Continue tap went to verifyCode, so
      // each incomplete entry spent one of the 5 attempts.
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = _CountingBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      controller.updateEmail(demoPatient.email);
      controller.sendCode();

      // Letters are filtered out by the code field, so a letters-only entry
      // arrives as ''; 'abc123' covers a value that bypasses the field.
      for (final entry in ['', '1', '12345', 'abc123', '12 345', '1234567']) {
        controller.updateCode(entry);
        final result = controller.submitCode();
        expect(result, isNull, reason: 'entry "$entry" must not be submitted');
        final state = container.read(signInControllerProvider);
        expect(state.errorText, 'Enter the 6-digit code.', reason: 'entry "$entry"');
        expect(state.isLocked, isFalse, reason: 'entry "$entry"');
      }
      expect(backend.verifyCalls, 0);

      // None of those spent an attempt: 6 incomplete entries plus 4 wrong
      // codes would be past the 5-attempt limit if they had counted, but the
      // 4th wrong code is still only "invalid", not "locked". (The issued
      // code itself is readable only in DEMO_BUILD, so it isn't used here.)
      for (var i = 0; i < 4; i++) {
        controller.updateCode('000000');
        expect(controller.submitCode(), CodeVerifyResult.invalid, reason: 'wrong try ${i + 1}');
      }
      expect(backend.verifyCalls, 4);
      expect(container.read(signInControllerProvider).isLocked, isFalse);
    });

    test('TC-029 review (Clara H2): the locked result replaces the wrong-code error with the lock state', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      controller.updateEmail(demoPatient.email);
      controller.sendCode();
      CodeVerifyResult? last;
      for (var i = 0; i < 6; i++) {
        controller.updateCode('000000');
        last = controller.submitCode();
      }

      expect(last, CodeVerifyResult.locked);
      final state = container.read(signInControllerProvider);
      expect(state.isLocked, isTrue);
      expect(state.stage, SignInStage.codeEntry);
      // The lock banner is the one message; the stale "isn't right" goes.
      expect(state.errorText, isNull);
    });

    test('TC-030 item 16: tapping submit twice on an unchanged full code spends two attempts', () {
      // Fail-first against L-r2-2: the earlier lockout test cleared the error
      // via updateCode before each submit, so it never proved a second submit
      // of the SAME code (no updateCode between taps) still counts. It does.
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = _CountingBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(signInControllerProvider.notifier);
      controller.updateEmail(demoPatient.email);
      controller.sendCode();
      controller.updateCode('000000');

      // No updateCode between the two submits: both must reach the server.
      expect(controller.submitCode(), CodeVerifyResult.invalid);
      expect(controller.submitCode(), CodeVerifyResult.invalid);
      expect(backend.verifyCalls, 2);

      // Three more taps of the unchanged code reach the 5-attempt lock.
      controller.submitCode();
      controller.submitCode();
      expect(controller.submitCode(), CodeVerifyResult.locked);
      expect(container.read(signInControllerProvider).isLocked, isTrue);
    });

    test('TC-030 item 14: the lock banner reports the real remaining minutes', () {
      // Fail-first: the state carried no remaining-minutes value before, so
      // the banner was the fixed "15 minutes" regardless of the real clock.
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
      expect(container.read(signInControllerProvider).lockedMinutesRemaining, 15);

      // 3 minutes into the 15-minute lock, another locked submit reports 12.
      clock.advance(const Duration(minutes: 3));
      controller.updateCode('000000');
      controller.submitCode();
      expect(container.read(signInControllerProvider).lockedMinutesRemaining, 12);
    });

    test('TC-030 item 17: while locked, a short code does not overwrite the lock with the 6-digit hint', () {
      // Fail-first: before the guard, submitCode set "Enter the 6-digit code."
      // for any incomplete entry, even while locked, so the code step showed
      // both the lock banner and that hint (Clara L-r2-3).
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

      // A short entry while locked: still locked, no inline hint set.
      controller.updateCode('12');
      expect(controller.submitCode(), isNull);
      final state = container.read(signInControllerProvider);
      expect(state.isLocked, isTrue);
      expect(state.errorText, isNull);
    });
  });
}
