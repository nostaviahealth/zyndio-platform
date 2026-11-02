// TC-026: ProtocolRepository.fetchAllAdminProtocols/fetchProtocol used to
// resolve a "profile id" by querying profiles.id where user_id = the auth
// user, purely as an indirection to feed into health_journeys.profile_id.
// Under the new schema the patient's identity key IS their auth user id -
// no profiles lookup needed, use it directly.
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/data/protocol_repository.dart';
import 'package:http/http.dart' as http;

import '../support/fake_supabase_rest.dart';

const _patientId = '00000000-0000-0000-0000-0000000a5001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
  });

  test('fetchAllAdminProtocols() never queries profiles to resolve a profile id', () async {
    final fake = FakeSupabaseRest();
    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;
      await fake.signIn(client, _patientId);
      await client.auth.setSession('fake-refresh-token');

      await ProtocolRepository.fetchAllAdminProtocols();

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
    }, () => fake.mockClient);
  });

  test('fetchProtocol() never queries profiles to resolve a profile id', () async {
    final fake = FakeSupabaseRest();
    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;
      await fake.signIn(client, _patientId);
      await client.auth.setSession('fake-refresh-token');

      await ProtocolRepository.fetchProtocol();

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
    }, () => fake.mockClient);
  });
}
