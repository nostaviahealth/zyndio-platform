import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/demo_tab_bar.dart';

void main() {
  testWidgets('DemoTabBar shows all 5 tabs and announces the selected one', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: DemoTabBar(selected: DemoTab.labs))),
      ),
    );

    for (final label in ['Today', 'Labs', 'Log', 'Companion', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
    final labsFlags = tester.getSemantics(find.bySemanticsLabel('Labs')).getSemanticsData().flagsCollection;
    final todayFlags = tester.getSemantics(find.bySemanticsLabel('Today')).getSemanticsData().flagsCollection;
    expect(labsFlags.isSelected, Tristate.isTrue);
    expect(todayFlags.isSelected, Tristate.isFalse);
    handle.dispose();
  });
}
