// Client walkthrough (19 Nov 2026): a DEXA booking link for patients without
// a scan (zyndio.com/dexascan) and one card for the merchandise store
// (zyndio.com/store). Fictional data only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/data/body_composition.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/body_composition_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/screens/care/care_screen.dart';
import 'package:zyndio_patient/screens/progress/progress_screen.dart';
import 'package:zyndio_patient/services/zyndio_links.dart';

class _Profile extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async =>
      PatientProfile(id: 'p1', name: 'Jordan Rivera', subscriptionPlan: 'free');
}

void main() {
  late List<Uri> opened;

  setUp(() {
    opened = [];
    zyndioUrlOpener = (url) async {
      opened.add(url);
      return true;
    };
  });
  tearDown(resetZyndioUrlOpener);

  Future<void> pump(WidgetTester tester, Widget screen,
      {List<StoredBodyScan> scans = const []}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        patientProfileProvider.overrideWith(() => _Profile()),
        bodyCompositionScansProvider.overrideWith((ref) async => scans),
      ],
      child: MaterialApp(theme: BrandTheme.lightTheme, home: screen),
    ));
    await tester.pumpAndSettle();
  }

  // The page's vertical list (Progress also has a sideways segment row).
  final pageScroll = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down);

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 200,
        scrollable: pageScroll.first);
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pump();
  }

  test('the new links point at zyndio.com over https', () {
    expect(ZyndioLinks.dexaScan, Uri.parse('https://www.zyndio.com/dexascan'));
    expect(ZyndioLinks.store, Uri.parse('https://www.zyndio.com/store'));
  });

  testWidgets('Progress with no scan offers to book one on zyndio.com',
      (tester) async {
    await pump(tester, const ProgressScreen());
    expect(find.text('No DEXASCAN results yet'), findsOneWidget);
    await tapText(tester, 'Book a DEXASCAN');
    expect(opened, [ZyndioLinks.dexaScan]);
  });

  testWidgets('Progress with a scan still links to the next booking',
      (tester) async {
    await pump(tester, const ProgressScreen(), scans: const [
      StoredBodyScan(
        scanDate: '2026-10-02',
        deviceVendor: 'Fictional Vendor',
        deviceModel: 'Model X',
        softwareVersion: '1.0',
        measures: [(name: 'body_fat_pct', value: '27.1')],
      ),
    ]);
    await tapText(tester, 'Book a DEXASCAN');
    expect(opened, [ZyndioLinks.dexaScan]);
  });

  testWidgets('Care has a Zyndio Store card that opens zyndio.com/store',
      (tester) async {
    await pump(tester, const CareScreen());
    expect(
        find.text('Apparel, hoodies, mugs and calendars at zyndio.com/store.'),
        findsOneWidget);
    await tapText(tester, 'Zyndio Store');
    expect(opened, [ZyndioLinks.store]);
  });
}
