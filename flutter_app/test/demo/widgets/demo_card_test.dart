import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/demo_card.dart';

void main() {
  testWidgets('DemoCard renders its child and has a shadow in light mode only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.lightTheme, home: const Scaffold(body: DemoCard(child: Text('Card body')))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Card body'), findsOneWidget);
    final lightContainerFinder = find.descendant(of: find.byType(DemoCard), matching: find.byType(Container));
    final lightDecoration = tester.widget<Container>(lightContainerFinder).decoration as BoxDecoration;
    expect(lightDecoration.boxShadow, isNotEmpty);

    await tester.pumpWidget(
      MaterialApp(theme: BrandTheme.darkTheme, home: const Scaffold(body: DemoCard(child: Text('Card body')))),
    );
    await tester.pumpAndSettle();
    final darkContainerFinder = find.descendant(of: find.byType(DemoCard), matching: find.byType(Container));
    final darkDecoration = tester.widget<Container>(darkContainerFinder).decoration as BoxDecoration;
    expect(darkDecoration.boxShadow, isEmpty);
  });
}
