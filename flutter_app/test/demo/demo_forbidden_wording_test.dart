import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/demo_app.dart';
import 'package:zyndio_patient/demo/screens/consent/consent_state.dart';
import 'package:zyndio_patient/demo/screens/consent/consent_view.dart';
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

  testWidgets('DemoApp (interactive, default route): no forbidden wording', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DemoApp()));
    await tester.pumpAndSettle();
    expectNoForbiddenWording(tester);
  });
}
