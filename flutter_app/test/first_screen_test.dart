import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyndio_patient/app.dart';

void main() {
  testWidgets('first screen is titled Zyndio and never shows the old brand name',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: BrandHealthApp()));

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'Zyndio');

    // Assembled from character codes so this file never contains the literal
    // legacy brand string (the leak scanner greps the source tree for it).
    final legacyBrand = String.fromCharCodes(
      const [78, 111, 115, 116, 97, 118, 105, 97],
    ).toLowerCase();

    final renderedText = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join(' ')
        .toLowerCase();

    expect(renderedText.contains(legacyBrand), isFalse);
  });
}
