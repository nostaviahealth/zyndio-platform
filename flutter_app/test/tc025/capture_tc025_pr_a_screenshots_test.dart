import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/models/lab_report.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/intelligence_provider.dart';
import 'package:zyndio_patient/providers/lab_reports_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/providers/wearable_sync_provider.dart';
import 'package:zyndio_patient/screens/biomarkers/biomarkers_screen.dart';
import 'package:zyndio_patient/screens/care/care_screen.dart';
import 'package:zyndio_patient/screens/progress/progress_screen.dart';
import 'package:zyndio_patient/screens/today/today_screen.dart';
import 'package:zyndio_patient/widgets/main_shell.dart';

/// TC-025 PR A screenshot capture.
///
/// Pumps the REAL production `MainShell` (5-tab bar) with the real
/// `TodayScreen`, `BiomarkersScreen`, `ProgressScreen` and `CareScreen` under
/// BrandTheme light/dark at 390×844 logical (DPR 2 → 780×1688 PNG), with Inter
/// + Lucide fonts loaded (not Ahem). Data is fictional and injected through
/// provider overrides only; no app code is changed.
///
/// Capture-only: every test is skipped unless run with --update-goldens, so it
/// never gates CI. Output lands in docs/screenshots/tc-025/pr-a/.
///
/// Run (from flutter_app/):
///   flutter test test/tc025/capture_tc025_pr_a_screenshots_test.dart --update-goldens

const _logical = Size(390, 844);
const _dpr = 2.0;
const _out = '../../../docs/screenshots/tc-025/pr-a';

Future<void> _loadAppFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-VariableFont_opsz,wght.ttf'));
  await inter.load();

  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/home/box/sdk/flutter';
  final iconsPath =
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  if (File(iconsPath).existsSync()) {
    final b = File(iconsPath).readAsBytesSync();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.view(b.buffer))))
        .load();
  }
  final robotoPath =
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
  if (File(robotoPath).existsSync()) {
    final b = File(robotoPath).readAsBytesSync();
    await (FontLoader('Roboto')..addFont(Future.value(ByteData.view(b.buffer))))
        .load();
  }
  final home = Platform.environment['HOME'] ?? '/home/box';
  final pubCache = Platform.environment['PUB_CACHE'] ?? '$home/.pub-cache';
  final hosted = Directory('$pubCache/hosted/pub.dev');
  if (hosted.existsSync()) {
    final dirs = hosted
        .listSync()
        .whereType<Directory>()
        .where((d) => d.path.contains('lucide_icons_flutter-'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final d in dirs) {
      final f = File('${d.path}/assets/lucide.ttf');
      if (f.existsSync()) {
        final b = f.readAsBytesSync();
        await (FontLoader('packages/lucide_icons_flutter/Lucide')
              ..addFont(Future.value(ByteData.view(b.buffer))))
            .load();
        break;
      }
    }
  }
}

class _Profile extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async =>
      PatientProfile(id: 'p1', name: 'Jordan Rivera', subscriptionPlan: 'free');
}

class _Wearable extends WearableSyncNotifier {
  _Wearable(this._state, {this.loadForever = false, this.fail = false});
  final WearableSyncState _state;
  final bool loadForever;
  final bool fail;
  @override
  Future<WearableSyncState> build() async {
    if (loadForever) return Completer<WearableSyncState>().future;
    if (fail) throw StateError('fictional failure');
    return _state;
  }
}

WearableSyncState _synced() => WearableSyncState(
      snapshot: const WearableSnapshot(
          sleepHours: 7.3, steps: 8421, hrv: 61, hrvBaseline: 58),
      lastSynced: DateTime(2026, 11, 3, 9, 5),
    );

LabMarker _m(String name, String value,
        {String unit = '',
        double? low,
        double? high,
        String status = 'In-range'}) =>
    LabMarker(
        name: name,
        value: value,
        range: '',
        status: status,
        unit: unit,
        minRange: low,
        maxRange: high);

/// Fictional reports only.
List<LabReport> _reports() => [
      LabReport(
        id: 'r3',
        date: '2026-09-15',
        title: 'Longevity panel',
        summary: '',
        markers: [
          _m('Intracellular NAD+', '41', unit: 'µM', low: 25, high: 60),
          _m('NADH', '3.1', unit: 'µM', low: 1.5, high: 4.0),
          _m('HbA1c', '5.2', unit: '%', low: 4.0, high: 5.6),
          _m('Fasting Glucose', '92', unit: 'mg/dL', low: 65, high: 99),
          _m('LDL Cholesterol', '140',
              unit: 'mg/dL', low: 0, high: 129, status: 'High'),
          _m('HDL Cholesterol', '58', unit: 'mg/dL', low: 40, high: 100),
          _m('Testosterone', '600', unit: 'ng/dL', low: 300, high: 1000),
          _m('hs-CRP', '0.8', unit: 'mg/L', low: 0, high: 3),
        ],
      ),
      LabReport(
        id: 'r2',
        date: '2026-06-01',
        title: 'Follow-up panel',
        summary: '',
        markers: [_m('Intracellular NAD+', '33', unit: 'µM', low: 25, high: 60)],
      ),
      LabReport(
        id: 'r1',
        date: '2026-01-10',
        title: 'Baseline panel',
        summary: '',
        markers: [_m('Intracellular NAD+', '26', unit: 'µM', low: 25, high: 60)],
      ),
    ];

GoRouter _router(String initial) => GoRouter(
      initialLocation: initial,
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
                  pageBuilder: (c, s) =>
                      const NoTransitionPage(child: SizedBox.shrink())),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/care',
                  pageBuilder: (c, s) =>
                      const NoTransitionPage(child: CareScreen())),
            ]),
          ],
        ),
      ],
    );

class _Shot {
  const _Shot(this.name, this.initial,
      {this.wearable, this.labs, this.after, this.settle = true});
  final String name;
  final String initial;
  final WearableSyncNotifier Function()? wearable;
  final Future<List<LabReport>> Function()? labs;
  final Future<void> Function(WidgetTester)? after;
  final bool settle;
}

final _shots = <_Shot>[
  _Shot('today-default', '/', wearable: () => _Wearable(_synced())),
  _Shot('today-no-wearable', '/',
      wearable: () => _Wearable(WearableSyncState(error: 'Not linked'))),
  _Shot('today-offline', '/',
      wearable: () => _Wearable(WearableSyncState(
          snapshot: _synced().snapshot,
          error: 'network',
          lastSynced: DateTime(2026, 11, 3, 9, 5)))),
  _Shot('today-loading', '/',
      wearable: () => _Wearable(WearableSyncState(), loadForever: true),
      settle: false),
  _Shot('today-error', '/',
      wearable: () => _Wearable(WearableSyncState(), fail: true)),
  _Shot('biomarkers-nad', '/biomarkers', labs: () async => _reports()),
  _Shot('biomarkers-metabolic', '/biomarkers',
      labs: () async => _reports(), after: (t) async {
    await t.tap(find.text('Metabolic').first);
    await t.pumpAndSettle();
  }),
  _Shot('biomarkers-hormones-single', '/biomarkers',
      labs: () async => _reports(), after: (t) async {
    await t.tap(find.text('Hormones').first);
    await t.pumpAndSettle();
  }),
  _Shot('biomarkers-empty', '/biomarkers', labs: () async => const []),
  _Shot('biomarkers-loading', '/biomarkers',
      labs: () => Completer<List<LabReport>>().future, settle: false),
  _Shot('biomarkers-error', '/biomarkers',
      labs: () async => throw StateError('fictional failure')),
  _Shot('shell-progress-interim', '/progress'),
  _Shot('shell-care-interim', '/care'),
];

Future<void> _pump(WidgetTester tester, _Shot s, bool dark) async {
  tester.view.physicalSize =
      Size(_logical.width * _dpr, _logical.height * _dpr);
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final base = dark ? BrandTheme.darkTheme : BrandTheme.lightTheme;
  final theme = base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'Inter'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        patientProfileProvider.overrideWith(() => _Profile()),
        aiInsightsProvider.overrideWithValue(const [
          'Your HRV has been a little higher than your 7-day average this week.'
        ]),
        wearableSyncProvider
            .overrideWith(s.wearable ?? () => _Wearable(_synced())),
        labReportsProvider
            .overrideWith((ref) => (s.labs ?? () async => _reports())()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: theme,
        routerConfig: _router(s.initial),
      ),
    ),
  );
  // Decode asset images (brand mark) for real before the capture; widget
  // tests otherwise leave the first Image.asset blank.
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  if (s.settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (s.after != null) await s.after!(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadAppFonts);

  for (final mode in ['light', 'dark']) {
    for (final s in _shots) {
      testWidgets('${s.name}--$mode', (tester) async {
        await _pump(tester, s, mode == 'dark');
        await expectLater(find.byType(MaterialApp).first,
            matchesGoldenFile('$_out/${s.name}--$mode.png'));
      },
          skip: !autoUpdateGoldenFiles,
          timeout: const Timeout(Duration(seconds: 60)));
    }
  }
}
