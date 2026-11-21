// Client walkthrough (19 Nov 2026): upload stays the main way in, and a photo
// of a printed report is offered as well (APP-05 camera). Fictional data.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/providers/lab_analysis_provider.dart';
import 'package:zyndio_patient/screens/health_data/lab_report_upload_screen.dart';

class _IdleAnalysis extends LabAnalysisNotifier {
  @override
  LabAnalysisState build() => const LabAnalysisState();
}

// The upload screen's pulse animation repeats forever, so step time
// instead of pumpAndSettle.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(() => labPhotoCapture = labPhotoCaptureDefault);

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [labAnalysisProvider.overrideWith(() => _IdleAnalysis())],
      child: MaterialApp(
          theme: BrandTheme.lightTheme, home: const LabReportUploadScreen()),
    ));
    await settle(tester);
  }

  testWidgets('a photo of the report is selected like an upload',
      (tester) async {
    labPhotoCapture = () async => PlatformFile(
        path: '/tmp/fictional-report.jpg', name: 'fictional-report.jpg', size: 1024);
    await pump(tester);
    expect(find.text('Select Report'), findsOneWidget);
    await tester.tap(find.text('Take a photo instead'));
    await settle(tester);
    expect(find.text('Report Selected'), findsOneWidget);
    expect(find.text('fictional-report.jpg'), findsOneWidget);
  });

  testWidgets('cancelling the camera keeps the upload choice open',
      (tester) async {
    labPhotoCapture = () async => null;
    await pump(tester);
    await tester.tap(find.text('Take a photo instead'));
    await settle(tester);
    expect(find.text('Select Report'), findsOneWidget);
  });

  testWidgets('a camera that fails says so and points to upload',
      (tester) async {
    labPhotoCapture = () async => throw Exception('camera denied');
    await pump(tester);
    await tester.tap(find.text('Take a photo instead'));
    await tester.pump();
    expect(find.textContaining("Couldn't open the camera"), findsOneWidget);
  });
}
