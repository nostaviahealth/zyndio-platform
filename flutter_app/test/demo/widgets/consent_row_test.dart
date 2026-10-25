import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/consent_row.dart';

Widget _wrap(Widget child) => MaterialApp(theme: BrandTheme.lightTheme, home: Scaffold(body: child));

void main() {
  group('ConsentRow', () {
    testWidgets('unchecked: shows the default subline and a Read link', (tester) async {
      var toggled = false;
      await tester.pumpWidget(
        _wrap(
          ConsentRow(
            title: 'Terms of Service',
            subline: 'Version 0.1 · placeholder text',
            checked: false,
            onToggle: () => toggled = true,
          ),
        ),
      );

      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Version 0.1 · placeholder text'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);

      await tester.tap(find.text('Terms of Service'));
      expect(toggled, isTrue);
    });

    testWidgets('showRequiredError: swaps the subline for the critical copy', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConsentRow(
            title: 'Privacy Notice',
            subline: 'Version 0.1 · placeholder text',
            checked: false,
            showRequiredError: true,
          ),
        ),
      );

      expect(find.text('Required to continue'), findsOneWidget);
      expect(find.text('Version 0.1 · placeholder text'), findsNothing);
    });

    testWidgets('hasError: shows a Retry link instead of Read', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ConsentRow(
            title: 'Privacy Notice',
            subline: 'Version 0.1 · placeholder text',
            checked: false,
            hasError: true,
          ),
        ),
      );

      expect(find.text("Couldn't load this document"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Read'), findsNothing);
    });
  });
}
