import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/demo_app.dart';
import 'package:zyndio_patient/demo/logic/clock.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';
import 'package:zyndio_patient/demo/router/demo_state.dart';
import 'package:zyndio_patient/demo/screens/consent/consent_state.dart';
import 'package:zyndio_patient/demo/screens/consent/consent_view.dart';
import 'package:zyndio_patient/demo/screens/lab_review/lab_review_state.dart';
import 'package:zyndio_patient/demo/screens/lab_review/lab_review_view.dart';
import 'package:zyndio_patient/demo/screens/lab_trends/lab_trends_state.dart';
import 'package:zyndio_patient/demo/screens/lab_trends/lab_trends_view.dart';
import 'package:zyndio_patient/demo/screens/lab_upload/lab_upload_state.dart';
import 'package:zyndio_patient/demo/screens/lab_upload/lab_upload_view.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_state.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_view.dart';

/// Clause 9.1 / Clara review finding 3: the old base screens' "Disease
/// risk", "Biological age" and "URGENT" must never be reachable or visible
/// anywhere in the demo build. This pumps every screen/state the demo ships
/// (both themes) and asserts none of those strings appear. Add the
/// `?flow=journey` path here too once it exists (Step 6).
const _forbiddenPatterns = [
  'disease risk',
  'biological age',
  'urgent',
];

void main() {
  Widget wrap(Widget child, Brightness brightness) {
    return MaterialApp(
      theme: brightness == Brightness.light ? BrandTheme.lightTheme : BrandTheme.darkTheme,
      home: child,
    );
  }

  void expectNoForbiddenWording(WidgetTester tester) {
    for (final pattern in _forbiddenPatterns) {
      expect(
        find.textContaining(RegExp(pattern, caseSensitive: false)),
        findsNothing,
        reason: 'Forbidden wording "$pattern" must never be reachable in the demo build.',
      );
    }
  }

  group('Sign-in (01/07): no forbidden wording in any state/mode', () {
    for (final brightness in Brightness.values) {
      for (final state in [
        SignInState.defaultState(),
        SignInState.sending(),
        SignInState.code(),
        SignInState.error(),
        SignInState.locked(),
        SignInState.offline(),
      ]) {
        testWidgets('$brightness state', (tester) async {
          await tester.pumpWidget(wrap(SignInView(state: state), brightness));
          expectNoForbiddenWording(tester);
        });
      }
    }
  });

  group('Consent (02): no forbidden wording in any state/mode', () {
    for (final brightness in Brightness.values) {
      for (final state in [
        ConsentState.unchecked(),
        ConsentState.partnerOn(),
        ConsentState.validation(),
        ConsentState.loading(),
        ConsentState.docLoadError(),
        ConsentState.complete(),
      ]) {
        testWidgets('$brightness state', (tester) async {
          await tester.pumpWidget(wrap(ConsentView(state: state), brightness));
          expectNoForbiddenWording(tester);
        });
      }
    }
  });

  group('Lab upload (03): no forbidden wording in any state/mode', () {
    for (final brightness in Brightness.values) {
      for (final state in [
        LabUploadState.empty(),
        LabUploadState.defaultState(),
        LabUploadState.uploading(),
        LabUploadState.duplicate(),
        LabUploadState.offline(),
        LabUploadState.error(),
      ]) {
        testWidgets('$brightness state', (tester) async {
          await tester.pumpWidget(wrap(LabUploadView(state: state), brightness));
          expectNoForbiddenWording(tester);
        });
      }
    }
  });

  group('Lab review (04): no forbidden wording in any state/mode', () {
    for (final brightness in Brightness.values) {
      for (final state in [
        LabReviewState.loading(),
        LabReviewState.defaultState(),
        LabReviewState.mismatch(),
        LabReviewState.empty(),
        LabReviewState.error(),
        LabReviewState.saved(),
      ]) {
        testWidgets('$brightness state', (tester) async {
          await tester.pumpWidget(wrap(LabReviewView(state: state), brightness));
          expectNoForbiddenWording(tester);
        });
      }
    }
  });

  group('Lab trends (05/06): no forbidden wording in any state/mode', () {
    for (final brightness in Brightness.values) {
      for (final state in [
        LabTrendsState.loading(),
        LabTrendsState.defaultState(),
        LabTrendsState.single(),
        LabTrendsState.error(),
        LabTrendsState.above(),
      ]) {
        testWidgets('$brightness state', (tester) async {
          await tester.pumpWidget(wrap(LabTrendsView(state: state), brightness));
          expectNoForbiddenWording(tester);
        });
      }
    }
  });

  testWidgets('DemoApp (interactive, default route): no forbidden wording', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DemoApp()));
    await tester.pumpAndSettle();
    expectNoForbiddenWording(tester);
  });

  testWidgets(
    'DemoApp (?flow=journey): no forbidden wording on any screen reached',
    tags: ['demo_flow'],
    (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final clock = FakeClock(DateTime(2026, 1, 1, 9, 0, 0));
    final backend = DemoBackend(clock: clock);
    final container = ProviderContainer(overrides: [
      demoClockProvider.overrideWithValue(clock),
      demoBackendProvider.overrideWithValue(backend),
    ]);
    addTearDown(container.dispose);

    Future<void> tapByScrollingIntoView(Finder finder) async {
      await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable));
      await tester.tap(finder);
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DemoApp(initialParams: DemoRouteParams(flow: 'journey')),
      ),
    );
    await tester.pumpAndSettle();
    expectNoForbiddenWording(tester); // sign-in, email step

    await tester.enterText(find.byKey(const Key('signin-email-field')), demoPatient.email);
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expectNoForbiddenWording(tester); // sign-in, code step

    final code = backend.debugLastIssuedCode(demoPatient.email)!;
    await tester.enterText(find.byType(TextField), code);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expectNoForbiddenWording(tester); // consent

    await tester.tap(find.text('Terms of Service'));
    await tester.pump();
    await tester.tap(find.text('Privacy Notice'));
    await tester.pump();
    await tester.tap(find.text('Consent to use my health data'));
    await tester.pump();
    await tapByScrollingIntoView(find.text('Agree and continue'));
    await tester.pumpAndSettle();
    expectNoForbiddenWording(tester); // lab upload

    await tapByScrollingIntoView(find.text('Choose a PDF'));
    await tester.pumpAndSettle();
    expectNoForbiddenWording(tester); // lab review

    await tapByScrollingIntoView(find.text('Save results'));
    await tester.pumpAndSettle();
    await tapByScrollingIntoView(find.text('Done'));
    await tester.pumpAndSettle();
    expectNoForbiddenWording(tester); // lab trends
  });
}
