import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/fictional_data_tag.dart';

void main() {
  testWidgets('FictionalDataTag renders the FICTIONAL DATA label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: const Scaffold(body: FictionalDataTag())),
    );

    expect(find.text('FICTIONAL DATA'), findsOneWidget);
  });
}
