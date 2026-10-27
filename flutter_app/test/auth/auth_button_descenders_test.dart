// Ava round 3 must-fix: Inter descenders (p, y, g) were clipped in auth
// button labels ("Open mail app", "Go to Today", "Link my record") because
// the text box had no line-height headroom. Guards that every auth button
// variant gives its label >=1.2 line height with room reserved below the
// baseline (applyHeightToLastDescent), without growing the fixed 50px button.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/screens/auth/widgets/patient_auth_chrome.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: BrandTheme.lightTheme, home: Scaffold(body: child));

void _expectNoClippedDescenders(Finder finder) {
  final text = finder.evaluate().single.widget as Text;
  final style = text.style;
  expect(style, isNotNull);
  expect(style!.height, isNotNull);
  expect(style.height!, greaterThanOrEqualTo(1.2));

  final behavior = text.textHeightBehavior;
  expect(
    behavior != null && behavior.applyHeightToLastDescent,
    isTrue,
    reason: 'label must reserve height below the baseline for Inter '
        'descenders (p, y, g) or TextHeightBehavior must enable '
        'applyHeightToLastDescent',
  );
}

void main() {
  group('Auth button labels never clip descenders (Ava R3)', () {
    testWidgets('AuthPrimaryButton — "Open mail app"', (tester) async {
      await tester.pumpWidget(_wrap(
        AuthPrimaryButton(label: 'Open mail app', onPressed: () {}),
      ));
      _expectNoClippedDescenders(find.text('Open mail app'));
      expect(
        tester.getSize(find.byType(AuthPrimaryButton)).height,
        50,
        reason: 'button height must stay 50 even with the taller line box',
      );
    });

    testWidgets('AuthPrimaryButton loading — "Open mail app"', (tester) async {
      await tester.pumpWidget(_wrap(
        AuthPrimaryButton(
            label: 'Open mail app', onPressed: () {}, loading: true),
      ));
      _expectNoClippedDescenders(find.text('Open mail app'));
    });

    testWidgets('AuthSecondaryButton (outlined) — "Go to Today"', (tester) async {
      await tester.pumpWidget(_wrap(
        AuthSecondaryButton(label: 'Go to Today', onPressed: () {}),
      ));
      _expectNoClippedDescenders(find.text('Go to Today'));
    });

    testWidgets('AuthSecondaryButton (text) — "Go to Today"', (tester) async {
      await tester.pumpWidget(_wrap(
        AuthSecondaryButton(
            label: 'Go to Today', onPressed: () {}, outlined: false),
      ));
      _expectNoClippedDescenders(find.text('Go to Today'));
    });

    testWidgets('AuthPrimaryButton — "Link my record"', (tester) async {
      await tester.pumpWidget(_wrap(
        AuthPrimaryButton(label: 'Link my record', onPressed: () {}),
      ));
      _expectNoClippedDescenders(find.text('Link my record'));
    });

    testWidgets('AuthPrimaryButton destructive — "Delete account"', (tester) async {
      await tester.pumpWidget(_wrap(
        AuthPrimaryButton(
            label: 'Delete account', onPressed: () {}, destructive: true),
      ));
      _expectNoClippedDescenders(find.text('Delete account'));
    });

    testWidgets('AuthPrimaryButton destructive loading — "Deleting…"', (tester) async {
      await tester.pumpWidget(_wrap(
        AuthPrimaryButton(
            label: 'Deleting…',
            onPressed: () {},
            destructive: true,
            loading: true),
      ));
      _expectNoClippedDescenders(find.text('Deleting…'));
    });
  });
}
