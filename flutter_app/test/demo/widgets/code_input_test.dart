import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/code_input.dart';

void main() {
  testWidgets('CodeInput renders 6 cells and reports digits entered', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: const Scaffold(body: CodeInput(value: '417'))),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.bySemanticsLabel('Verification code, 3 of 6 digits entered'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('CodeInput shows an empty field when the value is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: const Scaffold(body: CodeInput(value: ''))),
    );

    expect(find.byType(CodeInput), findsOneWidget);
  });
}
