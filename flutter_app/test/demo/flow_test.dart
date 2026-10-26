import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/demo_app.dart';
import 'package:zyndio_patient/demo/logic/clock.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';
import 'package:zyndio_patient/demo/router/demo_state.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_controller.dart';
import 'package:zyndio_patient/demo/widgets/metric_header.dart';

/// Step 6: one journey test that walks sign-in -> consent -> lab upload ->
/// lab review -> lab trends through `?flow=journey`, driven entirely by real
/// taps and the real controllers/`DemoBackend` — never by constructing a
/// screen state by hand. Names follow Clara's TC-008_TEST_PLAN IDs
/// (T-AUTH, T-CONS, T-LAB, T-BIO).
void main() {
  ({ProviderContainer container, FakeClock clock, DemoBackend backend}) setUpJourney() {
    final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
    final backend = DemoBackend(clock: clock);
    final container = ProviderContainer(overrides: [
      demoClockProvider.overrideWithValue(clock),
      demoBackendProvider.overrideWithValue(backend),
    ]);
    return (container: container, clock: clock, backend: backend);
  }

  Future<void> pumpJourney(WidgetTester tester, ProviderContainer container) async {
    // Wide and tall enough that every screen's content is on-screen without
    // scrolling or triggering the 390-wide `MetricHeader` badge overflow
    // (a Step 5 visual concern, out of scope here) — this test proves
    // navigation/logic, not pixel-perfect mobile layout.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DemoApp(initialParams: DemoRouteParams(flow: 'journey')),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapByScrollingIntoView(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable));
    await tester.tap(finder);
  }

  testWidgets(
    'T-AUTH-01/02 + T-CONS-01/02 + T-LAB-03/05 + T-BIO-01/02: '
    'sign-in -> consent -> lab upload -> lab review -> lab trends, real logic end to end',
    (tester) async {
      final journey = setUpJourney();
      addTearDown(journey.container.dispose);
      await pumpJourney(tester, journey.container);

      // Sign-in: enter email, send code, enter the backend's own issued code.
      await tester.enterText(find.byKey(const Key('signin-email-field')), demoPatient.email);
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pump();
      expect(find.text('Enter your code'), findsOneWidget);

      final code = journey.backend.debugLastIssuedCode(demoPatient.email);
      expect(code, isNotNull);
      await tester.enterText(find.byType(TextField), code!);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Consent: agree to all 3 docs, continue.
      expect(find.text('Before we begin'), findsOneWidget);
      await tester.tap(find.text('Terms of Service'));
      await tester.pump();
      await tester.tap(find.text('Privacy Notice'));
      await tester.pump();
      await tester.tap(find.text('Consent to use my health data'));
      await tester.pump();
      await tapByScrollingIntoView(tester, find.text('Agree and continue'));
      await tester.pumpAndSettle();

      // Lab upload: pick a fictional PDF.
      expect(find.text('Choose a PDF'), findsOneWidget);
      await tapByScrollingIntoView(tester, find.text('Choose a PDF'));
      await tester.pumpAndSettle();

      // Lab review: save, then continue.
      expect(find.text('Check your results'), findsOneWidget);
      await tapByScrollingIntoView(tester, find.text('Save results'));
      await tester.pumpAndSettle();
      await tapByScrollingIntoView(tester, find.text('Done'));
      await tester.pumpAndSettle();

      // Lab trends: the fixture HbA1c trend, latest value and delta.
      expect(find.text('HbA1c'), findsOneWidget);
      expect(
        find.descendant(of: find.byType(MetricHeader), matching: find.text('5.5')),
        findsOneWidget,
      );
      expect(find.textContaining('−0.7 points since baseline'), findsOneWidget);
    },
  );

  testWidgets('T-AUTH-02: a code submitted after 10 minutes is rejected, not signed in', (tester) async {
    final journey = setUpJourney();
    addTearDown(journey.container.dispose);
    await pumpJourney(tester, journey.container);

    await tester.enterText(find.byKey(const Key('signin-email-field')), demoPatient.email);
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();

    final code = journey.backend.debugLastIssuedCode(demoPatient.email);
    expect(code, isNotNull);

    journey.clock.advance(const Duration(minutes: 10, seconds: 1));

    await tester.enterText(find.byType(TextField), code!);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Enter your code'), findsOneWidget, reason: 'expired code must not advance the flow');
    expect(journey.container.read(currentSessionProvider), isNull);
  });

  testWidgets('T-AUTH-03: 5 wrong codes lock the account, and the right code is then rejected', (tester) async {
    final journey = setUpJourney();
    addTearDown(journey.container.dispose);
    await pumpJourney(tester, journey.container);

    await tester.enterText(find.byKey(const Key('signin-email-field')), demoPatient.email);
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();

    final code = journey.backend.debugLastIssuedCode(demoPatient.email);
    expect(code, isNotNull);

    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Continue'));
      await tester.pump();
    }

    expect(journey.container.read(signInControllerProvider).isLocked, isTrue);

    await tester.enterText(find.byType(TextField), code!);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Before we begin'), findsNothing, reason: 'locked account must not reach consent');
    expect(journey.container.read(currentSessionProvider), isNull);
  });
}
