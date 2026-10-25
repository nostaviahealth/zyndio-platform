import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/logic/clock.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';
import 'package:zyndio_patient/demo/screens/consent/consent_controller.dart';
import 'package:zyndio_patient/demo/screens/consent/consent_state.dart';
import 'package:zyndio_patient/demo/screens/consent/consent_view.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? BrandTheme.lightTheme : BrandTheme.darkTheme,
    home: child,
  );
}

void main() {
  group('ConsentView', () {
    testWidgets('unchecked: button stays enabled with all 3 docs unticked', (tester) async {
      await tester.pumpWidget(_wrap(ConsentView(state: ConsentState.unchecked())));

      expect(find.text('Before we begin'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Notice'), findsOneWidget);
      expect(find.text('Consent to use my health data'), findsOneWidget);

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('partner-on: shows the partner sharing copy with the switch on', (tester) async {
      await tester.pumpWidget(_wrap(ConsentView(state: ConsentState.partnerOn())));

      expect(
        find.text('Share progress with my body composition partner'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Turn this off any time in Settings, and future sharing stops.'),
        findsOneWidget,
      );
    });

    testWidgets('validation: only the unticked required row turns critical', (tester) async {
      await tester.pumpWidget(_wrap(ConsentView(state: ConsentState.validation())));

      expect(find.text('Required to continue'), findsOneWidget);
      // Terms and the health-data consent are checked and show their normal subline.
      expect(find.text('Version 0.1 · placeholder text'), findsOneWidget);
      expect(find.text("Version 0.1 · for your care team's review"), findsOneWidget);
    });

    testWidgets('loading: shows skeleton rows and no interactive controls', (tester) async {
      await tester.pumpWidget(_wrap(ConsentView(state: ConsentState.loading())));

      expect(find.text('Loading the latest versions…'), findsOneWidget);
      expect(find.text('Agree and continue'), findsNothing);
      expect(find.text('Terms of Service'), findsNothing);
    });

    testWidgets("error: the document's subline becomes an error and Read becomes Retry", (tester) async {
      await tester.pumpWidget(_wrap(ConsentView(state: ConsentState.docLoadError())));

      expect(find.text("Couldn't load this document"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('complete: all 3 docs checked, PLACEHOLDER visible on terms/privacy/consent', (tester) async {
      await tester.pumpWidget(_wrap(ConsentView(state: ConsentState.complete())));

      expect(find.textContaining('placeholder text'), findsNWidgets(2));
      expect(find.textContaining('placeholder'), findsWidgets);
      expect(find.text('Agree and continue'), findsOneWidget);
      expect(
        find.text('We keep a record of each version you agree to and when.'),
        findsOneWidget,
      );
    });

    testWidgets('every state builds in dark mode too', (tester) async {
      final states = [
        ConsentState.unchecked(),
        ConsentState.partnerOn(),
        ConsentState.validation(),
        ConsentState.loading(),
        ConsentState.docLoadError(),
        ConsentState.complete(),
      ];
      for (final state in states) {
        await tester.pumpWidget(_wrap(ConsentView(state: state), brightness: Brightness.dark));
        expect(find.byType(ConsentView), findsOneWidget);
      }
    });
  });

  group('ConsentController', () {
    test('agreeing to all 3 docs stores a version + timestamp record per doc', () {
      final clock = FakeClock(DateTime(2026, 10, 25, 9, 0));
      final backend = DemoBackend(clock: clock);
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(consentControllerProvider.notifier);
      for (final doc in consentDocs) {
        controller.toggleDoc(doc.id);
      }
      final advanced = controller.submit();

      expect(advanced, isTrue);
      final session = container.read(currentSessionProvider)!.unwrap<DemoSession>();
      expect(backend.consentRecordsFor(session), hasLength(3));
      for (final record in backend.consentRecordsFor(session)) {
        expect(record.version, '0.1');
        expect(record.agreedAt, clock.now());
      }
    });

    test('submitting with an unticked doc marks only that row critical and does not record', () {
      final backend = DemoBackend(clock: const SystemClock());
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(consentControllerProvider.notifier);
      controller.toggleDoc(consentDocs[0].id);
      controller.toggleDoc(consentDocs[2].id);
      final advanced = controller.submit();

      expect(advanced, isFalse);
      // Validation failure returns before the repository/session is ever
      // touched, so nothing could have been recorded for any patient.
      expect(container.read(currentSessionProvider), isNull);
      final state = container.read(consentControllerProvider);
      expect(state.docs.firstWhere((d) => d.doc.id == consentDocs[1].id).showRequiredError, isTrue);
      expect(state.docs.firstWhere((d) => d.doc.id == consentDocs[0].id).showRequiredError, isFalse);
    });
  });
}
