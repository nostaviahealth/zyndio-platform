import '../logic/clock.dart';
import '../logic/code_expiry.dart';
import '../logic/file_hash.dart';
import '../logic/lockout.dart';
import 'fixtures.dart';

enum CodeVerifyResult { success, invalid, expired, locked }

/// Thrown when code touches another patient's data through a stale or
/// mismatched session. Every real call path is scoped by [DemoSession], so
/// this only fires on a programming error — never silently returns data.
class AccessDeniedException implements Exception {
  const AccessDeniedException(this.message);

  final String message;

  @override
  String toString() => 'AccessDeniedException: $message';
}

/// Opaque handle returned by a successful [DemoBackend.verifyCode]. All
/// lab/file/consent/hash reads and writes take a session and are scoped to
/// that session's patient only.
class DemoSession {
  const DemoSession._(this.patientId);

  final String patientId;
}

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

class _Account {
  _Account({required this.patientId});

  final String patientId;
  final LockoutPolicy lockoutPolicy = LockoutPolicy();
  String? issuedCode;
  DateTime? issuedAt;
  bool used = false;
}

class _PatientRecord {
  final List<ConsentRecord> consentRecords = [];
  final Set<String> uploadedHashes = {};
  final List<String> labReportIds = [];
}

/// In-memory, deterministic fake backend for the offline demo. No network.
///
/// Multi-patient: accounts are keyed by email and seeded once from the
/// fictional fixtures — there is no self-sign-up API, so an unverified email
/// can never acquire an account. Every other piece of state (codes, lockout,
/// consent, uploaded-file hashes, lab reports) is scoped per account/patient
/// so one patient's data is never visible through another patient's session.
class DemoBackend {
  DemoBackend({Clock clock = const SystemClock()})
      : _clock = clock,
        codeExpiryPolicy = const CodeExpiryPolicy(),
        _duplicateDetector = const DuplicateDetector() {
    for (final patient in allDemoPatients) {
      final id = 'patient-${_accountsByEmail.length}';
      _accountsByEmail[_normalize(patient.email)] = _Account(patientId: id);
      _patients[id] = _PatientRecord();
    }
  }

  final Clock _clock;
  final CodeExpiryPolicy codeExpiryPolicy;
  final DuplicateDetector _duplicateDetector;

  final Map<String, _Account> _accountsByEmail = {};
  final Map<String, _PatientRecord> _patients = {};
  int _issueCounter = 0;

  static String _normalize(String email) => email.trim().toLowerCase();

  /// Issues (or re-issues) a sign-in code for [email]. Unknown emails are a
  /// silent no-op server-side — there is no self-sign-up API — but the
  /// method never throws or signals that difference, so the caller/UI path
  /// is identical for a known and an unknown email (no enumeration).
  /// Issuing a new code immediately invalidates any code issued earlier.
  void sendCode(String email) {
    final account = _accountsByEmail[_normalize(email)];
    if (account == null) return;
    final now = _clock.now();
    account.issuedAt = now;
    account.issuedCode = _generateCode(email, now);
    account.used = false;
  }

  String _generateCode(String email, DateTime issuedAt) {
    // Deterministic per issue (so demo runs/screenshots/tests are
    // reproducible given a FakeClock) but distinct per issue, so a reused
    // code never verifies after a new one is sent.
    final seed = Object.hash(email, issuedAt.microsecondsSinceEpoch, _issueCounter++);
    final sixDigits = seed.abs() % 1000000;
    return sixDigits.toString().padLeft(6, '0');
  }

  /// Demo/test-only hook: the code last issued to [email] (or `null` if none
  /// was issued, including for an unknown email). A real backend would only
  /// deliver this out-of-band by email — never call this from product code.
  String? debugLastIssuedCode(String email) =>
      _accountsByEmail[_normalize(email)]?.issuedCode;

  /// Verifies [code] against [email]'s own server-side expiry/lockout/used
  /// state. On success returns a [DemoSession] scoped to that patient;
  /// otherwise the session is `null`. Unknown emails and wrong codes both
  /// resolve to [CodeVerifyResult.invalid] so timing/behaviour can't be used
  /// to enumerate enrolled emails.
  (CodeVerifyResult, DemoSession?) verifyCode(String email, String code) {
    final now = _clock.now();
    final account = _accountsByEmail[_normalize(email)];
    if (account == null) return (CodeVerifyResult.invalid, null);

    if (account.lockoutPolicy.isLocked(now)) {
      return (CodeVerifyResult.locked, null);
    }

    final issuedAt = account.issuedAt;
    final issuedCode = account.issuedCode;
    if (issuedAt == null || issuedCode == null || account.used) {
      return (CodeVerifyResult.invalid, null);
    }
    if (codeExpiryPolicy.isExpired(issuedAt, now)) {
      return (CodeVerifyResult.expired, null);
    }

    if (code != issuedCode) {
      account.lockoutPolicy.registerWrong(now);
      final result = account.lockoutPolicy.isLocked(now)
          ? CodeVerifyResult.locked
          : CodeVerifyResult.invalid;
      return (result, null);
    }

    account.used = true;
    account.lockoutPolicy.reset();
    return (CodeVerifyResult.success, DemoSession._(account.patientId));
  }

  _PatientRecord _patientRecordFor(DemoSession session) {
    final record = _patients[session.patientId];
    if (record == null) {
      throw const AccessDeniedException('Session does not match a seeded patient.');
    }
    return record;
  }

  void agreeToDoc(DemoSession session, String docId, {String version = '0.1'}) {
    _patientRecordFor(session).consentRecords.add(
          ConsentRecord(docId: docId, version: version, agreedAt: _clock.now()),
        );
  }

  List<ConsentRecord> consentRecordsFor(DemoSession session) =>
      List.unmodifiable(_patientRecordFor(session).consentRecords);

  /// Duplicate check scoped to [session]'s patient only — a hash already
  /// uploaded by a *different* patient never warns and never hints that
  /// another patient has it.
  DuplicateCheckResult checkDuplicate(DemoSession session, String hash) =>
      _duplicateDetector.check(hash, session.patientId, _patientRecordFor(session).uploadedHashes);

  void recordUploadHash(DemoSession session, String hash) =>
      _patientRecordFor(session).uploadedHashes.add(hash);

  List<String> uploadedHashesFor(DemoSession session) =>
      List.unmodifiable(_patientRecordFor(session).uploadedHashes);

  void addLabReport(DemoSession session, String reportId) =>
      _patientRecordFor(session).labReportIds.add(reportId);

  List<String> labReportsFor(DemoSession session) =>
      List.unmodifiable(_patientRecordFor(session).labReportIds);
}
