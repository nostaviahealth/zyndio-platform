import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/services/secure_local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('PSU-SES-01 SecureLocalStorage', () {
    test('persists session via flutter_secure_storage mock (not SharedPreferences)', () async {
      final storage = SecureLocalStorage();
      expect(await storage.hasAccessToken(), isFalse);
      await storage.persistSession(
        '{"access_token":"at-fictional","refresh_token":"rt-fictional"}',
      );
      expect(await storage.hasAccessToken(), isTrue);
      expect(await storage.accessToken(), contains('rt-fictional'));
    });
  });

  group('PSU-SES-03 sign-out clears persisted session', () {
    test('removePersistedSession deletes the secure entry', () async {
      final storage = SecureLocalStorage();
      await storage.persistSession('{"access_token":"at","refresh_token":"rt"}');
      await storage.removePersistedSession();
      expect(await storage.hasAccessToken(), isFalse);
      expect(await storage.accessToken(), isNull);
    });
  });
}
