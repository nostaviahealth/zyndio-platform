import '../../config/supabase_config.dart';
import '../logic/file_hash.dart';
import '../logic/upload_queue.dart';
import 'demo_backend.dart';
import 'fixtures.dart';
import 'zyndio_repository.dart';

/// Real-backend implementation of [ZyndioRepository] for a future production
/// build. Not used by the offline demo. Never embeds a URL or key: it reads
/// [SupabaseConfig] (dart-define env vars only) and, if that configuration
/// is missing, fails closed before touching the network — it does not fall
/// back to any default project.
class SupabaseRepository implements ZyndioRepository {
  const SupabaseRepository();

  void _requireConfigured() {
    if (!SupabaseConfig.hasCredentials) {
      throw StateError(
        'Zyndio data source not configured: SUPABASE_URL/SUPABASE_ANON_KEY '
        'are empty. Build with --dart-define=DATA_SOURCE=offline for the '
        'demo, or provide Supabase env vars for a real backend.',
      );
    }
  }

  @override
  void sendCode(String email) {
    _requireConfigured();
    throw UnimplementedError('Supabase data source is not implemented yet.');
  }

  @override
  (CodeVerifyResult, RepoSession?) verifyCode(String email, String code) {
    _requireConfigured();
    throw UnimplementedError('Supabase data source is not implemented yet.');
  }

  @override
  String? debugLastIssuedCode(String email) => null;

  @override
  void agreeToDoc(RepoSession session, String docId, {String version = '0.1'}) {
    _requireConfigured();
    throw UnimplementedError('Supabase data source is not implemented yet.');
  }

  @override
  List<ConsentRecord> consentRecordsFor(RepoSession session) {
    _requireConfigured();
    throw UnimplementedError('Supabase data source is not implemented yet.');
  }

  @override
  DuplicateCheckResult checkDuplicateHash(RepoSession session, String hash) {
    _requireConfigured();
    throw UnimplementedError('Supabase data source is not implemented yet.');
  }

  @override
  void recordUploadHash(RepoSession session, String hash) {
    _requireConfigured();
    throw UnimplementedError('Supabase data source is not implemented yet.');
  }

  @override
  UploadQueue uploadQueueFor(RepoSession session) {
    _requireConfigured();
    throw UnimplementedError('Supabase data source is not implemented yet.');
  }

  @override
  List<HbA1cPoint> hba1cTrendFor(RepoSession session) {
    _requireConfigured();
    throw UnimplementedError('Supabase data source is not implemented yet.');
  }
}
