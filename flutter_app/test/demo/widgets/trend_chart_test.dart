import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/widgets/trend_chart.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: BrandTheme.lightTheme, home: Scaffold(body: child));

  testWidgets('a11y summary states every point as text, matching the fixture', (tester) async {
    await tester.pumpWidget(
      wrap(TrendChart(points: hba1cTrend, rangeCeiling: hba1cDefaultRangeCeiling)),
    );

    expect(
      find.bySemanticsLabel('HbA1c chart: Apr 2 6.2%, Jun 4 5.9%, Aug 6 5.7%, Oct 14 5.5%'),
      findsOneWidget,
    );
  });

  testWidgets('line colour stays chart.line even when every point is above range (no alarm colour)', (tester) async {
    final abovePoints = [
      HbA1cPoint(date: DateTime(2026, 4, 2), percent: 5.9),
      HbA1cPoint(date: DateTime(2026, 10, 14), percent: 6.1),
    ];
    await tester.pumpWidget(wrap(TrendChart(points: abovePoints, rangeCeiling: hba1cDefaultRangeCeiling)));

    final context = tester.element(find.byType(TrendChart));
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final barColor = lineChart.data.lineBarsData.single.color;

    expect(barColor, colors.chartLine);
    expect(barColor, isNot(colors.statusCritical));
    expect(barColor, isNot(colors.statusWarning));
  });
}
