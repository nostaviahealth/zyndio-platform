// TC-025 C5 (Q23): with the patient-extras flag off, Shop / Meditate / Cycle
// reminders are cancelled (targeted, by payload route - never cancelAll) at
// startup and on an on->off flip, and a stale or unknown notification tap
// lands on Today without opening the disabled feature or throwing.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyndio_patient/app.dart';
import 'package:zyndio_patient/providers/feature_flags_provider.dart';
import 'package:zyndio_patient/services/extras_notification_guard.dart';
import 'package:zyndio_patient/services/notification_service.dart';

class _FakeNotifications implements PendingNotificationCanceller {
  _FakeNotifications(this.pendingList);
  final List<PendingNotificationRequest> pendingList;
  final List<int> cancelled = [];
  bool cancelAllCalled = false;

  @override
  Future<List<PendingNotificationRequest>> pending() async =>
      List.of(pendingList);

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  // Present only so a regression to a blanket cancel would be visible.
  Future<void> cancelAll() async => cancelAllCalled = true;
}

// Fictional scheduled reminders: three extras + non-extras ones that must stay.
List<PendingNotificationRequest> _scheduled() => const [
      PendingNotificationRequest(1001, 'Zyndio', 'Morning anchor', '/'),
      PendingNotificationRequest(1002, 'Zyndio', 'Lunch anchor', '/lens'),
      PendingNotificationRequest(2000, 'Upcoming Protocol', 'Task', 'task:t1'),
      PendingNotificationRequest(7101, 'Shop', 'Restock reminder', '/shop'),
      PendingNotificationRequest(7102, 'Shop', 'Product', '/shop/product/p1'),
      PendingNotificationRequest(7201, 'Meditate', 'Evening session', '/meditate'),
      PendingNotificationRequest(7301, 'Cycle', 'Log your cycle', '/cycle'),
      PendingNotificationRequest(7401, 'Zyndio', 'No payload', null),
    ];

class _ExtrasFlag extends Notifier<bool> {
  _ExtrasFlag(this.initial);
  final bool initial;
  @override
  bool build() => initial;
  void set(bool v) => state = v;
}

ProviderContainer _container(_FakeNotifications fake, bool extrasOn,
    NotifierProvider<_ExtrasFlag, bool> flag) {
  return ProviderContainer(overrides: [
    pendingNotificationCancellerProvider.overrideWithValue(fake),
    featureFlagsProvider.overrideWith(
        (ref) => FeatureFlags(patientExtrasEnabled: ref.watch(flag))),
  ]);
}

void main() {
  group('extras reminder cancellation', () {
    test('flag off at startup cancels exactly the Shop/Meditate/Cycle ones',
        () async {
      final fake = _FakeNotifications(_scheduled());
      final flag = NotifierProvider<_ExtrasFlag, bool>(() => _ExtrasFlag(false));
      final c = _container(fake, false, flag);
      addTearDown(c.dispose);
      await c.read(extrasReminderGuardProvider).idle;
      expect(fake.cancelled..sort(), [7101, 7102, 7201, 7301]);
      expect(fake.cancelAllCalled, isFalse);
    });

    test('flag on at startup cancels nothing', () async {
      final fake = _FakeNotifications(_scheduled());
      final flag = NotifierProvider<_ExtrasFlag, bool>(() => _ExtrasFlag(true));
      final c = _container(fake, true, flag);
      addTearDown(c.dispose);
      await c.read(extrasReminderGuardProvider).idle;
      expect(fake.cancelled, isEmpty);
    });

    test('on -> off flip cancels exactly the extras reminders', () async {
      final fake = _FakeNotifications(_scheduled());
      final flag = NotifierProvider<_ExtrasFlag, bool>(() => _ExtrasFlag(true));
      final c = _container(fake, true, flag);
      addTearDown(c.dispose);
      final guard = c.read(extrasReminderGuardProvider);
      await guard.idle;
      expect(fake.cancelled, isEmpty);
      c.read(flag.notifier).set(false);
      c.read(featureFlagsProvider); // flush the dependency
      await Future<void>.delayed(Duration.zero);
      await guard.idle;
      expect(fake.cancelled..sort(), [7101, 7102, 7201, 7301]);
      expect(fake.cancelAllCalled, isFalse);
    });

    test('a failing notification layer never throws out of the guard',
        () async {
      final guard = ExtrasReminderGuard(_ThrowingNotifications());
      await expectLater(guard.onExtrasFlag(previous: null, current: false),
          completes);
    });
  });

  group('notification tap routing', () {
    for (final payload in [
      '/shop',
      '/shop/product/p1',
      '/meditate',
      '/cycle',
    ]) {
      test('flag off: stale $payload tap routes to Today', () {
        expect(
            resolveNotificationTapRoute(payload, patientExtrasEnabled: false),
            '/');
      });
    }

    for (final payload in [null, '', 'garbage', '{type: promo}', 'task:t1']) {
      test('unknown/non-route payload "$payload" routes to Today', () {
        expect(
            resolveNotificationTapRoute(payload, patientExtrasEnabled: false),
            '/');
        expect(
            resolveNotificationTapRoute(payload, patientExtrasEnabled: true),
            '/');
      });
    }

    test('flag on: extras payloads keep their route; normal routes kept', () {
      expect(resolveNotificationTapRoute('/meditate', patientExtrasEnabled: true),
          '/meditate');
      expect(resolveNotificationTapRoute('/lens', patientExtrasEnabled: false),
          '/lens');
    });

    test('NotificationService body tap goes through the tap router, no throw',
        () {
      final routed = <String?>[];
      NotificationService.onNotificationTap = routed.add;
      addTearDown(() => NotificationService.onNotificationTap = null);
      for (final p in ['/shop', '/meditate', '/cycle', 'garbage', null]) {
        expect(
            () => NotificationService().handleNotificationResponse(
                NotificationResponse(
                    notificationResponseType:
                        NotificationResponseType.selectedNotification,
                    payload: p)),
            returnsNormally);
      }
      expect(routed, ['/shop', '/meditate', '/cycle', 'garbage', null]);
    });

    testWidgets('the real app registers the notification tap router',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      NotificationService.onNotificationTap = null;
      addTearDown(() => NotificationService.onNotificationTap = null);
      await tester.pumpWidget(const ProviderScope(child: BrandHealthApp()));
      await tester.pump();
      expect(NotificationService.onNotificationTap, isNotNull);
      // A stale extras tap through the real wiring must not throw.
      expect(
          () => NotificationService().handleNotificationResponse(
              const NotificationResponse(
                  notificationResponseType:
                      NotificationResponseType.selectedNotification,
                  payload: '/meditate')),
          returnsNormally);
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });

    test('a throwing tap callback does not crash the handler', () {
      NotificationService.onNotificationTap = (_) => throw StateError('boom');
      addTearDown(() => NotificationService.onNotificationTap = null);
      expect(
          () => NotificationService().handleNotificationResponse(
              const NotificationResponse(
                  notificationResponseType:
                      NotificationResponseType.selectedNotification,
                  payload: '/cycle')),
          returnsNormally);
    });
  });
}

class _ThrowingNotifications implements PendingNotificationCanceller {
  @override
  Future<List<PendingNotificationRequest>> pending() async =>
      throw StateError('plugin not available');
  @override
  Future<void> cancel(int id) async => throw StateError('plugin not available');
}
