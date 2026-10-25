import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/logic/clock.dart';

void main() {
  group('DemoBackend code flow', () {
    test('verifies the issued code', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);

      backend.sendCode('jordan.rivera@example.com');
      expect(
        backend.verifyCode(DemoBackend.issuedCode),
        CodeVerifyResult.success,
      );
    });

    test('expires the code after 10 minutes', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);

      backend.sendCode('jordan.rivera@example.com');
      clock.advance(const Duration(minutes: 10));
      expect(
        backend.verifyCode(DemoBackend.issuedCode),
        CodeVerifyResult.expired,
      );
    });

    test('locks after 5 wrong codes and clears the issued code', () {
      final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
      final backend = DemoBackend(clock: clock);
      backend.sendCode('jordan.rivera@example.com');

      for (var i = 0; i < 4; i++) {
        expect(backend.verifyCode('000000'), CodeVerifyResult.invalid);
      }
      expect(backend.verifyCode('000000'), CodeVerifyResult.locked);
      expect(
        backend.verifyCode(DemoBackend.issuedCode),
        CodeVerifyResult.locked,
      );
    });
  });

  group('DemoBackend consent', () {
    test('stores a versioned, timestamped record per agreed doc', () {
      final clock = FakeClock(DateTime(2026, 10, 23, 9, 0, 0));
      final backend = DemoBackend(clock: clock);

      backend.agreeToDoc('terms');
      backend.agreeToDoc('privacy');
      backend.agreeToDoc('consent');

      expect(backend.consentRecords, hasLength(3));
      for (final record in backend.consentRecords) {
        expect(record.version, '0.1');
        expect(record.agreedAt, clock.now());
      }
    });
  });
}
