import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/info_card.dart';

void main() {
  testWidgets('InfoCard renders its message with the info icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: const Scaffold(body: InfoCard(message: 'Helpful info'))),
    );

    expect(find.text('Helpful info'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });
}
