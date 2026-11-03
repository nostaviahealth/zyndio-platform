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

    // TC-025 A5: the companion is renamed "Zyndio AI" everywhere; the old
    // "Companion" label must no longer appear.
    for (final label in ['Today', 'Labs', 'Log', 'Zyndio AI', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Companion'), findsNothing);
    final labsFlags = tester.getSemantics(find.bySemanticsLabel('Labs')).getSemanticsData().flagsCollection;
    final todayFlags = tester.getSemantics(find.bySemanticsLabel('Today')).getSemanticsData().flagsCollection;
    expect(labsFlags.isSelected, Tristate.isTrue);
    expect(todayFlags.isSelected, Tristate.isFalse);
    handle.dispose();
  });
}
