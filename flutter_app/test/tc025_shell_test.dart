import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zyndio_patient/config/routes.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/providers/lab_reports_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/screens/biomarkers/biomarkers_screen.dart';
import 'package:zyndio_patient/screens/care/care_screen.dart';
import 'package:zyndio_patient/screens/progress/progress_screen.dart';
import 'package:zyndio_patient/screens/today/today_screen.dart';
import 'package:zyndio_patient/widgets/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyndio_patient/providers/feature_flags_provider.dart';
import 'package:zyndio_patient/services/notification_permission_prompt.dart';

/// Keeps the brand-row avatar initials deterministic without hitting Supabase.
class _TestProfileNotifier extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async =>
      PatientProfile(id: 'p1', name: 'Jordan Rivera', subscriptionPlan: 'free');
}

GoRouter _shellRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (c, s, shell) => MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/',
                  pageBuilder: (c, s) =>
                      const NoTransitionPage(child: TodayScreen())),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/progress',
                  pageBuilder: (c, s) =>
                      const NoTransitionPage(child: ProgressScreen())),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/biomarkers',
                  pageBuilder: (c, s) =>
                      const NoTransitionPage(child: BiomarkersScreen())),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/my-plan',
                  pageBuilder: (c, s) => const NoTransitionPage(
                      child: Scaffold(body: Text('MY PLAN STUB')))),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/care',
                  pageBuilder: (c, s) =>
                      const NoTransitionPage(child: CareScreen())),
            ]),
          ],
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          builder: (c, s) =>
              const Scaffold(body: Center(child: Text('SETTINGS SCREEN'))),
        ),
      ],
    );

/// Records prompts instead of touching the OS permission dialog.
class _FakeRequester implements NotificationPermissionRequester {
  int calls = 0;
  @override
  Future<bool> requestPermissions() async {
    calls++;
    return true;
  }
}

Future<void> _pumpShell(
  WidgetTester tester, {
  Brightness b = Brightness.light,
  FeatureFlags flags = const FeatureFlags(),
  _FakeRequester? requester,
}) async {
  SharedPreferences.setMockInitialValues({});
  final fake = requester ?? _FakeRequester();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        featureFlagsProvider.overrideWithValue(flags),
        notificationPermissionPromptProvider.overrideWithValue(
          NotificationPermissionPrompt(SharedPreferences.getInstance, fake),
        ),
        patientProfileProvider.overrideWith(() => _TestProfileNotifier()),
        // Fictional: no lab reports, so the Biomarkers tab never hits Supabase.
        labReportsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp.router(
        theme: b == Brightness.light
            ? BrandTheme.lightTheme
            : BrandTheme.darkTheme,
        routerConfig: _shellRouter(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('appointmentsRedirect (pure rules)', () {
    test('flag off: every appointments location lands on Today', () {
      for (final loc in ['/appointments', '/appointments/doctor/d1']) {
        expect(appointmentsRedirect(loc, appointmentsEnabled: false), '/',
            reason: loc);
      }
    });
    test('flag off: other locations are untouched', () {
      expect(appointmentsRedirect('/care', appointmentsEnabled: false), isNull);
      expect(appointmentsRedirect('/appointmentsx', appointmentsEnabled: false),
          isNull);
    });
    test('flag on: appointments stays reachable', () {
      expect(appointmentsRedirect('/appointments', appointmentsEnabled: true),
          isNull);
    });
  });

  group('tc025Redirect (pure rules)', () {
    test('legacy tab paths map to their new homes', () {
      expect(
          tc025Redirect('/protocol', patientExtrasEnabled: false), '/my-plan');
      expect(tc025Redirect('/health_data', patientExtrasEnabled: false),
          '/biomarkers');
      expect(tc025Redirect('/wearables', patientExtrasEnabled: false), '/');
    });

    test('extras deep links land on Today when the flag is off', () {
      expect(tc025Redirect('/shop', patientExtrasEnabled: false), '/');
      expect(
          tc025Redirect('/shop/product/1', patientExtrasEnabled: false), '/');
      expect(tc025Redirect('/meditate', patientExtrasEnabled: false), '/');
      expect(tc025Redirect('/cycle', patientExtrasEnabled: false), '/');
    });

    test('extras are reachable when the flag is on', () {
      expect(tc025Redirect('/shop', patientExtrasEnabled: true), isNull);
      expect(tc025Redirect('/meditate', patientExtrasEnabled: true), isNull);
      expect(tc025Redirect('/cycle', patientExtrasEnabled: true), isNull);
    });

    test('unrelated paths are left alone', () {
      expect(tc025Redirect('/', patientExtrasEnabled: false), isNull);
      expect(tc025Redirect('/biomarkers', patientExtrasEnabled: false), isNull);
      expect(tc025Redirect('/health_data/upload', patientExtrasEnabled: false),
          isNull);
    });
  });

  group('5-tab shell', () {
    testWidgets('renders all five tabs, each announced "name, tab n of 5"',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(tester);

      const labels = [
        'Today, tab 1 of 5',
        'Progress, tab 2 of 5',
        'Biomarkers, tab 3 of 5',
        'My Plan, tab 4 of 5',
        'Care, tab 5 of 5',
      ];
      for (final l in labels) {
        expect(find.bySemanticsLabel(l), findsOneWidget, reason: l);
      }
      // Today starts selected; a sibling does not.
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('Today, tab 1 of 5'))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isTrue);
      expect(
          tester
              .getSemantics(find.bySemanticsLabel('Care, tab 5 of 5'))
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          Tristate.isFalse);
      // Tab target height meets the 44pt minimum.
      expect(tester.getSize(find.bySemanticsLabel('Today, tab 1 of 5')).height,
          greaterThanOrEqualTo(44));
      handle.dispose();
    });

    testWidgets('tapping a tab switches the mounted interim screen',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(tester);

      await tester.tap(find.bySemanticsLabel('Progress, tab 2 of 5'));
      await tester.pumpAndSettle();
      expect(find.text('No DEXASCAN results yet'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Care, tab 5 of 5'));
      await tester.pumpAndSettle();
      expect(find.text('My Care'), findsOneWidget);
      expect(find.text('Lab Results'), findsOneWidget);
      // Appointments is mock data: hidden in the store build (flag off).
      expect(find.text('Appointments'), findsNothing);
      handle.dispose();
    });

    testWidgets('switching tabs at phone width never throws a layout error',
        (tester) async {
      // The pill animates between tabs; at phone width a mid-animation
      // overflow or constraint assertion used to flash an error box.
      tester.view.physicalSize = const Size(402 * 3, 874 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      await _pumpShell(tester);
      for (final label in [
        'Progress, tab 2 of 5',
        'Biomarkers, tab 3 of 5',
        'My Plan, tab 4 of 5',
        'Care, tab 5 of 5',
        'Today, tab 1 of 5',
        'Biomarkers, tab 3 of 5',
      ]) {
        await tester.tap(find.bySemanticsLabel(label));
        // Step through the animation frame by frame.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pumpAndSettle();
        final err = tester.takeException();
        expect(err, isNull, reason: "after tapping $label");
      }
      handle.dispose();
    });

    testWidgets('the sliding pill settles exactly under the selected tab',
        (tester) async {
      tester.view.physicalSize = const Size(402 * 3, 874 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      await _pumpShell(tester);
      final pill = find.byWidgetPredicate((w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          (w.decoration as BoxDecoration).gradient == ZyndioGradients.brand &&
          (w.decoration as BoxDecoration).borderRadius ==
              const BorderRadius.all(Radius.circular(26)));
      for (final label in [
        'My Plan, tab 4 of 5',
        'Progress, tab 2 of 5',
        'Care, tab 5 of 5',
        'Today, tab 1 of 5',
      ]) {
        await tester.tap(find.bySemanticsLabel(label));
        await tester.pumpAndSettle();
        final tab = tester.getRect(find.bySemanticsLabel(label));
        final p = tester.getRect(pill);
        // The pill sits 4pt inside its tab on each side.
        expect(p.left, moreOrLessEquals(tab.left + 4, epsilon: 0.5),
            reason: label);
        expect(p.width, moreOrLessEquals(tab.width - 8, epsilon: 0.5),
            reason: label);
      }
      handle.dispose();
    });

    testWidgets('store build hides every Appointments entry point',
        (tester) async {
      await _pumpShell(tester);
      await tester.tap(find.bySemanticsLabel('Progress, tab 2 of 5'));
      await tester.pumpAndSettle();
      expect(find.text('No DEXASCAN results yet'), findsOneWidget);
      expect(find.text('Book my baseline scan'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Care, tab 5 of 5'));
      await tester.pumpAndSettle();
      expect(find.text('Appointments'), findsNothing);
    });

    testWidgets('with appointmentsEnabled the entry points come back',
        (tester) async {
      await _pumpShell(tester,
          flags: const FeatureFlags(appointmentsEnabled: true));
      await tester.tap(find.bySemanticsLabel('Progress, tab 2 of 5'));
      await tester.pumpAndSettle();
      expect(find.text('Book my baseline scan'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Care, tab 5 of 5'));
      await tester.pumpAndSettle();
      expect(find.text('Appointments'), findsOneWidget);
    });

    testWidgets(
        'the signed-in shell asks for notifications once, not again on rebuild',
        (tester) async {
      final fake = _FakeRequester();
      await _pumpShell(tester, requester: fake);
      expect(fake.calls, 1);
      await tester.tap(find.bySemanticsLabel('Care, tab 5 of 5'));
      await tester.pumpAndSettle();
      expect(fake.calls, 1);
    });

    testWidgets('brand-row avatar opens Profile & settings', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(tester);
      expect(find.bySemanticsLabel('Profile and settings'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Profile and settings'));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS SCREEN'), findsOneWidget);
      handle.dispose();
    });

    // H1 (Ava, PR #30 review): a screen-reader activation (SemanticsAction.tap)
    // must do exactly what a finger tap does.
    testWidgets('H1: semantics tap on every tab switches to that tab',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(tester);

      bool selected(String label) =>
          tester
              .getSemantics(find.bySemanticsLabel(label))
              .getSemanticsData()
              .flagsCollection
              .isSelected ==
          Tristate.isTrue;

      final cases = <String, Finder>{
        'Progress, tab 2 of 5': find.text('No DEXASCAN results yet'),
        'Biomarkers, tab 3 of 5': find.byType(BiomarkersScreen),
        'My Plan, tab 4 of 5': find.text('MY PLAN STUB'),
        'Care, tab 5 of 5': find.text('My Care'),
        'Today, tab 1 of 5': find.byType(TodayScreen),
      };
      for (final e in cases.entries) {
        final node = find.semantics.byLabel(e.key).evaluate().single;
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
            reason: '${e.key} exposes SemanticsAction.tap');
        tester.semantics.tap(find.semantics.byLabel(e.key));
        await tester.pumpAndSettle();
        expect(selected(e.key), isTrue, reason: '${e.key} is now selected');
        expect(e.value.hitTestable(), findsOneWidget,
            reason: '${e.key} screen shown');
      }
      handle.dispose();
    });

    testWidgets('H1: semantics tap on the avatar opens Profile & settings',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(tester);
      tester.semantics.tap(find.semantics.byLabel('Profile and settings'));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS SCREEN'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('renders in dark mode without error', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpShell(tester, b: Brightness.dark);
      expect(find.bySemanticsLabel('Biomarkers, tab 3 of 5'), findsOneWidget);
      handle.dispose();
    });
  });
}
