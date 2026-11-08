// Progress shows a bound DEXA scan in report-style sections with units.
// Fictional values only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/data/body_composition.dart';
import 'package:zyndio_patient/providers/body_composition_provider.dart';
import 'package:zyndio_patient/screens/progress/progress_screen.dart';

void main() {
  testWidgets('a scan renders grouped sections with units, raw keys hidden', (tester) async {
    const scan = StoredBodyScan(
      scanDate: '2026-10-02',
      deviceVendor: 'Fictional Vendor',
      deviceModel: 'Model X',
      softwareVersion: '1.0',
      measures: [
        (name: 'health_score', value: '81'),
        (name: 'body_fat_pct', value: '27.1'),
        (name: 'almi_kg_m2', value: '6.10'),
        (name: 'bone_t_score', value: '-0.9'),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [bodyCompositionScansProvider.overrideWith((ref) async => [scan])],
      child: MaterialApp(theme: BrandTheme.lightTheme, home: const ProgressScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('DEXA scan · 2026-10-02'), findsOneWidget);
    expect(find.text('OVERVIEW'), findsOneWidget);
    expect(find.text('MUSCLE'), findsOneWidget);
    expect(find.text('BONE'), findsOneWidget);
    expect(find.text('81/100'), findsOneWidget);
    expect(find.text('27.1%'), findsOneWidget);
    expect(find.text('6.10 kg/m²'), findsOneWidget);
    expect(find.textContaining('body_fat_pct'), findsNothing);
  });
}
