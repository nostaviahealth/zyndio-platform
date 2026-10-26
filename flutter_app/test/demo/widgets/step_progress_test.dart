import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/step_progress.dart';

void main() {
  testWidgets('StepProgress renders and announces its fraction', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: const Scaffold(body: StepProgress(value: 0.5)),
      ),
    );

    expect(find.byType(StepProgress), findsOneWidget);
    expect(find.bySemanticsLabel('Step progress'), findsOneWidget);
    handle.dispose();
  });
}
