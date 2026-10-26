import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/widgets/skeleton.dart';

void main() {
  testWidgets('Skeleton renders at the requested size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: BrandTheme.lightTheme,
        home: const Scaffold(body: Skeleton(width: 120, height: 14)),
      ),
    );

    final size = tester.getSize(find.byType(Skeleton));
    expect(size.width, 120);
    expect(size.height, 14);
  });
}
