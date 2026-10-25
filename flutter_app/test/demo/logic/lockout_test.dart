import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/logic/lockout.dart';

void main() {
  group('LockoutPolicy', () {
    test('5th wrong code locks the account for 15 minutes', () {
      final policy = LockoutPolicy();
      var now = DateTime(2026, 1, 1, 9, 0, 0);

      for (var i = 0; i < 4; i++) {
        policy.registerWrong(now);
        expect(policy.isLocked(now), isFalse);
      }

      policy.registerWrong(now);
      expect(policy.isLocked(now), isTrue);
      expect(policy.remaining(now), const Duration(minutes: 15));
    });

    test('unlocks after 15 minutes', () {
      final policy = LockoutPolicy();
      final lockedAt = DateTime(2026, 1, 1, 9, 0, 0);
      for (var i = 0; i < 5; i++) {
        policy.registerWrong(lockedAt);
      }
      expect(policy.isLocked(lockedAt), isTrue);

      final stillLocked = lockedAt.add(const Duration(minutes: 14, seconds: 59));
      expect(policy.isLocked(stillLocked), isTrue);

      final unlocked = lockedAt.add(const Duration(minutes: 15));
      expect(policy.isLocked(unlocked), isFalse);
      expect(policy.remaining(unlocked), Duration.zero);
    });
  });
}
