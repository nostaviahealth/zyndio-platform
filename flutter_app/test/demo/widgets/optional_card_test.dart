import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/optional_card.dart';

void main() {
  testWidgets('OptionalCard renders its copy and toggles on tap anywhere in the card', (tester) async {
    var value = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: Scaffold(
          body: OptionalCard(
            title: 'Share progress with my body composition partner',
            subtitle: 'Only results your Zyndio clinician has reviewed.',
            value: value,
            onChanged: (v) => value = v,
          ),
        ),
      ),
    );

    expect(find.text('Share progress with my body composition partner'), findsOneWidget);
    expect(find.text('Only results your Zyndio clinician has reviewed.'), findsOneWidget);

    await tester.tap(find.text('Share progress with my body composition partner'));
    expect(value, isTrue);
  });
}
