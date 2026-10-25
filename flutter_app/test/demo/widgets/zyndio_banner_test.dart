import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/zyndio_banner.dart';

void main() {
  testWidgets('ZyndioBanner renders its message and icon for every variant', (tester) async {
    for (final variant in BannerVariant.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: BrandTheme.lightTheme,
          home: Scaffold(body: ZyndioBanner(variant: variant, message: 'Test message')),
        ),
      );

      expect(find.text('Test message'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    }
  });
}
