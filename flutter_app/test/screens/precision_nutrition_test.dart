import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/data/precision_nutrition.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/screens/supplements/precision_nutrition_screen.dart';
import 'package:zyndio_patient/services/zyndio_links.dart';
import 'package:zyndio_patient/widgets/tc025/tc025_widgets.dart';

class _TestProfileNotifier extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async =>
      PatientProfile(id: 'p1', name: 'Jordan Rivera', subscriptionPlan: 'free');
}

void main() {
  late List<Uri> opened;
  late bool openResult;

  setUp(() {
    opened = [];
    openResult = true;
    zyndioUrlOpener = (url) async {
      opened.add(url);
      return openResult;
    };
  });
  tearDown(resetZyndioUrlOpener);

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        patientProfileProvider.overrideWith(() => _TestProfileNotifier()),
      ],
      child: MaterialApp(theme: BrandTheme.lightTheme, home: child),
    ));
    await tester.pumpAndSettle();
  }

  group('Precision Nutrition catalogue', () {
    test('has the eight zyndio.com products with unique ids and pages', () {
      expect(precisionNutritionProducts, hasLength(8));
      expect(precisionNutritionProducts.map((p) => p.id).toSet(), hasLength(8));
      for (final p in precisionNutritionProducts) {
        expect(p.url.host, 'www.zyndio.com');
        expect(p.url.scheme, 'https');
        expect(p.priceUsd, greaterThan(0));
      }
      expect(precisionNutritionProducts.where((p) => p.isTest), hasLength(1));
    });
  });

  group('PrecisionNutritionScreen', () {
    testWidgets('lists every product and the FDA disclaimer', (tester) async {
      await pump(tester, const PrecisionNutritionScreen());
      for (final p in precisionNutritionProducts) {
        await tester.scrollUntilVisible(find.text(p.name), 200);
        expect(find.text(p.name), findsOneWidget);
      }
      await tester.scrollUntilVisible(
          find.text(precisionNutritionDisclaimer), 200);
      expect(find.text(precisionNutritionDisclaimer), findsOneWidget);
    });

    testWidgets('buying opens that product page on zyndio.com', (tester) async {
      await pump(tester, const PrecisionNutritionScreen());
      final mito =
          precisionNutritionProducts.firstWhere((p) => p.id == 'mitoaid');
      await tester.scrollUntilVisible(find.text(mito.name), 200);
      await tester.tap(find.text(mito.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buy on zyndio.com · \$56.00'));
      await tester.pumpAndSettle();
      expect(opened, [Uri.parse('https://www.zyndio.com/mitoaid')]);
    });

    testWidgets('a link that fails to open says so', (tester) async {
      openResult = false;
      await pump(tester, const PrecisionNutritionScreen());
      final visit = find.text('Visit zyndio.com/supplements');
      await tester.scrollUntilVisible(visit, 200);
      await tester.ensureVisible(visit);
      await tester.pumpAndSettle();
      await tester.tap(visit);
      await tester.pump();
      expect(opened, [ZyndioLinks.supplements]);
      expect(find.textContaining("Couldn't open www.zyndio.com"), findsOneWidget);
    });
  });

  group('Header links', () {
    testWidgets('Z opens zyndio.com and the shield opens the patient portal',
        (tester) async {
      await pump(
          tester,
          const Scaffold(
              body: Padding(
                  padding: EdgeInsets.all(20), child: ZyndioBrandRow())));
      await tester.tap(find.bySemanticsLabel('Open zyndio.com'));
      await tester.tap(find.bySemanticsLabel('Open patient portal'));
      await tester.pump();
      expect(opened, [
        Uri.parse('https://www.zyndio.com'),
        Uri.parse('https://member.zyndio.com'),
      ]);
    });
  });
}
