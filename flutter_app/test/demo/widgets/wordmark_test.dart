import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/wordmark.dart';

void main() {
  testWidgets('Wordmark shows the ZYNDIO text and PLACEHOLDER tag', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: const Scaffold(body: Wordmark())),
    );

    expect(find.text('ZYNDIO'), findsOneWidget);
    expect(find.text('PLACEHOLDER'), findsOneWidget);
    expect(find.text('GLP-1 WEIGHT LOSS CARE'), findsOneWidget);
  });

  testWidgets('Wordmark is announced as a single "Zyndio" semantics node', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: const Scaffold(body: Wordmark())),
    );

    expect(find.bySemanticsLabel('Zyndio'), findsOneWidget);
    handle.dispose();
  });
}
