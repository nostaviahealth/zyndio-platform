// APP-07: the Connections screen connects Apple Health / Health Connect on
// the device and starts the wearable upload. It used to call
// `functions/v1/connect` (through the wearables SDK's cloud client), an
// endpoint that does not exist; no network request may be made from here.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zyndio_patient/data/health_repository.dart';
import 'package:zyndio_patient/screens/settings/connections_screen.dart';
import 'package:zyndio_patient/services/wearable_daily/device_health_connector.dart';
import 'package:zyndio_patient/services/wearable_daily/wearable_daily_sync.dart';

class _FakeConnector implements DeviceHealthConnector {
  _FakeConnector(this.result);
  final DeviceHealthConnectResult result;
  int calls = 0;

  @override
  Future<DeviceHealthConnectResult> connect() async {
    calls++;
    return result;
  }
}

class _FakeRepo extends HealthRepository {
  _FakeRepo({this.granted = true, this.hcStatus = 'installed'});
  final bool granted;
  final String hcStatus;
  bool? linked;

  @override
  Future<String> getHealthConnectStatus() async => hcStatus;
  @override
  Future<bool> requestUnifiedPermissions() async => granted;
  @override
  Future<void> setLinked(bool isLinked) async => linked = isLinked;
}

class _FakeSync extends WearableDailySync {
  _FakeSync() : super(client: () => null);
  int connected = 0;

  @override
  Future<WearableSyncOutcome> onConnected(
      {WearableUploadPermissions? permissions}) async {
    connected++;
    return const WearableSyncOutcome(WearableSyncStatus.uploaded);
  }
}

Future<void> _pump(WidgetTester tester, DeviceHealthConnector connector) =>
    tester
        .pumpWidget(MaterialApp(home: ConnectionsScreen(connector: connector)));

void main() {
  final requests = <http.BaseRequest>[];
  final mock = MockClient((r) async {
    requests.add(r);
    return http.Response('unexpected', 500);
  });

  setUp(requests.clear);

  testWidgets(
      'connecting the health store uses the device, not functions/v1/connect',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await http.runWithClient(() async {
      final connector = _FakeConnector(DeviceHealthConnectResult.connected);
      await _pump(tester, connector);
      expect(find.text('Connect Apple Health'), findsOneWidget);
      await tester.tap(find.byKey(const Key('connect-health-store')));
      await tester.pumpAndSettle();
      expect(connector.calls, 1);
      expect(find.text(connectedHealthStoreMessage), findsOneWidget);
    }, () => mock);
    debugDefaultTargetPlatformOverride = null;
    expect(requests, isEmpty,
        reason: 'no server call to connect an on-device health store');
  });

  testWidgets('on Android the button names Health Connect', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _pump(tester, _FakeConnector(DeviceHealthConnectResult.connected));
      expect(find.text('Connect Health Connect'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('denied permissions show a fixed message', (tester) async {
    await _pump(tester, _FakeConnector(DeviceHealthConnectResult.denied));
    await tester.tap(find.byKey(const Key('connect-health-store')));
    await tester.pumpAndSettle();
    expect(find.textContaining('were not granted'), findsOneWidget);
  });

  testWidgets(
      'WHOOP (cloud, no server integration) is disabled, never calls out',
      (tester) async {
    await http.runWithClient(() async {
      final connector = _FakeConnector(DeviceHealthConnectResult.connected);
      await _pump(tester, connector);
      await tester.tap(find.byKey(const Key('connect-whoop')),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(connector.calls, 0);
      final button = tester.widget<ElevatedButton>(find.descendant(
          of: find.byKey(const Key('connect-whoop')),
          matching: find.byType(ElevatedButton)));
      expect(button.onPressed, isNull);
    }, () => mock);
    expect(requests, isEmpty);
  });

  group('HealthStoreConnector', () {
    test('granted: marks linked and starts the backfill upload', () async {
      final repo = _FakeRepo();
      final sync = _FakeSync();
      final result =
          await HealthStoreConnector(repository: repo, sync: sync).connect();
      await Future<void>.delayed(Duration.zero);
      expect(result, DeviceHealthConnectResult.connected);
      expect(repo.linked, isTrue);
      expect(sync.connected, 1);
    });

    test('denied: not linked, no upload', () async {
      final repo = _FakeRepo(granted: false);
      final sync = _FakeSync();
      final result =
          await HealthStoreConnector(repository: repo, sync: sync).connect();
      expect(result, DeviceHealthConnectResult.denied);
      expect(repo.linked, isNull);
      expect(sync.connected, 0);
    });

    test('Android without Health Connect asks to install it first', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final sync = _FakeSync();
        final result = await HealthStoreConnector(
          repository: _FakeRepo(hcStatus: 'not_installed'),
          sync: sync,
        ).connect();
        expect(result, DeviceHealthConnectResult.healthConnectNotInstalled);
        expect(sync.connected, 0);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
