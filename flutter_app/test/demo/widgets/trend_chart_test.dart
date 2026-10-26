import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/widgets/trend_chart.dart';

void main() {
  Widget wrap(Widget child) =>
      MaterialApp(theme: BrandTheme.lightTheme, home: Scaffold(body: child));

  testWidgets('a11y summary states every point as text, matching the fixture',
      (tester) async {
    await tester.pumpWidget(
      wrap(TrendChart(
          points: hba1cTrend, rangeCeiling: hba1cDefaultRangeCeiling)),
    );

    expect(
      find.bySemanticsLabel(
          'HbA1c chart: Apr 2 6.2%, Jun 4 5.9%, Aug 6 5.7%, Oct 14 5.5%'),
      findsOneWidget,
    );
  });

  testWidgets(
      'line colour stays chart.line even when every point is above range (no alarm colour)',
      (tester) async {
    final abovePoints = [
      HbA1cPoint(date: DateTime(2026, 4, 2), percent: 5.9),
      HbA1cPoint(date: DateTime(2026, 10, 14), percent: 6.1),
    ];
    await tester.pumpWidget(wrap(TrendChart(
        points: abovePoints, rangeCeiling: hba1cDefaultRangeCeiling)));

    final context = tester.element(find.byType(TrendChart));
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final lineChart = tester.widget<LineChart>(find.byType(LineChart));
    final barColor = lineChart.data.lineBarsData.single.color;

    expect(barColor, colors.chartLine);
    expect(barColor, isNot(colors.statusCritical));
    expect(barColor, isNot(colors.statusWarning));
  });

  testWidgets('lab-trends x-axis: one label per data point', (tester) async {
    await tester.pumpWidget(
      wrap(TrendChart(
          points: hba1cTrend, rangeCeiling: hba1cDefaultRangeCeiling)),
    );

    final expectedLabels = [
      for (final p in hba1cTrend) DateFormat('MMM d').format(p.date)
    ];
    expect(expectedLabels.toSet().length, hba1cTrend.length,
        reason:
            'fixture dates must be distinct for this test to be meaningful');

    for (final label in expectedLabels) {
      expect(find.text(label), findsOneWidget,
          reason: '"$label" must appear exactly once on the x-axis');
    }

    // Matches only x-axis date labels ("Apr 2"); y-axis labels are numeric.
    final xAxisLabelPattern = RegExp(r'^[A-Z][a-z]{2} \d{1,2}$');
    expect(find.textContaining(xAxisLabelPattern),
        findsNWidgets(hba1cTrend.length));
  });

  testWidgets(
      'lab-trends chart: last x-axis label sits inside the chart bounds (no right- or bottom-edge clipping)',
      (tester) async {
    await tester.pumpWidget(
      wrap(TrendChart(
          points: hba1cTrend, rangeCeiling: hba1cDefaultRangeCeiling)),
    );

    final chartRect = tester.getRect(find.byType(TrendChart));
    final lastLabel = DateFormat('MMM d').format(hba1cTrend.last.date);
    final labelRect = tester.getRect(find.text(lastLabel));

    expect(labelRect.right, lessThanOrEqualTo(chartRect.right));
    expect(chartRect.right - labelRect.right, greaterThanOrEqualTo(8));
    expect(labelRect.bottom, lessThanOrEqualTo(chartRect.bottom));
  });
}
