import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// SHA-256 hex digest of [bytes], used to detect duplicate lab-report uploads.
String sha256Hex(Uint8List bytes) => sha256.convert(bytes).toString();

class DuplicateCheckResult {
  const DuplicateCheckResult({required this.isDuplicate});

  final bool isDuplicate;
}

/// Flags a hash already seen for a patient. Never blocks the upload — the
/// screen must still offer "Upload anyway".
class DuplicateDetector {
  const DuplicateDetector();

  DuplicateCheckResult check(
    String hash,
    String patientId,
    Set<String> priorHashes,
  ) {
    return DuplicateCheckResult(isDuplicate: priorHashes.contains(hash));
  }
}
