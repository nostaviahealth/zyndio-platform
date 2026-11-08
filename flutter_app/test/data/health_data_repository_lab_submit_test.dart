// APP-05: HealthDataRepository.submitLabReport - the patient app's one lab
// path. Files the report (SHA-256 dedupe, private upload, real columns) and
// asks the server (analyze-lab-report) to read it; nothing is extracted on
// the device. The exact requests are pinned by
// tests/contracts/patient-lab-report-submit.json. Real SupabaseClient on
// package:http's MockClient. Fictional data only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/data/health_data_repository.dart';
import 'package:zyndio_patient/data/lab_submission.dart';

const _patientId = '00000000-0000-0000-0000-0000000a1001';
const _orgId = '00000000-0000-0000-0000-00000000000a';
const _reportId = '00000000-0000-0000-0000-00000051a301';
const _errorText = 'fictional upstream failure: relation "internal_secret" does not exist';
final _objectName = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

Map<String, dynamic> _contract() => json.decode(
      File('../tests/contracts/patient-lab-report-submit.json').readAsStringSync(),
    ) as Map<String, dynamic>;

Object? _fill(Object? v, Map<String, String> values) {
  if (v is String) {
    var out = v;
    values.forEach((k, val) => out = out.replaceAll('{$k}', val));
    return out;
  }
  if (v is Map) return v.map((k, e) => MapEntry(k as String, _fill(e, values)));
  if (v is List) return v.map((e) => _fill(e, values)).toList();
  return v;
}

String _today() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

http.Response _json(http.Request r, Object? body, [int status = 200]) =>
    http.Response(json.encode(body), status, headers: {'content-type': 'application/json'}, request: r);

class _Backend {
  _Backend({
    this.existing = const [],
    this.insertStatus = 201,
    this.analyzeStatus = 200,
    this.analyzeBody,
  });
  final List<Map<String, dynamic>> existing;
  final int insertStatus;
  final int analyzeStatus;
  final Object? analyzeBody;
  final requests = <http.Request>[];

  late final MockClient mock = MockClient((r) async {
    requests.add(r);
    final path = r.url.path;
    if (path == '/rest/v1/lab_reports' && r.method == 'GET') return _json(r, existing);
    if (path == '/rest/v1/patients') {
      return _json(r, [
        {'org_id': _orgId}
      ]);
    }
    if (path == '/rest/v1/lab_reports' && r.method == 'POST') {
      if (insertStatus == 409) {
        return _json(r, {'code': '23505', 'message': _errorText, 'details': null, 'hint': null}, 409);
      }
      if (insertStatus != 201) return _json(r, {'code': '42501', 'message': _errorText}, insertStatus);
      return _json(r, [
        {'id': _reportId}
      ], 201);
    }
    if (path.startsWith('/storage/v1/object/lab-reports/') && r.method == 'POST') {
      return _json(r, {'Key': path.substring('/storage/v1/object/'.length)});
    }
    if (path == '/storage/v1/object/lab-reports' && r.method == 'DELETE') return _json(r, []);
    if (path == '/functions/v1/analyze-lab-report') {
      return _json(r, analyzeBody ?? {'error': _errorText}, analyzeStatus);
    }
    if (path.startsWith('/rest/v1/')) return http.Response('', 201, request: r);
    return http.Response('unexpected ${r.method} $path', 500, request: r);
  });

  // The functions client sends its method in lower case ("post").
  Iterable<http.Request> where(String method, String path) =>
      requests.where((r) => r.method.toUpperCase() == method && r.url.path == path);
  List<http.Request> get uploads =>
      requests.where((r) => r.method == 'POST' && r.url.path.startsWith('/storage/v1/object/lab-reports/')).toList();
  List<http.Request> get removals =>
      requests.where((r) => r.method == 'DELETE' && r.url.path == '/storage/v1/object/lab-reports').toList();
}

Future<T> _run<T>(_Backend b, List<String> printed, Future<T> Function() body) => runZoned(
      () => http.runWithClient(() async {
        SupabaseConfig.debugClientOverride = SupabaseClient('https://example.test', 'fake-anon-key');
        return body();
      }, () => b.mock),
      zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => printed.add(line)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late File pdf;
  late String hash;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('app05-');
    // The golden fixture: a fictional report.
    final bytes = File('../tests/fixtures/labs/jordan-rivera-2026-10-14-us.pdf').readAsBytesSync();
    pdf = File('${tmp.path}/Jordan Rivera labs Oct.pdf')..writeAsBytesSync(bytes);
    hash = sha256.convert(bytes).toString();
  });
  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
    tmp.deleteSync(recursive: true);
  });

  Future<LabSubmission> submit(_Backend b, List<String> printed, {void Function()? onUploaded}) => _run(
      b,
      printed,
      () => HealthDataRepository.submitLabReport(
            filePath: pdf.path,
            fileName: 'Jordan Rivera labs Oct.pdf',
            profileId: _patientId,
            onUploaded: onUploaded,
          ));

  test('fileSha256 is the lower-case hex SHA-256 of the bytes', () async {
    expect(await HealthDataRepository.fileSha256(pdf), hash);
    expect(hash, matches(RegExp(r'^[0-9a-f]{64}$')));
  });

  test('files the report with its hash, then asks the server to read it (contract)', () async {
    final b = _Backend(analyzeBody: {
      'status': 'analyzed',
      'extraction_status': 'extracted',
      'identity_hold': false,
      'results': 1,
      'needs_review': 0,
      'markers': [
        {'name': 'HbA1c', 'value': '5.5', 'unit': '%', 'range': '<5.7', 'status': 'Normal', 'needs_review': false}
      ],
    });
    final printed = <String>[];
    var uploaded = false;
    final s = await submit(b, printed, onUploaded: () => uploaded = true);
    expect(s.outcome, LabSubmissionOutcome.analyzed);
    expect(s.reportId, _reportId);
    expect(s.markers.single.name, 'HbA1c');
    expect(uploaded, isTrue);

    final c = _contract();
    final lookup = b.where('GET', '/rest/v1/lab_reports').single;
    expect(lookup.url.queryParameters, _fill(c['dedupe_lookup']['query'], {'patient_id': _patientId, 'sha256': hash}));

    final upload = b.uploads.single;
    final object = upload.url.path.split('/').last.replaceAll('.pdf', '');
    expect(object, matches(_objectName));

    final insert = b.where('POST', '/rest/v1/lab_reports').single;
    expect(insert.url.queryParameters, c['submit_insert']['query']);
    expect(json.decode(insert.body), _fill(c['submit_insert']['body'],
        {'patient_id': _patientId, 'org_id': _orgId, 'object': object, 'sha256': hash, 'today': _today()}));

    final analyze = b.where('POST', c['analyze_call']['path'] as String).single;
    expect(json.decode(analyze.body), _fill(c['analyze_call']['body'], {'report_id': _reportId}));

    // The user's file name (which names the patient) is never sent.
    for (final r in b.requests) {
      expect(r.url.toString(), isNot(contains('Jordan')));
      if (r.method != 'GET' && !r.url.path.startsWith('/storage/')) expect(r.body, isNot(contains('Jordan')));
    }
    expect(printed, isEmpty);
  });

  test('the same file again: nothing uploaded or inserted -> duplicate', () async {
    final b = _Backend(existing: [
      {'id': _reportId, 'extraction_status': 'extracted'}
    ]);
    final s = await submit(b, []);
    expect(s.outcome, LabSubmissionOutcome.duplicate);
    expect(s.saved, isFalse);
    expect(b.uploads, isEmpty);
    expect(b.where('POST', '/rest/v1/lab_reports'), isEmpty);
    expect(b.where('POST', '/functions/v1/analyze-lab-report'), isEmpty);
  });

  test('the same file, filed but never read (app killed): read it now, no new upload', () async {
    final b = _Backend(existing: [
      {'id': _reportId, 'extraction_status': 'pending'}
    ], analyzeStatus: 501, analyzeBody: {'error': 'analysis_unavailable'});
    final s = await submit(b, []);
    expect(s.outcome, LabSubmissionOutcome.awaitingReview);
    expect(b.uploads, isEmpty);
    expect(json.decode(b.where('POST', '/functions/v1/analyze-lab-report').single.body), {'report_id': _reportId});
  });

  test('a duplicate caught by the unique index (race): upload removed, duplicate, nothing printed', () async {
    final b = _Backend(insertStatus: 409);
    final printed = <String>[];
    final s = await submit(b, printed);
    expect(s.outcome, LabSubmissionOutcome.duplicate);
    expect(b.removals, hasLength(1));
    expect(b.where('POST', '/functions/v1/analyze-lab-report'), isEmpty);
    expect(printed, isEmpty);
  });

  test('insert refused: upload removed, fixed error thrown, no backend text, nothing printed', () async {
    final b = _Backend(insertStatus: 403);
    final printed = <String>[];
    Object? error;
    try {
      await submit(b, printed);
    } catch (e) {
      error = e;
    }
    expect(error, isA<StateError>());
    expect(error.toString(), isNot(contains('internal_secret')));
    expect(b.removals, hasLength(1));
    expect(printed, isEmpty);
  });

  final cases = <int, LabSubmissionOutcome>{
    501: LabSubmissionOutcome.awaitingReview,
    429: LabSubmissionOutcome.rateLimited,
    502: LabSubmissionOutcome.analysisFailed,
    500: LabSubmissionOutcome.analysisFailed,
  };
  cases.forEach((status, outcome) {
    test('server answers $status: report stays filed -> $outcome, nothing printed', () async {
      final b = _Backend(analyzeStatus: status);
      final printed = <String>[];
      final s = await submit(b, printed);
      expect(s.outcome, outcome);
      expect(s.saved, isTrue);
      expect(s.reportId, _reportId);
      expect(s.message, isNot(contains('internal_secret')));
      expect(b.removals, isEmpty);
      expect(printed, isEmpty);
    });
  });

  test('identity hold: the patient is told, no values come back', () async {
    final b = _Backend(analyzeBody: {
      'status': 'analyzed',
      'extraction_status': 'identity_hold',
      'identity_hold': true,
      'results': 7,
      'needs_review': 0,
      'message': 'server text is not shown',
    });
    final s = await submit(b, []);
    expect(s.outcome, LabSubmissionOutcome.identityHold);
    expect(s.markers, isEmpty);
    expect(s.message, contains("doesn't match your account"));
  });
}
