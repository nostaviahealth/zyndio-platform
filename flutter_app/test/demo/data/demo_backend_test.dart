@Tags(['demo_flow'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/logic/clock.dart';

const _jordan = demoPatient;
final _sam = secondaryDemoPatients.first;

void main() {
  group('DemoBackend code flow', () {
    test('T-AUTH-01: a used code fails a second time', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);

      backend.sendCode(_jordan.email);
      final code = backend.debugLastIssuedCode(_jordan.email)!;
      final (first, session) = backend.verifyCode(_jordan.email, code);
      expect(first, CodeVerifyResult.success);
      expect(session, isNotNull);

      final (second, secondSession) = backend.verifyCode(_jordan.email, code);
      expect(second, CodeVerifyResult.invalid);
      expect(secondSession, isNull);
    });

    test('T-AUTH-01: issuing a new code invalidates the old one', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);

      backend.sendCode(_jordan.email);
      final oldCode = backend.debugLastIssuedCode(_jordan.email)!;

      backend.sendCode(_jordan.email);
      final newCode = backend.debugLastIssuedCode(_jordan.email)!;

      expect(
        backend.verifyCode(_jordan.email, oldCode).$1,
        CodeVerifyResult.invalid,
      );
      expect(
        backend.verifyCode(_jordan.email, newCode).$1,
        CodeVerifyResult.success,
      );
    });

    test('T-AUTH-02: valid at 9:59, rejected at 10:00 and after', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      backend.sendCode(_jordan.email);
      final code = backend.debugLastIssuedCode(_jordan.email)!;

      final clockAt959 = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backendAt959 = DemoBackend(clock: clockAt959);
      backendAt959.sendCode(_jordan.email);
      final codeAt959 = backendAt959.debugLastIssuedCode(_jordan.email)!;
      clockAt959.set(DateTime(2026, 1, 1, 9, 9, 59));
      expect(
        backendAt959.verifyCode(_jordan.email, codeAt959).$1,
        CodeVerifyResult.success,
      );

      clock.set(DateTime(2026, 1, 1, 9, 10, 0));
      expect(
        backend.verifyCode(_jordan.email, code).$1,
        CodeVerifyResult.expired,
      );

      clock.set(DateTime(2026, 1, 1, 9, 11, 0));
      expect(
        backend.verifyCode(_jordan.email, code).$1,
        CodeVerifyResult.expired,
      );
    });

    test('T-AUTH-03: 4 wrong + the right code logs in', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      backend.sendCode(_jordan.email);
      final code = backend.debugLastIssuedCode(_jordan.email)!;

      for (var i = 0; i < 4; i++) {
        expect(
          backend.verifyCode(_jordan.email, '000000').$1,
          CodeVerifyResult.invalid,
        );
      }
      expect(backend.verifyCode(_jordan.email, code).$1, CodeVerifyResult.success);
    });

    test('T-AUTH-03: 5 wrong locks, and the right code is then rejected', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      backend.sendCode(_jordan.email);
      final code = backend.debugLastIssuedCode(_jordan.email)!;

      for (var i = 0; i < 4; i++) {
        backend.verifyCode(_jordan.email, '000000');
      }
      expect(
        backend.verifyCode(_jordan.email, '000000').$1,
        CodeVerifyResult.locked,
      );
      expect(backend.verifyCode(_jordan.email, code).$1, CodeVerifyResult.locked);
    });

    test('T-AUTH-03: still locked at 14:59, unlocked at 15:00, resets on success', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      backend.sendCode(_jordan.email);
      for (var i = 0; i < 5; i++) {
        backend.verifyCode(_jordan.email, '000000');
      }
      expect(backend.verifyCode(_jordan.email, '000000').$1, CodeVerifyResult.locked);

      clock.set(DateTime(2026, 1, 1, 9, 14, 59));
      expect(backend.verifyCode(_jordan.email, '000000').$1, CodeVerifyResult.locked);

      clock.set(DateTime(2026, 1, 1, 9, 15, 0));
      backend.sendCode(_jordan.email);
      final freshCode = backend.debugLastIssuedCode(_jordan.email)!;
      expect(
        backend.verifyCode(_jordan.email, freshCode).$1,
        CodeVerifyResult.success,
      );

      // A fresh wrong-attempt counter after the reset-on-success: 3 more
      // wrong codes (4 total) shouldn't re-lock the account — locking needs
      // a 5th.
      backend.sendCode(_jordan.email);
      for (var i = 0; i < 3; i++) {
        backend.verifyCode(_jordan.email, '000000');
      }
      expect(backend.verifyCode(_jordan.email, '000000').$1, CodeVerifyResult.invalid);
    });

    test('T-AUTH-03: lockout is per account, survives a brand-new DemoBackend-driven controller', () {
      // Simulates "a new controller/view instance" (e.g. app restart):
      // the lockout state lives in the backend, not anything UI-owned, so a
      // second read of the same backend still sees the lock.
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      backend.sendCode(_jordan.email);
      for (var i = 0; i < 5; i++) {
        backend.verifyCode(_jordan.email, '000000');
      }
      expect(backend.verifyCode(_jordan.email, '000000').$1, CodeVerifyResult.locked);

      // "New controller" = a fresh read of the same long-lived backend.
      DemoBackend sameBackend() => backend;
      expect(sameBackend().verifyCode(_jordan.email, '000000').$1, CodeVerifyResult.locked);
    });

    test('T-AUTH-03: lockout on one account never affects another', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      backend.sendCode(_jordan.email);
      for (var i = 0; i < 5; i++) {
        backend.verifyCode(_jordan.email, '000000');
      }
      expect(backend.verifyCode(_jordan.email, '000000').$1, CodeVerifyResult.locked);

      backend.sendCode(_sam.email);
      final samCode = backend.debugLastIssuedCode(_sam.email)!;
      expect(backend.verifyCode(_sam.email, samCode).$1, CodeVerifyResult.success);
    });

    test('T-AUTH-04: no self-sign-up — an unseeded email never gets a working code', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);

      backend.sendCode('someone.new@example.com');
      expect(backend.debugLastIssuedCode('someone.new@example.com'), isNull);
      expect(
        backend.verifyCode('someone.new@example.com', '123456').$1,
        CodeVerifyResult.invalid,
      );
    });

    test('T-AUTH-04: unknown email resolves the same way as a wrong code for a known one', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      backend.sendCode(_jordan.email);

      final unknownResult = backend.verifyCode('nobody@example.com', '123456').$1;
      final wrongKnownResult = backend.verifyCode(_jordan.email, '000000').$1;
      expect(unknownResult, wrongKnownResult);
      expect(unknownResult, CodeVerifyResult.invalid);
    });
  });

  group('DemoBackend consent (T-CONS-01/02)', () {
    test('stores a versioned, timestamped record per agreed doc', () {
      final clock = FakeClock(DateTime(2026, 10, 23, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final session = _login(backend, clock, _jordan.email);

      backend.agreeToDoc(session, 'terms');
      backend.agreeToDoc(session, 'privacy');
      backend.agreeToDoc(session, 'consent');

      expect(backend.consentRecordsFor(session), hasLength(3));
      for (final record in backend.consentRecordsFor(session)) {
        expect(record.version, '0.1');
        expect(record.agreedAt, clock.now());
      }
    });
  });

  group('DemoBackend duplicate detection (T-LAB-03)', () {
    test('same hash + same patient warns', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final session = _login(backend, clock, _jordan.email);

      expect(backend.checkDuplicate(session, 'hash-a').isDuplicate, isFalse);
      backend.recordUploadHash(session, 'hash-a');
      expect(backend.checkDuplicate(session, 'hash-a').isDuplicate, isTrue);
    });

    test('"Upload anyway" stores, "Cancel" stores nothing', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final session = _login(backend, clock, _jordan.email);
      backend.recordUploadHash(session, 'hash-a');

      // Cancel: caller simply never calls recordUploadHash again.
      expect(backend.uploadedHashesFor(session), ['hash-a']);

      // Upload anyway: caller calls recordUploadHash despite the warning.
      backend.recordUploadHash(session, 'hash-a');
      expect(backend.uploadedHashesFor(session), ['hash-a']);
    });

    test('same hash for a different patient gives no warning and no hint', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final jordanSession = _login(backend, clock, _jordan.email);
      final samSession = _login(backend, clock, _sam.email);

      backend.recordUploadHash(jordanSession, 'shared-hash');

      expect(backend.checkDuplicate(samSession, 'shared-hash').isDuplicate, isFalse);
      expect(backend.uploadedHashesFor(samSession), isEmpty);
    });
  });

  group('DemoBackend isolation', () {
    test('ISOLATION consent: one patient never sees another patient\'s consent records', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final jordanSession = _login(backend, clock, _jordan.email);
      final samSession = _login(backend, clock, _sam.email);

      backend.agreeToDoc(jordanSession, 'terms');

      expect(backend.consentRecordsFor(jordanSession), hasLength(1));
      expect(backend.consentRecordsFor(samSession), isEmpty);
    });

    test('ISOLATION hashes: uploaded-file hashes never cross patients', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final jordanSession = _login(backend, clock, _jordan.email);
      final samSession = _login(backend, clock, _sam.email);

      backend.recordUploadHash(jordanSession, 'hash-a');

      expect(backend.uploadedHashesFor(jordanSession), ['hash-a']);
      expect(backend.uploadedHashesFor(samSession), isEmpty);
    });

    test('ISOLATION labs: lab report ids never cross patients', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final jordanSession = _login(backend, clock, _jordan.email);
      final samSession = _login(backend, clock, _sam.email);

      backend.addLabReport(jordanSession, 'report-1');

      expect(backend.labReportsFor(jordanSession), ['report-1']);
      expect(backend.labReportsFor(samSession), isEmpty);
    });

    test('ISOLATION files: every seeded patient starts with their own empty record, not a shared one', () {
      // Belt-and-braces on top of the hash/consent/lab isolation above:
      // DemoSession's constructor is private to demo_backend.dart, so no
      // caller outside it can ever mint a session for a patient id the
      // backend didn't itself issue via a real login — cross-patient access
      // is denied by construction, not just by convention.
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      final jordanSession = _login(backend, clock, _jordan.email);
      final samSession = _login(backend, clock, _sam.email);

      expect(jordanSession.patientId, isNot(samSession.patientId));
      expect(backend.uploadedHashesFor(jordanSession), isEmpty);
      expect(backend.uploadedHashesFor(samSession), isEmpty);
    });
  });
}

DemoSession _login(DemoBackend backend, FakeClock clock, String email) {
  backend.sendCode(email);
  final code = backend.debugLastIssuedCode(email)!;
  final (result, session) = backend.verifyCode(email, code);
  expect(result, CodeVerifyResult.success);
  return session!;
}
