import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/logic/code_expiry.dart';

void main() {
  group('CodeExpiryPolicy', () {
    const policy = CodeExpiryPolicy();
    final issuedAt = DateTime(2026, 1, 1, 9, 0, 0);

    test('is not expired before 10 minutes', () {
      final now = issuedAt.add(const Duration(minutes: 9, seconds: 59));
      expect(policy.isExpired(issuedAt, now), isFalse);
    });

    test('is expired at exactly 10 minutes', () {
      final now = issuedAt.add(const Duration(minutes: 10));
      expect(policy.isExpired(issuedAt, now), isTrue);
    });

    test('is expired after 10 minutes', () {
      final now = issuedAt.add(const Duration(minutes: 10, seconds: 1));
      expect(policy.isExpired(issuedAt, now), isTrue);
    });
  });
}
