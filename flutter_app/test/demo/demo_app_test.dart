import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/demo_app.dart';

void main() {
  testWidgets('DemoApp with no deep-link opens the real sign-in entry, not the placeholder', (tester) async {
    // TC-029 (BUG-2): on a native build Uri.base carries no query string, so
    // DemoApp() resolves to no screen/flow. It used to fall through to the
    // "coming soon" placeholder; it now opens the real app entry (sign-in).
    // See demo_app_entry_test.dart for the full web-vs-native routing matrix.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: DemoApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.textContaining('coming soon'), findsNothing);
    expect(find.text('Sign in to your care program'), findsOneWidget);
  });

  testWidgets('kDemoBuild defaults to false', (tester) async {
    expect(kDemoBuild, isFalse);
  });
}
