// TC-039: every place the app opens a lab report's file goes through the
// signed-link helper (HealthDataRepository.signedLabReportUrl, TC-036):
// a fresh 5-minute link per open, made from the stored `pdf_path`, never
// stored, logged or shown; a failed hand-off (e.g. an expired link) gets one
// fresh link; refusal shows a fixed error. Identity-held reports never reach
// the list, so they can't be opened.
//
// The only UI that opens a report file is ReportDetailScreen's "Open report
// file" action, reached from My Lab Records. Real screens + real repository +
// real SupabaseClient on package:http's MockClient; the platform launcher is
// replaced. Fictional data only.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/models/lab_report.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/lab_reports_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/screens/health_data/my_lab_records_screen.dart';
import 'package:zyndio_patient/screens/health_data/report_detail_screen.dart';
import 'package:zyndio_patient/services/lab_report_file_opener.dart';

const _patientId = '00000000-0000-0000-0000-0000000a1001';
const _otherPatientId = '00000000-0000-0000-0000-0000000b2002';
const _ownPath = '$_patientId/36a00000-0000-4000-8000-000000000001.pdf';
const _otherPath = '$_otherPatientId/36a00000-0000-4000-8000-000000000002.pdf';
const _signPrefix = '/storage/v1/object/sign/lab-reports/';

class _FixedProfile extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async => PatientProfile(id: _patientId);
}

/// PostgREST + Storage as the real RLS answers them for [_patientId]: rows
/// are filtered as the query asks (held ones only come back if the query
/// forgets `identity_hold=eq.false`), and Storage signs only objects in the
/// caller's own folder.
class _Backend {
  _Backend({this.listFails = false});
  final bool listFails;
  final requests = <http.Request>[];
  var signed = 0;

  static Map<String, dynamic> _row(String id, String title,
          {String? pdfPath, bool held = false}) =>
      {
        'id': id,
        'report_type': 'patient_upload',
        'created_at': '2026-10-0${held ? 2 : 1}T08:00:00+00:00',
        'data': {'title': title, 'markers': []},
        'pdf_path': pdfPath,
        'identity_hold': held,
      };

  final rows = [
    _row('00000000-0000-0000-0000-0000000c0001', 'Fictional own report',
        pdfPath: _ownPath),
    _row('00000000-0000-0000-0000-0000000c0002', 'Fictional held report',
        pdfPath: '$_patientId/36a00000-0000-4000-8000-000000000003.pdf',
        held: true),
  ];

  late final MockClient mock = MockClient((r) async {
    requests.add(r);
    final path = r.url.path;
    if (path == '/rest/v1/lab_reports' && r.method == 'GET') {
      if (listFails) {
        return http.Response(
            json.encode(
                {'code': '42501', 'message': 'fictional backend error text'}),
            403,
            headers: {'content-type': 'application/json'},
            request: r);
      }
      final q = r.url.queryParameters;
      final out = rows
          .where((row) =>
              q['identity_hold'] != 'eq.false' || row['identity_hold'] == false)
          .map((row) => Map.of(row)..remove('identity_hold'))
          .toList();
      return http.Response(json.encode(out), 200,
          headers: {'content-type': 'application/json'}, request: r);
    }
    if (path.startsWith(_signPrefix) && r.method == 'POST') {
      final object = path.substring(_signPrefix.length);
      if (!object.startsWith('$_patientId/')) {
        return http.Response(
            json.encode({
              'statusCode': '404',
              'error': 'not_found',
              'message': 'Object not found'
            }),
            400,
            headers: {'content-type': 'application/json'},
            request: r);
      }
      signed++;
      return http.Response(
          json.encode({
            'signedURL':
                '/object/sign/lab-reports/$object?token=fictional-token-$signed'
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: r);
    }
    return http.Response('unexpected ${r.method} $path', 500, request: r);
  });

  List<http.Request> get signs =>
      requests.where((r) => r.url.path.startsWith(_signPrefix)).toList();
}

void main() {
  late List<Uri> launched;
  late List<bool> launchResults;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    launched = [];
    launchResults = [];
    LabReportFileOpener.launcher = (uri) async {
      launched.add(uri);
      return launchResults.isEmpty ? true : launchResults.removeAt(0);
    };
  });
  tearDown(() {
    LabReportFileOpener.resetForTest();
    SupabaseConfig.debugClientOverride = null;
  });

  Future<void> settle(WidgetTester tester, {int rounds = 20}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(
      WidgetTester tester, _Backend b, Widget screen) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() => http.runWithClient(() async {
          SupabaseConfig.debugClientOverride =
              SupabaseClient('https://example.test', 'fake-anon-key');
        }, () => b.mock));
    await tester.pumpWidget(ProviderScope(
      overrides: [patientProfileProvider.overrideWith(_FixedProfile.new)],
      child: MaterialApp(theme: BrandTheme.lightTheme, home: screen),
    ));
    await settle(tester);
  }

  Future<void> tapOpen(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('open-report-file')));
    await settle(tester);
  }

  LabReport report(String? pdfPath) => LabReport(
        id: '00000000-0000-0000-0000-0000000c0009',
        date: '2026-10-01',
        title: 'Fictional report',
        summary: 's',
        pdfPath: pdfPath,
        markers: const [],
      );

  testWidgets(
      'a patient opens their own report file: fresh 5-minute signed link, launched, not shown or printed',
      (tester) async {
    final b = _Backend();
    final printed = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? m, {int? wrapWidth}) => printed.add(m ?? '');
    try {
      await pumpScreen(tester, b, const MyLabRecordsScreen());
      expect(find.text('2026-10-01'), findsOneWidget);
      await tester.tap(find.text('2026-10-01'));
      await settle(tester);
      expect(find.byType(ReportDetailScreen), findsOneWidget);

      await tapOpen(tester);
      expect(b.signs, hasLength(1));
      expect(b.signs.single.url.path, '$_signPrefix$_ownPath');
      expect(json.decode(b.signs.single.body), {'expiresIn': 300});
      expect(launched, hasLength(1));
      expect(
          launched.single.toString(),
          startsWith(
              'https://example.test/storage/v1/object/sign/lab-reports/$_ownPath?token='));
      expect(find.textContaining('token='), findsNothing);
      expect(find.text(reportFileOpenFailedMessage), findsNothing);

      // Opening again makes a NEW link - nothing is cached.
      await tapOpen(tester);
      expect(b.signs, hasLength(2));
      expect(launched.map((u) => u.queryParameters['token']),
          ['fictional-token-1', 'fictional-token-2']);
    } finally {
      debugPrint = previousDebugPrint;
    }
    expect(printed.where((l) => l.contains('token') || l.contains(_ownPath)),
        isEmpty,
        reason: printed.join('\n'));
  });

  testWidgets(
      "a patient cannot open another patient's file: storage refuses, nothing launched, fixed error",
      (tester) async {
    final b = _Backend();
    await pumpScreen(tester, b, ReportDetailScreen(report: report(_otherPath)));
    await tapOpen(tester);
    expect(b.signs, isNotEmpty);
    expect(
        b.signs.every((r) => r.url.path == '$_signPrefix$_otherPath'), isTrue);
    expect(launched, isEmpty);
    expect(find.text(reportFileOpenFailedMessage), findsOneWidget);
    expect(find.textContaining('Object not found'), findsNothing);
  });

  testWidgets('a failed hand-off (expired link) gets exactly one fresh link',
      (tester) async {
    final b = _Backend();
    launchResults = [false, true];
    await pumpScreen(tester, b, ReportDetailScreen(report: report(_ownPath)));
    await tapOpen(tester);
    expect(b.signs, hasLength(2));
    expect(launched.map((u) => u.queryParameters['token']),
        ['fictional-token-1', 'fictional-token-2']);
    expect(find.text(reportFileOpenFailedMessage), findsNothing);
  });

  testWidgets(
      'if the fresh link fails too, a fixed error shows (no endless retry)',
      (tester) async {
    final b = _Backend();
    launchResults = [false, false, false];
    await pumpScreen(tester, b, ReportDetailScreen(report: report(_ownPath)));
    await tapOpen(tester);
    expect(b.signs, hasLength(LabReportFileOpener.maxAttempts));
    expect(find.text(reportFileOpenFailedMessage), findsOneWidget);
  });

  testWidgets('a report without a stored file has no open action',
      (tester) async {
    final b = _Backend();
    await pumpScreen(tester, b, ReportDetailScreen(report: report(null)));
    expect(find.byKey(const Key('open-report-file')), findsNothing);
    expect(b.signs, isEmpty);
  });

  testWidgets(
      'identity-held reports stay hidden: the list asks for identity_hold=eq.false and never shows them',
      (tester) async {
    final b = _Backend();
    await pumpScreen(tester, b, const MyLabRecordsScreen());
    final list =
        b.requests.where((r) => r.url.path == '/rest/v1/lab_reports').single;
    expect(list.url.queryParameters['identity_hold'], 'eq.false');
    expect(list.url.queryParameters['patient_id'], 'eq.$_patientId');
    expect(find.text('2026-10-01'), findsOneWidget);
    expect(find.text('2026-10-02'), findsNothing);
  });

  testWidgets('a failed list shows a fixed error, not the backend text',
      (tester) async {
    final b = _Backend(listFails: true);
    await pumpScreen(tester, b, const MyLabRecordsScreen());
    expect(find.text(labReportsLoadFailedMessage), findsOneWidget);
    expect(find.textContaining('fictional backend error text'), findsNothing);
  });
}
