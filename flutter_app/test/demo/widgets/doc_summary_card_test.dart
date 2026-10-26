import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/doc_summary_card.dart';

void main() {
  testWidgets('DocSummaryCard renders title, subtitle and collected date', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: const Scaffold(
          body: DocSummaryCard(
            title: 'Metabolic panel',
            subtitle: 'Fictional Reference Lab · 2 pages',
            collectedLabel: 'Collected Oct 14, 2026',
          ),
        ),
      ),
    );

    expect(find.text('Metabolic panel'), findsOneWidget);
    expect(find.text('Fictional Reference Lab · 2 pages'), findsOneWidget);
    expect(find.text('Collected Oct 14, 2026'), findsOneWidget);
  });
}
