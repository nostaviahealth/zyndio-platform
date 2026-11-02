// TC-026: NotificationService.syncTokenToSupabase must write the FCM token
// to patient_accounts (keyed by patient_id), never the removed profiles
// table.
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/services/notification_service.dart';
import 'package:http/http.dart' as http;

import '../support/fake_supabase_rest.dart';

const _patientId = '00000000-0000-0000-0000-0000000a4001';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
  });

  test('syncTokenToSupabase() upserts patient_accounts keyed by patient_id, not profiles/user_id', () async {
    final fake = FakeSupabaseRest();

    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;
      await fake.signIn(client, _patientId);
      await client.auth.setSession('fake-refresh-token');

      await NotificationService().syncTokenToSupabase('fictional-fcm-token');

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
      final writes = fake.requestsFor('patient_accounts').where((r) => r.method != 'GET');
      expect(writes, isNotEmpty, reason: fake.tableNames.toString());
      for (final r in writes) {
        expect(r.url.query, contains('patient_id'));
      }
    }, () => fake.mockClient);
  });
}
