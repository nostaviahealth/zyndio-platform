import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/identity_line.dart';

void main() {
  testWidgets('IdentityLine renders its message with the success check icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: const Scaffold(body: IdentityLine(message: 'Name and date of birth match your account')),
      ),
    );

    expect(find.text('Name and date of birth match your account'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
  });
}
