import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/footer_links.dart';

void main() {
  testWidgets('FooterLinks shows Terms, Privacy and Help each with a >=44 hit area', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: const Scaffold(body: FooterLinks())),
    );

    expect(find.text('Terms'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Help'), findsOneWidget);

    final buttons = find.byType(TextButton);
    for (var i = 0; i < tester.widgetList(buttons).length; i++) {
      expect(tester.getSize(buttons.at(i)).height, greaterThanOrEqualTo(44));
    }
  });

  testWidgets('tapping a link invokes its callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: Scaffold(body: FooterLinks(onTerms: () => tapped = true)),
      ),
    );

    await tester.tap(find.text('Terms'));
    expect(tapped, isTrue);
  });
}
