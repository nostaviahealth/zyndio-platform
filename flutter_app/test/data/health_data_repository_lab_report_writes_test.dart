// TC-036: the patient app must file lab reports and manual biomarker entries
// with the REAL lab_reports columns, and must not print backend error text.
//
// Before TC-036, uploadLabReport inserted `profile_id`, `date`, `title`,
// `pdf_url`, `published`, `markers`, `summary`, `updated_at`, and
// saveManualBiomarker looked rows up by `profile_id`/`title`/`date` - none of
// those columns exist (real: id, org_id, patient_id, report_type, data,
// created_at, ... , pdf_path). PostgREST rejects that (400, PGRST204 /
// 42703), so no patient upload or manual entry was ever saved; the repository
// printed the error and returned false.
//
// These tests drive the real repository + real SupabaseClient through
// package:http's MockClient. The exact requests are pinned by
// tests/contracts/patient-lab-report-writes.json, which
// tests/integration/patient-lab-report-writes.test.ts replays against the
// migrated schema + RLS through real PostgREST. Fictional data only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/data/health_data_repository.dart';

const _patientId = '00000000-0000-0000-0000-0000000a1001';
const _orgId = '00000000-0000-0000-0000-00000000000a';
final _objectName = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

Map<String, dynamic> _contract() => json.decode(
      File('../tests/contracts/patient-lab-report-writes.json').readAsStringSync(),
    ) as Map<String, dynamic>;

/// Deep-replaces `{name}` placeholders in a decoded contract value.
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

http.Response _json(http.Request r, Object? body, [int status = 200]) => http.Response(
      json.encode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: r,
    );

/// What real PostgREST answers for the pre-TC-036 insert.
http.Response _missingColumn(http.Request r) => _json(r, {
      'code': 'PGRST204',
      'details': null,
      'hint': null,
      'message': "Could not find the 'date' column of 'lab_reports' in the schema cache",
    }, 400);

/// Routes a real SupabaseClient's requests. Defaults behave like a healthy
/// backend for a linked patient; [onInsert] decides the lab_reports insert.
class _Backend {
  _Backend({this.onInsert});
  final http.Response Function(http.Request)? onInsert;
  final requests = <http.Request>[];

  late final MockClient mock = MockClient((r) async {
    requests.add(r);
    final path = r.url.path;
    if (path == '/rest/v1/patients' && r.method == 'GET') {
      return _json(r, [
        {'org_id': _orgId}
      ]);
    }
    if (path == '/rest/v1/lab_reports' && r.method == 'POST') {
      return onInsert?.call(r) ?? http.Response('', 201, request: r);
    }
    if (path == '/rest/v1/lab_reports') return _missingColumn(r);
    if (path.startsWith('/storage/v1/object/lab-reports/') && r.method == 'POST') {
      return _json(r, {'Key': path.substring('/storage/v1/object/'.length)});
    }
    if (path == '/storage/v1/object/lab-reports' && r.method == 'DELETE') {
      return _json(r, []);
    }
    if (path.startsWith('/rest/v1/')) return http.Response('', 201, request: r);
    return http.Response('unexpected ${r.method} $path', 500, request: r);
  });

  List<http.Request> get labReportWrites => requests
      .where((r) => r.url.path == '/rest/v1/lab_reports' && r.method != 'GET')
      .toList();
  List<http.Request> get labReportReads => requests
      .where((r) => r.url.path == '/rest/v1/lab_reports' && r.method == 'GET')
      .toList();
  List<http.Request> get orgLookups =>
      requests.where((r) => r.url.path == '/rest/v1/patients').toList();
  List<http.Request> get uploads => requests
      .where((r) => r.url.path.startsWith('/storage/v1/object/lab-reports/') && r.method == 'POST')
      .toList();
}

/// Runs [body] with a real SupabaseClient on [b]'s MockClient installed as
/// SupabaseConfig.client, and collects everything printed.
Future<T> _run<T>(_Backend b, List<String> printed, Future<T> Function() body) =>
    runZoned(
      () => http.runWithClient(() async {
        SupabaseConfig.debugClientOverride =
            SupabaseClient('https://example.test', 'fake-anon-key');
        return body();
      }, () => b.mock),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printed.add(line),
      ),
    );

void _expectOrgLookup(_Backend b) {
  final c = _contract()['org_lookup'] as Map<String, dynamic>;
  expect(b.orgLookups, hasLength(1));
  final req = b.orgLookups.single;
  expect(req.method, c['method']);
  expect(req.url.path, c['path']);
  expect(req.url.queryParameters, _fill(c['query'], {'patient_id': _patientId}));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late File pdf;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tc036-');
    pdf = File('${tmp.path}/Fictional Lipid Panel (Oct).PDF')
      ..writeAsBytesSync(utf8.encode('%PDF-1.4 fictional'));
  });
  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
    tmp.deleteSync(recursive: true);
  });

  Map<String, dynamic> extracted() {
    final data = (_contract()['upload_insert'] as Map<String, dynamic>)['body']['data'] as Map<String, dynamic>;
    return json.decode(json.encode(data)) as Map<String, dynamic>;
  }

  group('HealthDataRepository.uploadLabReport (TC-036)', () {
    test('files the report with exactly the pinned real-column insert', () async {
      final b = _Backend();
      final printed = <String>[];
      final ok = await _run(b, printed, () => HealthDataRepository.uploadLabReport(
            filePath: pdf.path,
            fileName: 'Fictional Lipid Panel (Oct).PDF',
            profileId: _patientId,
            extractedData: extracted(),
          ));

      expect(ok, isTrue);
      _expectOrgLookup(b);
      expect(b.uploads, hasLength(1));
      final objectPath = b.uploads.single.url.path.substring('/storage/v1/object/lab-reports/'.length);
      final parts = objectPath.split('/');
      expect(parts, hasLength(2));
      expect(parts[0], _patientId);
      expect(parts[1], endsWith('.pdf'));
      final objectId = parts[1].substring(0, parts[1].length - '.pdf'.length);
      expect(objectId, matches(_objectName), reason: 'object is named by a fresh uuid, not the user file name');

      final c = _contract()['upload_insert'] as Map<String, dynamic>;
      expect(b.labReportWrites, hasLength(1));
      final insert = b.labReportWrites.single;
      expect(insert.method, c['method']);
      expect(insert.url.path, c['path']);
      expect(json.decode(insert.body),
          _fill(c['body'], {'patient_id': _patientId, 'org_id': _orgId, 'object': objectId}));
      expect(printed, isEmpty);
    });

    test('never names a non-existent column and never stores a URL', () async {
      final b = _Backend();
      await _run(b, [], () => HealthDataRepository.uploadLabReport(
            filePath: pdf.path,
            fileName: 'x.pdf',
            profileId: _patientId,
            extractedData: extracted(),
          ));
      final body = json.decode(b.labReportWrites.single.body) as Map<String, dynamic>;
      for (final gone in ['profile_id', 'date', 'title', 'pdf_url', 'published', 'markers', 'summary', 'updated_at']) {
        expect(body.containsKey(gone), isFalse, reason: '$gone is not a lab_reports column');
      }
      expect(b.labReportWrites.single.body, isNot(contains('http')));
      expect(b.requests.map((r) => r.url.path), isNot(contains(contains('/object/public/'))));
    });

    test('a rejected insert returns false and prints nothing', () async {
      final b = _Backend(onInsert: _missingColumn);
      final printed = <String>[];
      final ok = await _run(b, printed, () => HealthDataRepository.uploadLabReport(
            filePath: pdf.path,
            fileName: 'x.pdf',
            profileId: _patientId,
            extractedData: extracted(),
          ));
      expect(ok, isFalse);
      expect(printed, isEmpty, reason: 'backend error text must not reach device logs');
    });
  });

  group('HealthDataRepository.saveManualBiomarker (TC-036)', () {
    test('files a new one-marker manual_entry report with exactly the pinned insert', () async {
      final b = _Backend();
      final printed = <String>[];
      final ok = await _run(b, printed, () => HealthDataRepository.saveManualBiomarker(
            profileId: _patientId,
            markerName: 'Vitamin D',
            value: '32',
            unit: 'ng/mL',
          ));

      expect(ok, isTrue);
      _expectOrgLookup(b);
      expect(b.labReportReads, isEmpty, reason: 'no lookup by non-existent columns');
      final c = _contract()['manual_entry_insert'] as Map<String, dynamic>;
      expect(b.labReportWrites, hasLength(1));
      final insert = b.labReportWrites.single;
      expect(insert.method, c['method'], reason: 'patients cannot UPDATE lab_reports (RLS), so never PATCH');
      expect(insert.url.path, c['path']);
      expect(json.decode(insert.body),
          _fill(c['body'], {'patient_id': _patientId, 'org_id': _orgId, 'today': _today()}));
      expect(printed, isEmpty);
    });

    test('a rejected insert returns false and prints nothing', () async {
      final b = _Backend(onInsert: (r) => _json(r, {
            'code': '42501',
            'details': null,
            'hint': null,
            'message': 'new row violates row-level security policy for table "lab_reports"',
          }, 403));
      final printed = <String>[];
      final ok = await _run(b, printed, () => HealthDataRepository.saveManualBiomarker(
            profileId: _patientId,
            markerName: 'Vitamin D',
            value: '32',
            unit: 'ng/mL',
          ));
      expect(ok, isFalse);
      expect(printed, isEmpty);
    });
  });
}
