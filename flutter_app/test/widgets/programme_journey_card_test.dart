import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/data/programme_journey.dart';
import 'package:zyndio_patient/providers/feature_flags_provider.dart';
import 'package:zyndio_patient/providers/programme_journey_provider.dart';
import 'package:zyndio_patient/widgets/programme_journey_card.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

Future<void> _pump(
  WidgetTester tester,
  ProgrammeJourney? journey, {
  bool canBook = false,
  Widget child = const ProgrammeJourneyCard(),
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(402 * 3, 1400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (c, s) => Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
    GoRoute(
        path: '/progress',
        builder: (c, s) => const Scaffold(body: Text('PROGRESS'))),
    GoRoute(
        path: '/upload',
        name: 'upload_report',
        builder: (c, s) => const Scaffold(body: Text('UPLOAD'))),
    GoRoute(
        path: '/appointments',
        name: 'appointments',
        builder: (c, s) => const Scaffold(body: Text('APPOINTMENTS'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      programmeJourneyProvider.overrideWithValue(journey),
      featureFlagsProvider
          .overrideWithValue(FeatureFlags(appointmentsEnabled: canBook)),
    ],
    child: MaterialApp.router(
      theme: brightness == Brightness.light
          ? BrandTheme.lightTheme
          : BrandTheme.darkTheme,
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}

ProgrammeJourney _setup({bool labs = false}) => buildProgrammeJourney(
      scanDates: const [],
      hasLabResults: labs,
      hasCarePlan: false,
      today: d(2026, 11, 9),
    );

ProgrammeJourney _demoStory() => buildProgrammeJourney(
      scanDates: [d(2026, 4, 8), d(2026, 7, 9), d(2026, 10, 2)],
      hasLabResults: true,
      hasCarePlan: true,
      today: d(2026, 11, 9),
    );

void main() {
  testWidgets('renders nothing while the journey is unknown', (tester) async {
    await _pump(tester, null);
    expect(find.text('YOUR PROGRAMME'), findsNothing);
  });

  testWidgets('getting started: progress, steps, and Upload labs opens upload',
      (tester) async {
    await _pump(tester, _setup());
    expect(find.text('YOUR PROGRAMME'), findsOneWidget);
    expect(find.text('Getting started'), findsOneWidget);
    expect(find.text('0 of 3 steps done'), findsOneWidget);
    expect(find.text('Upload your baseline labs'), findsOneWidget);
    expect(find.text('Get your baseline DEXASCAN'), findsOneWidget);
    expect(find.text('Your physician starts your plan'), findsOneWidget);
    await tester.tap(find.text('Upload labs'));
    await tester.pumpAndSettle();
    expect(find.text('UPLOAD'), findsOneWidget);
  });

  testWidgets('scan step offers booking only when Appointments is on',
      (tester) async {
    await _pump(tester, _setup(labs: true));
    expect(find.text('1 of 3 steps done'), findsOneWidget);
    expect(find.text('Book scan'), findsNothing);
    expect(find.text('Lab results added.'), findsOneWidget);

    await _pump(tester, _setup(labs: true), canBook: true);
    await tester.tap(find.text('Book scan'));
    await tester.pumpAndSettle();
    expect(find.text('APPOINTMENTS'), findsOneWidget);
  });

  testWidgets('after the baseline: programme day, track and next milestone',
      (tester) async {
    await _pump(tester, _demoStory());
    expect(find.text('Day 215 of your programme'), findsOneWidget);
    expect(find.text('Baseline scan 8 Apr 2026'), findsOneWidget);
    for (final l in ['Baseline', 'Day 90', 'Day 180', 'Day 365']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('Next: Day 365 scan and labs'), findsOneWidget);
    expect(find.text('Due 8 Apr 2027 · in 150 days'), findsOneWidget);
    // Not yet in the booking window: no Book button.
    expect(find.text('Book'), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp(
          r'Day 90, scan received 9 Jul 2026\. Day 180, scan received 2 Oct 2026')),
      findsOneWidget,
    );
  });

  testWidgets('booking window open: Book when Appointments is on, else a note',
      (tester) async {
    final j = buildProgrammeJourney(
      scanDates: [d(2026, 8, 20)], // Day 90 = 18 Nov 2026
      hasLabResults: true,
      hasCarePlan: true,
      today: d(2026, 11, 9),
    );
    await _pump(tester, j);
    expect(find.text('Book'), findsNothing);
    expect(find.textContaining('Your clinic will help you book both.'),
        findsOneWidget);

    await _pump(tester, j, canBook: true);
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();
    expect(find.text('APPOINTMENTS'), findsOneWidget);
  });

  testWidgets('missing labs after a baseline still shows as a to-do',
      (tester) async {
    final j = buildProgrammeJourney(
      scanDates: [d(2026, 10, 1)],
      hasLabResults: false,
      hasCarePlan: false,
      today: d(2026, 11, 9),
    );
    await _pump(tester, j);
    expect(find.text('Upload your baseline labs'), findsOneWidget);
    expect(find.text('Your physician starts your plan'), findsOneWidget);
  });

  testWidgets('the chevron opens Body Composition', (tester) async {
    await _pump(tester, _demoStory());
    await tester.tap(find.bySemanticsLabel('Open body composition'));
    await tester.pumpAndSettle();
    expect(find.text('PROGRESS'), findsOneWidget);
  });

  testWidgets('schedule card lists baseline and each milestone neutrally',
      (tester) async {
    final j = buildProgrammeJourney(
      scanDates: [d(2026, 1, 1), d(2026, 7, 1)], // Day 90 window passed
      hasLabResults: true,
      hasCarePlan: true,
      today: d(2026, 7, 10),
    );
    await _pump(tester, j, child: const ProgrammeScheduleCard());
    expect(find.text('YOUR SCAN SCHEDULE'), findsOneWidget);
    expect(find.text('Baseline scan'), findsOneWidget);
    expect(find.text('No scan recorded'), findsOneWidget);
    expect(find.text('Scan received 1 Jul 2026'), findsOneWidget);
    expect(find.text('Due 1 Jan 2027 · in 175 days'), findsOneWidget);
  });

  testWidgets('first programme year complete', (tester) async {
    final j = buildProgrammeJourney(
      scanDates: [d(2025, 1, 1), d(2026, 1, 2)],
      hasLabResults: true,
      hasCarePlan: true,
      today: d(2026, 3, 1),
    );
    await _pump(tester, j);
    expect(find.text('First programme year complete'), findsOneWidget);
  });

  testWidgets('dark mode renders without errors', (tester) async {
    await _pump(tester, _demoStory(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
    await _pump(tester, _setup(), brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  test('relative day wording', () {
    expect(relativeDays(0), 'today');
    expect(relativeDays(1), 'tomorrow');
    expect(relativeDays(-1), 'yesterday');
    expect(relativeDays(5), 'in 5 days');
    expect(relativeDays(-3), '3 days ago');
  });
}
