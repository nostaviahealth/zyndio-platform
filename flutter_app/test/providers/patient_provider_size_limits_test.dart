// TC-030 item 3: patient_accounts avatar and display-name size limits must be
// enforced client-side (ahead of the DB CHECK backstop in
// 20261102163000_tc030_patient_accounts_size_limits.sql):
//   - display name <= 80 characters
//   - avatar <= 2 MB and an image/* type
// These tests fail on the pre-item-3 code, which uploaded/persisted any size or
// type unchecked.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/main.dart';
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_supabase_rest.dart';

const _patientId = '00000000-0000-0000-0000-0000000a1001';

Future<void> _signInAndWaitForUser(
    ProviderContainer container, FakeSupabaseRest fake, SupabaseClient client) async {
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

  Future<void> withSignedInNotifier(
      Future<void> Function(PatientProfileNotifier notifier) body) async {
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
      await body(container.read(patientProfileProvider.notifier));
    }, () => fake.mockClient);
  }

  test('updateProfile rejects a display name longer than 80 characters', () async {
    await withSignedInNotifier((notifier) async {
      final tooLong = 'A' * 81;
      await expectLater(
        () => notifier.updateProfile(name: tooLong),
        throwsA(isA<ProfileValidationException>()),
      );
    });
  });

  test('updateProfile accepts a display name of exactly 80 characters', () async {
    await withSignedInNotifier((notifier) async {
      final exactly = 'A' * 80;
      await notifier.updateProfile(name: exactly); // must not throw
    });
  });

  test('updateAvatar rejects a non-image file', () async {
    await withSignedInNotifier((notifier) async {
      final file = XFile.fromData(
        Uint8List.fromList([1, 2, 3, 4]),
        name: 'notes.txt',
        mimeType: 'text/plain',
      );
      await expectLater(
        () => notifier.updateAvatar(file),
        throwsA(isA<ProfileValidationException>()),
      );
    });
  });

  test('updateAvatar rejects an image larger than 2 MB', () async {
    await withSignedInNotifier((notifier) async {
      final big = Uint8List(PatientProfileNotifier.maxAvatarBytes + 1);
      final file = XFile.fromData(big, name: 'huge.png', mimeType: 'image/png');
      await expectLater(
        () => notifier.updateAvatar(file),
        throwsA(isA<ProfileValidationException>()),
      );
    });
  });

  test('_guessImageMimeType accepts common image extensions when mimeType absent', () async {
    await withSignedInNotifier((notifier) async {
      // A 2 KB image under the cap with an explicit image mimeType passes the
      // guard (the backend upload then runs past it - any error from here on is
      // not a ProfileValidationException).
      final small = Uint8List.fromList(List.filled(2048, 7));
      final file = XFile.fromData(small, name: 'avatar.png', mimeType: 'image/png');
      await expectLater(
        () => notifier.updateAvatar(file),
        throwsA(isNot(isA<ProfileValidationException>())),
      );
    });
  });
}
