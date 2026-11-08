// APP-10: no health information in visible notification text. Whatever a
// caller passes as title/body (here: a workout summary with heart rate and
// calories), the platform only ever receives the neutral copy.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:zyndio_patient/services/notification_service.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');
const _healthTitle = 'Run Summary';
const _healthBody = 'Alex, 42min Run locked in! Burned 512kcal. Avg HR: 151bpm.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/New_York'));
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  void expectNeutral(String method) {
    final sent = calls.where((c) => c.method == method).toList();
    expect(sent, hasLength(1), reason: calls.map((c) => c.method).toString());
    final args = Map<String, Object?>.from(sent.single.arguments as Map);
    expect(args['title'], kNotificationTitle);
    expect(args['body'], kNotificationBody);
    expect(args.toString(), isNot(contains('151bpm')));
    expect(args.toString(), isNot(contains('512kcal')));
  }

  test('showLocalNotification never displays the caller\'s health text', () async {
    await NotificationService().showLocalNotification(
      id: 3001,
      title: _healthTitle,
      body: _healthBody,
      payload: '/wearables',
    );
    expectNeutral('show');
  });

  test('scheduleNotification never displays the caller\'s health text', () async {
    await NotificationService().scheduleNotification(
      id: 1001,
      title: _healthTitle,
      body: _healthBody,
      scheduledDate: DateTime.now().add(const Duration(hours: 1)),
      payload: '/',
    );
    expectNeutral('zonedSchedule');
  });

  test('neutral copy names no health details', () {
    expect(kNotificationBody, isNot(matches(RegExp(r'\d'))));
  });
}
