import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/demo_app.dart';

void main() {
  testWidgets('DemoApp builds with the placeholder body', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DemoApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('coming soon'), findsOneWidget);
  });

  testWidgets('kDemoBuild defaults to false', (tester) async {
    expect(kDemoBuild, isFalse);
  });
}
