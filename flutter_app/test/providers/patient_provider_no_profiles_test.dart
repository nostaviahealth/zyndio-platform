// TC-026: patient_provider.dart (PatientProfileNotifier) must read/write the
// patient's own account data via patient_accounts, never the removed
// profiles table, keyed by the patient's own auth user id (patient_accounts'
// primary key) rather than a separate profile id.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/main.dart';
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_supabase_rest.dart';

const _patientId = '00000000-0000-0000-0000-0000000a1001';

/// authStateProvider's underlying stream is a plain broadcast stream with no
/// replay, so signIn() must happen *after* something has already subscribed
/// (the provider is created at the first watch/listen) - otherwise the
/// signed-in event fires before anyone is listening and currentUserProvider
/// never sees it. Subscribe first, sign in, then poll briefly for the
/// resulting currentUserProvider update to propagate.
Future<void> _signInAndWaitForUser(ProviderContainer container, FakeSupabaseRest fake, SupabaseClient client) async {
  container.listen(currentUserProvider, (_, __) {});
  await fake.signIn(client, _patientId);
  for (var i = 0; i < 200; i++) {
    if (container.read(currentUserProvider) != null) return;
    await Future.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('currentUserProvider never saw the signed-in user');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
  });

  test('fetching the patient profile touches patient_accounts, not profiles', () async {
    final fake = FakeSupabaseRest();

    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;

      final container = ProviderContainer(overrides: [
        supabaseInitializedProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);

      await _signInAndWaitForUser(container, fake, client);
      await container.read(patientProfileProvider.future);

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
      expect(fake.tableNames, contains('patient_accounts'), reason: fake.tableNames.toString());
    }, () => fake.mockClient);
  });

  test('updateProfile() upserts patient_accounts keyed by patient_id, not profiles/user_id', () async {
    final fake = FakeSupabaseRest();

    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;

      final container = ProviderContainer(overrides: [
        supabaseInitializedProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);

      await _signInAndWaitForUser(container, fake, client);
      await container.read(patientProfileProvider.future);
      await container.read(patientProfileProvider.notifier).updateProfile(name: 'Fictional Patient');

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
      final writes = fake.requestsFor('patient_accounts').where((r) => r.method != 'GET');
      expect(writes, isNotEmpty);
      for (final r in writes) {
        expect(r.url.query, contains('patient_id'));
      }
    }, () => fake.mockClient);
  });
}
