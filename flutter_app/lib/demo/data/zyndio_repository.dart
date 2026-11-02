import '../logic/file_hash.dart';
import '../logic/upload_queue.dart';
import 'demo_backend.dart';
import 'fixtures.dart';

/// Repository-level session handle. Wraps whichever session type the
/// underlying data source produced (a [DemoSession] for the offline
/// backend; a Supabase auth session once that implementation exists) behind
/// one [patientId] that screens/controllers can depend on without knowing
/// which data source is selected.
class RepoSession {
  const RepoSession(this.patientId, Object native) : _native = native;

  final String patientId;
  final Object _native;

  T unwrap<T>() => _native as T;
}

/// Single data-access interface for the whole app: auth codes/sessions,
/// consent, lab reports/files/upload, and trends. Screens and controllers
/// depend only on this interface, never on [DemoBackend] or a Supabase
/// client directly, so swapping the data source never touches UI code.
abstract class ZyndioRepository {
  /// Issues (or re-issues) a sign-in code for [email]. No self-sign-up: an
  /// unknown email never creates an account, and the call never reveals
  /// whether the email was known.
  void sendCode(String email);

  /// Verifies [code] for [email]. Returns a session on success.
  (CodeVerifyResult, RepoSession?) verifyCode(String email, String code);

  /// Time left on [email]'s current lockout, or [Duration.zero] if not
  /// locked. The sign-in UI reads this for the "Try again in {n} min" copy.
  Duration lockRemaining(String email);

  /// Demo/test-only: the last code issued to [email]. Implementations that
  /// can't support this (e.g. a real email-delivered code) return `null`.
  String? debugLastIssuedCode(String email);

  void agreeToDoc(RepoSession session, String docId, {String version = '0.1'});

  List<ConsentRecord> consentRecordsFor(RepoSession session);

  DuplicateCheckResult checkDuplicateHash(RepoSession session, String hash);

  void recordUploadHash(RepoSession session, String hash);

  /// The upload queue for [session]'s patient. The same instance is
  /// returned for the same patient across calls so queued items persist for
  /// the lifetime of the repository.
  UploadQueue uploadQueueFor(RepoSession session);

  List<HbA1cPoint> hba1cTrendFor(RepoSession session);
}

/// Default implementation: wraps the hardened, multi-patient [DemoBackend].
/// Fully offline, no network, fictional seeded patients only.
class OfflineDemoRepository implements ZyndioRepository {
  OfflineDemoRepository(this._backend, {QueueStore Function(String patientId)? queueStoreFor})
      : _queueStoreFor = queueStoreFor;

  final DemoBackend _backend;
  final QueueStore Function(String patientId)? _queueStoreFor;
  final Map<String, UploadQueue> _uploadQueuesByPatientId = {};

  @override
  void sendCode(String email) => _backend.sendCode(email);

  @override
  (CodeVerifyResult, RepoSession?) verifyCode(String email, String code) {
    final (result, session) = _backend.verifyCode(email, code);
    if (session == null) return (result, null);
    return (result, RepoSession(session.patientId, session));
  }

  @override
  Duration lockRemaining(String email) => _backend.lockRemaining(email);

  @override
  String? debugLastIssuedCode(String email) => _backend.debugLastIssuedCode(email);

  @override
  void agreeToDoc(RepoSession session, String docId, {String version = '0.1'}) =>
      _backend.agreeToDoc(session.unwrap<DemoSession>(), docId, version: version);

  @override
  List<ConsentRecord> consentRecordsFor(RepoSession session) =>
      _backend.consentRecordsFor(session.unwrap<DemoSession>());

  @override
  DuplicateCheckResult checkDuplicateHash(RepoSession session, String hash) =>
      _backend.checkDuplicate(session.unwrap<DemoSession>(), hash);

  @override
  void recordUploadHash(RepoSession session, String hash) =>
      _backend.recordUploadHash(session.unwrap<DemoSession>(), hash);

  @override
  UploadQueue uploadQueueFor(RepoSession session) =>
      _uploadQueuesByPatientId.putIfAbsent(
        session.patientId,
        () => UploadQueue(store: _queueStoreFor?.call(session.patientId)),
      );

  @override
  List<HbA1cPoint> hba1cTrendFor(RepoSession session) {
    // Only the primary fixture patient (seeded first, so always
    // 'patient-0') has trend data in this demo; every other seeded patient
    // (e.g. Sam Okafor) correctly sees none — never Jordan's values.
    return session.patientId == 'patient-0' ? hba1cTrend : const [];
  }
}
