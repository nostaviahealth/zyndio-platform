import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/progress_bar.dart';

void main() {
  testWidgets('ProgressBar renders and announces its fraction complete', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: const Scaffold(body: ProgressBar(value: 0.6)),
      ),
    );

    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.bySemanticsLabel('Upload progress'), findsOneWidget);
    handle.dispose();
  });
}
