import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/intelligence_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/providers/wearable_sync_provider.dart';
import 'package:zyndio_patient/screens/today/today_screen.dart';

class _ProfileNotifier extends PatientProfileNotifier {
  _ProfileNotifier(this.name);
  final String? name;
  @override
  Future<PatientProfile?> build() async =>
      PatientProfile(id: 'p1', name: name);
}

class _FakeWearable extends WearableSyncNotifier {
  _FakeWearable(this._state, {this.loadForever = false, this.fail = false});
  final WearableSyncState _state;
  final bool loadForever;
  final bool fail;
  @override
  Future<WearableSyncState> build() async {
    if (loadForever) return Completer<WearableSyncState>().future;
    if (fail) throw StateError('boom');
    return _state;
  }
}

WearableSnapshot _snap() => const WearableSnapshot(
      sleepHours: 7.3,
      steps: 8421,
      hrv: 58,
      hrvBaseline: 58,
    );

GoRouter _router() => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (c, s) => const Scaffold(body: TodayScreen())),
        GoRoute(
            path: '/food-log',
            name: 'lens_history',
            builder: (c, s) => const Scaffold(body: Text('FOOD LOG SCREEN'))),
        GoRoute(
            path: '/chat',
            name: 'chat',
            builder: (c, s) => const Scaffold(body: Text('CHAT SCREEN'))),
        GoRoute(
            path: '/connect-wearable',
            name: 'connect_wearable',
            builder: (c, s) => const Scaffold(body: Text('CONNECT SCREEN'))),
        GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (c, s) => const Scaffold(body: Text('SETTINGS'))),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  required WearableSyncNotifier Function() wearable,
  String? name = 'Jordan Rivera',
  Brightness b = Brightness.light,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientProfileProvider.overrideWith(() => _ProfileNotifier(name)),
        wearableSyncProvider.overrideWith(wearable),
        aiInsightsProvider
            .overrideWithValue(const ['Your HRV has been steady this week.']),
      ],
      child: MaterialApp.router(
        theme: b == Brightness.light ? BrandTheme.lightTheme : BrandTheme.darkTheme,
        routerConfig: _router(),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  group('Today pure helpers', () {
    test('greeting by device hour + first name', () {
      expect(todayGreeting(8, 'Jordan'), 'Good morning, Jordan');
      expect(todayGreeting(13, 'Jordan'), 'Good afternoon, Jordan');
      expect(todayGreeting(20, 'Jordan'), 'Good evening, Jordan');
      expect(todayGreeting(8, null), 'Good morning');
    });

    test('firstNameOf', () {
      expect(firstNameOf('Jordan Rivera'), 'Jordan');
      expect(firstNameOf('  '), isNull);
    });

    test('neutral delta: Stable only at exact equality, else arrow + sign', () {
      expect(zyndioDelta(58, 58).stable, isTrue);
      expect(zyndioDelta(58, 58).text, 'Stable');
      expect(zyndioDelta(60, 58, unit: 'ms').text, '↑ 2ms');
      expect(zyndioDelta(55, 58, unit: 'ms').text, '↓ 3ms');
    });

    test('classifyToday', () {
      expect(classifyToday(const AsyncLoading()), TodayState.loading);
      expect(classifyToday(AsyncError('e', StackTrace.empty)), TodayState.error);
      expect(
          classifyToday(AsyncData(WearableSyncState(error: 'Not linked'))),
          TodayState.noWearable);
      expect(classifyToday(AsyncData(WearableSyncState(snapshot: _snap()))),
          TodayState.data);
      expect(
          classifyToday(AsyncData(
              WearableSyncState(snapshot: _snap(), error: 'net', lastSynced: DateTime(2026)))),
          TodayState.offline);
    });
  });

  group('Today screen', () {
    testWidgets('default: tiles shown, Recovery never rendered, ring absent, food log present',
        (tester) async {
      await _pump(tester,
          wearable: () => _FakeWearable(WearableSyncState(
              snapshot: _snap(), lastSynced: DateTime(2026, 11, 3, 9, 5))));

      expect(find.text('Sleep'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('HRV'), findsOneWidget);
      // Guardrail: Recovery is never derived / shown.
      expect(find.text('Recovery'), findsNothing);
      // Guardrail: no Longevity ring / composite score.
      expect(find.textContaining('Longevity'), findsNothing);
      // Q5: food log row present, with its subline, reachable.
      expect(find.text('Food log'), findsOneWidget);
      // Neutral delta for HRV (equal baseline → Stable).
      expect(find.text('Stable'), findsOneWidget);
      // Source caption names the connected source.
      expect(find.textContaining('Change vs. your previous 7 days'), findsOneWidget);
    });

    testWidgets('food log taps through to /food-log', (tester) async {
      await _pump(tester,
          wearable: () => _FakeWearable(WearableSyncState(
              snapshot: _snap(), lastSynced: DateTime(2026, 11, 3, 9, 5))));
      await tester.tap(find.text('Food log'));
      await tester.pumpAndSettle();
      expect(find.text('FOOD LOG SCREEN'), findsOneWidget);
    });

    testWidgets('no-wearable: connect card + food log, no tiles', (tester) async {
      await _pump(tester,
          wearable: () => _FakeWearable(WearableSyncState(error: 'Not linked')));
      expect(find.text('Connect your health data'), findsOneWidget);
      expect(find.text('Sleep'), findsNothing);
      expect(find.text('Food log'), findsOneWidget);
    });

    testWidgets('offline: warn banner + cached tiles + food log', (tester) async {
      await _pump(tester,
          wearable: () => _FakeWearable(WearableSyncState(
              snapshot: _snap(),
              error: 'net',
              lastSynced: DateTime(2026, 11, 3, 9, 5))));
      expect(find.textContaining("You're offline"), findsOneWidget);
      expect(find.text('Sleep'), findsOneWidget);
      expect(find.text('Food log'), findsOneWidget);
    });

    testWidgets('error: error card + Try again, NO food log row', (tester) async {
      await _pump(tester, wearable: () => _FakeWearable(WearableSyncState(), fail: true));
      expect(find.text("We couldn't load today's overview"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Food log'), findsNothing);
    });

    testWidgets('loading: skeleton with one Loading semantics, food log skeleton',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester,
          wearable: () => _FakeWearable(WearableSyncState(), loadForever: true),
          settle: false);
      await tester.pump();
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      expect(find.text('Food log'), findsNothing); // replaced by skeleton
      handle.dispose();
    });

    testWidgets('long name: greeting wraps without truncation', (tester) async {
      await _pump(tester,
          name: 'Maximiliana Alexandrina Featherstonehaugh',
          wearable: () => _FakeWearable(WearableSyncState(
              snapshot: _snap(), lastSynced: DateTime(2026, 11, 3, 9, 5))));
      expect(find.textContaining('Maximiliana'), findsOneWidget);
      expect(find.text('Food log'), findsOneWidget);
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pump(tester,
          b: Brightness.dark,
          wearable: () => _FakeWearable(WearableSyncState(
              snapshot: _snap(), lastSynced: DateTime(2026, 11, 3, 9, 5))));
      expect(find.text('HRV'), findsOneWidget);
    });
  });
}
