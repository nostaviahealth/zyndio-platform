import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/badge.dart';
import 'package:zyndio_patient/demo/widgets/metric_header.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(theme: BrandTheme.lightTheme, home: Scaffold(body: child));

  testWidgets('renders value, unit, badge and meta line', (tester) async {
    await tester.pumpWidget(
      wrap(
        const MetricHeader(
          value: '5.5',
          unit: '%',
          badgeLabel: 'Within default range',
          badgeVariant: BadgeVariant.brand,
          meta: 'Oct 14, 2026 · −0.7 points since baseline (Apr 2)',
        ),
      ),
    );

    expect(find.text('5.5'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);
    expect(find.text('Within default range'), findsOneWidget);
    expect(find.text('Oct 14, 2026 · −0.7 points since baseline (Apr 2)'), findsOneWidget);
  });
}
