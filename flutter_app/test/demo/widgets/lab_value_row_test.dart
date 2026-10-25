import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/lab_value_row.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: BrandTheme.lightTheme, home: Scaffold(body: child));

  testWidgets('renders name, value and unit', (tester) async {
    await tester.pumpWidget(wrap(const LabValueRow(name: 'HbA1c', value: '5.5', unit: '%')));

    expect(find.text('HbA1c'), findsOneWidget);
    expect(find.text('5.5'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);
    expect(find.text('Needs review'), findsNothing);
  });

  testWidgets('shows the Needs review badge and reason when flagged', (tester) async {
    await tester.pumpWidget(
      wrap(
        const LabValueRow(
          name: 'hsCRP',
          value: '1.7',
          unit: 'mg/L',
          needsReviewReason: 'Hard to read on page 2',
        ),
      ),
    );

    expect(find.text('Needs review'), findsOneWidget);
    expect(find.text('Hard to read on page 2'), findsOneWidget);
    expect(find.text('1.7'), findsOneWidget);
  });
}
