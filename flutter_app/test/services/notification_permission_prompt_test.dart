// App Store guideline 4.5.4 / store readiness: the notification permission
// prompt must not fire at launch on the sign-in screen. It is asked once, from
// the signed-in shell, and the "asked" flag is saved before prompting so a
// dismissed dialog never becomes a prompt on every launch.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyndio_patient/services/notification_permission_prompt.dart';

class _FakeRequester implements NotificationPermissionRequester {
  int calls = 0;
  bool throwOnRequest = false;
  @override
  Future<bool> requestPermissions() async {
    calls++;
    if (throwOnRequest) throw Exception('dialog failed');
    return true;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('asks the first time only', () async {
    final fake = _FakeRequester();
    final prompt = NotificationPermissionPrompt(SharedPreferences.getInstance, fake);
    expect(await prompt.maybeAskOnce(), isTrue);
    expect(await prompt.maybeAskOnce(), isFalse);
    expect(fake.calls, 1);
  });

  test('a patient who was already asked is never asked again', () async {
    SharedPreferences.setMockInitialValues({NotificationPermissionPrompt.askedKey: true});
    final fake = _FakeRequester();
    final prompt = NotificationPermissionPrompt(SharedPreferences.getInstance, fake);
    expect(await prompt.maybeAskOnce(), isFalse);
    expect(fake.calls, 0);
  });

  test('the flag is saved before prompting, so a failed dialog is not retried', () async {
    final fake = _FakeRequester()..throwOnRequest = true;
    final prompt = NotificationPermissionPrompt(SharedPreferences.getInstance, fake);
    expect(await prompt.maybeAskOnce(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(NotificationPermissionPrompt.askedKey), isTrue);
    expect(await prompt.maybeAskOnce(), isFalse);
    expect(fake.calls, 1);
  });

  test('a storage failure skips the prompt instead of throwing', () async {
    final fake = _FakeRequester();
    final prompt = NotificationPermissionPrompt(() async => throw Exception('no prefs'), fake);
    expect(await prompt.maybeAskOnce(), isFalse);
    expect(fake.calls, 0);
  });
}
