import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/badge.dart';

void main() {
  testWidgets('ZyndioBadge renders its label for every variant', (tester) async {
    for (final variant in BadgeVariant.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: BrandTheme.lightTheme,
          home: Scaffold(body: ZyndioBadge(label: 'Needs review', variant: variant)),
        ),
      );

      expect(find.text('Needs review'), findsOneWidget);
    }
  });
}
