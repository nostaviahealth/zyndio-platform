import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_backend.dart';
import '../data/fixtures.dart';
import '../data/supabase_repository.dart';
import '../data/zyndio_repository.dart';
import '../logic/clock.dart';
import '../logic/upload_queue.dart';

final demoClockProvider = Provider<Clock>((ref) => const SystemClock());

final demoBackendProvider = Provider<DemoBackend>((ref) {
  return DemoBackend(clock: ref.watch(demoClockProvider));
});

/// `DATA_SOURCE=offline|supabase`, default `offline`. Selects which
/// [ZyndioRepository] implementation the app runs against; screens and
/// controllers never see this — they depend only on [zyndioRepositoryProvider].
const String dataSource = String.fromEnvironment('DATA_SOURCE', defaultValue: 'offline');

/// App-private [QueueStore] factory for the offline repository's upload
/// queues, keyed by patient id. `null` (the default) keeps the in-memory
/// store, which is what every existing test runs against; `main_demo.dart`
/// overrides this on non-web so queued uploads survive an app kill.
final queueStoreFactoryProvider = Provider<QueueStore Function(String patientId)?>((ref) => null);

final zyndioRepositoryProvider = Provider<ZyndioRepository>((ref) {
  switch (dataSource) {
    case 'supabase':
      return const SupabaseRepository();
    case 'offline':
    default:
      return OfflineDemoRepository(
        ref.watch(demoBackendProvider),
        queueStoreFor: ref.watch(queueStoreFactoryProvider),
      );
  }
});

/// The signed-in session, set by [SignInController.submitCode] on success.
/// Downstream screens (consent, labs, trends) read this to scope their own
/// repository calls to the right patient.
class CurrentSessionNotifier extends Notifier<RepoSession?> {
  @override
  RepoSession? build() => null;

  void set(RepoSession? session) => state = session;
}

final currentSessionProvider = NotifierProvider<CurrentSessionNotifier, RepoSession?>(
  CurrentSessionNotifier.new,
);

/// Returns the current session, signing in the primary fixture patient as a
/// fallback. Demo convenience only: lets a screen after sign-in (e.g.
/// consent) be opened directly — via the screenshot harness, or before a
/// screen-to-screen flow router exists — without a real sign-in first. Every
/// repository call made with the returned session is still scoped to that
/// one patient like any other session.
RepoSession requireDemoSession(Ref ref) {
  final existing = ref.read(currentSessionProvider);
  if (existing != null) return existing;
  final repo = ref.read(zyndioRepositoryProvider);
  repo.sendCode(demoPatient.email);
  final code = repo.debugLastIssuedCode(demoPatient.email);
  final (_, session) = repo.verifyCode(demoPatient.email, code ?? '');
  if (session == null) {
    throw StateError('Demo auto-sign-in failed unexpectedly.');
  }
  ref.read(currentSessionProvider.notifier).set(session);
  return session;
}
