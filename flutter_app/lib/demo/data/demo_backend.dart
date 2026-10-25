import '../logic/clock.dart';
import '../logic/code_expiry.dart';
import '../logic/file_hash.dart';
import '../logic/lockout.dart';
import '../logic/upload_queue.dart';

enum CodeVerifyResult { success, invalid, expired, locked }

class ConsentRecord {
  const ConsentRecord({
    required this.docId,
    required this.version,
    required this.agreedAt,
  });

  final String docId;
  final String version;
  final DateTime agreedAt;
}

/// In-memory, deterministic fake backend for the offline demo. No network.
class DemoBackend {
  DemoBackend({Clock clock = const SystemClock()})
      : _clock = clock,
        codeExpiryPolicy = const CodeExpiryPolicy(),
        lockoutPolicy = LockoutPolicy(),
        uploadQueue = UploadQueue();

  /// The only code this backend ever issues/accepts, so screenshots and
  /// tests are deterministic.
  static const String issuedCode = '123456';

  final Clock _clock;
  final CodeExpiryPolicy codeExpiryPolicy;
  final LockoutPolicy lockoutPolicy;
  final UploadQueue uploadQueue;
  final DuplicateDetector _duplicateDetector = const DuplicateDetector();

  DateTime? _codeIssuedAt;
  final List<ConsentRecord> _consentRecords = [];
  final Set<String> _uploadedHashes = {};

  void sendCode(String email) {
    _codeIssuedAt = _clock.now();
  }

  CodeVerifyResult verifyCode(String code) {
    final now = _clock.now();
    if (lockoutPolicy.isLocked(now)) return CodeVerifyResult.locked;

    final issuedAt = _codeIssuedAt;
    if (issuedAt == null) return CodeVerifyResult.invalid;
    if (codeExpiryPolicy.isExpired(issuedAt, now)) {
      return CodeVerifyResult.expired;
    }

    if (code != issuedCode) {
      lockoutPolicy.registerWrong(now);
      return lockoutPolicy.isLocked(now)
          ? CodeVerifyResult.locked
          : CodeVerifyResult.invalid;
    }

    lockoutPolicy.reset();
    return CodeVerifyResult.success;
  }

  void agreeToDoc(String docId, {String version = '0.1'}) {
    _consentRecords.add(
      ConsentRecord(docId: docId, version: version, agreedAt: _clock.now()),
    );
  }

  List<ConsentRecord> get consentRecords => List.unmodifiable(_consentRecords);

  DuplicateCheckResult checkDuplicate(String hash, String patientId) =>
      _duplicateDetector.check(hash, patientId, _uploadedHashes);

  void recordUploadHash(String hash) => _uploadedHashes.add(hash);
}
