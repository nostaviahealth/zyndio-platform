import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/logic/file_hash.dart';

void main() {
  group('sha256Hex', () {
    test('is deterministic for the same bytes', () {
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(sha256Hex(bytes), sha256Hex(Uint8List.fromList([1, 2, 3])));
    });

    test('differs for different bytes', () {
      expect(
        sha256Hex(Uint8List.fromList([1, 2, 3])),
        isNot(sha256Hex(Uint8List.fromList([4, 5, 6]))),
      );
    });
  });

  group('DuplicateDetector', () {
    const detector = DuplicateDetector();

    test('flags a hash already seen for the patient as a warning, not a block', () {
      final priorHashes = {'abc123'};
      final result = detector.check('abc123', 'jordan-rivera', priorHashes);
      expect(result.isDuplicate, isTrue);
    });

    test('does not flag a new hash', () {
      final priorHashes = {'abc123'};
      final result = detector.check('def456', 'jordan-rivera', priorHashes);
      expect(result.isDuplicate, isFalse);
    });
  });
}
