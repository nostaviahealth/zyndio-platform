import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/history_row.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: BrandTheme.lightTheme, home: Scaffold(body: child));

  testWidgets('exposes date/value/unit as one accessibility label and meets the 48pt minimum row height', (tester) async {
    await tester.pumpWidget(wrap(const HistoryRow(date: 'Oct 14, 2026', value: '5.5', unit: '%')));

    expect(find.bySemanticsLabel('Oct 14, 2026, 5.5 %'), findsOneWidget);
    final box = tester.renderObject<RenderBox>(find.byType(HistoryRow));
    expect(box.size.height, greaterThanOrEqualTo(48));
  });
}
