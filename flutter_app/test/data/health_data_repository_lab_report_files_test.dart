// TC-036: lab-report FILES are private. The app stores only the object path
// (lab_reports.pdf_path), opens a file through a short-lived signed link made
// at the moment it is opened, and never leaves an unfiled upload behind.
//
// - Signed link: POST /storage/v1/object/sign/lab-reports/<path> with a
//   5-minute lifetime (TC-036 caps it at 10). Storage checks the caller's RLS
//   on the object before signing (supabase/tests/744_*.sql).
// - Orphan cleanup: if filing the lab_reports row fails after the upload
//   succeeded, the just-uploaded object is removed (the storage policy lets a
//   patient delete only their own UNFILED objects).
// - Path, not URL: rows are read via the real `pdf_path` column; a legacy
//   `pdf_url` left in the `data` payload is never trusted or re-emitted.
//
// Real repository + real SupabaseClient on package:http's MockClient.
// Fictional data only.
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
const _path = '$_patientId/36a00000-0000-4000-8000-000000000001.pdf';
const _signPrefix = '/storage/v1/object/sign/lab-reports/';
const _uploadPrefix = '/storage/v1/object/lab-reports/';

http.Response _json(http.Request r, Object? body, [int status = 200]) => http.Response(
      json.encode(body),
      status,
      headers: {'content-type': 'application/json'},
      request: r,
    );

class _Backend {
  _Backend({this.insertStatus = 201, this.uploadStatus = 200, this.removeStatus = 200, this.signStatus = 200, this.orgRows});
  final int insertStatus;
  final int uploadStatus;
  final int removeStatus;
  final int signStatus;
  final List<Map<String, dynamic>>? orgRows;
  final requests = <http.Request>[];

  late final MockClient mock = MockClient((r) async {
    requests.add(r);
    final path = r.url.path;
    if (path == '/rest/v1/patients') return _json(r, orgRows ?? [{'org_id': _orgId}]);
    if (path == '/rest/v1/lab_reports' && r.method == 'POST') {
      return insertStatus == 201
          ? http.Response('', 201, request: r)
          : _json(r, {'code': '42501', 'details': null, 'hint': null, 'message': 'fictional rls error text'}, insertStatus);
    }
    if (path.startsWith(_uploadPrefix) && r.method == 'POST') {
      return uploadStatus == 200
          ? _json(r, {'Key': path.substring('/storage/v1/object/'.length)})
          : _json(r, {'statusCode': '$uploadStatus', 'error': 'Unauthorized', 'message': 'fictional storage error text'}, uploadStatus);
    }
    if (path == '/storage/v1/object/lab-reports' && r.method == 'DELETE') {
      return removeStatus == 200 ? _json(r, []) : _json(r, {'message': 'fictional remove error'}, removeStatus);
    }
    if (path.startsWith(_signPrefix) && r.method == 'POST') {
      final object = path.substring(_signPrefix.length);
      return signStatus == 200
          ? _json(r, {'signedURL': '/object/sign/lab-reports/$object?token=fictional-signed-token'})
          : _json(r, {'statusCode': '404', 'error': 'not_found', 'message': 'Object not found'}, 400);
    }
    if (path.startsWith('/rest/v1/')) return http.Response('', 201, request: r);
    return http.Response('unexpected ${r.method} $path', 500, request: r);
  });

  List<http.Request> where(String method, bool Function(String) path) =>
      requests.where((r) => r.method == method && path(r.url.path)).toList();
  List<http.Request> get uploads => where('POST', (p) => p.startsWith(_uploadPrefix));
  List<http.Request> get removes => where('DELETE', (p) => p == '/storage/v1/object/lab-reports');
  List<http.Request> get inserts => where('POST', (p) => p == '/rest/v1/lab_reports');
  List<http.Request> get signs => where('POST', (p) => p.startsWith(_signPrefix));
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

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tc036-');
    pdf = File('${tmp.path}/Fictional report.pdf')..writeAsBytesSync(utf8.encode('%PDF-1.4 fictional'));
  });
  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
    tmp.deleteSync(recursive: true);
  });

  Future<bool> upload(_Backend b, List<String> printed) => _run(b, printed, () => HealthDataRepository.uploadLabReport(
        filePath: pdf.path,
        fileName: 'Fictional report.pdf',
        profileId: _patientId,
        extractedData: {'title': 'Fictional', 'date': '2026-10-30', 'summary': 's', 'markers': []},
      ));

  group('orphan cleanup (TC-036)', () {
    test('a failed insert after a successful upload removes exactly that object', () async {
      final b = _Backend(insertStatus: 403);
      final printed = <String>[];
      expect(await upload(b, printed), isFalse);
      expect(b.uploads, hasLength(1));
      final uploaded = b.uploads.single.url.path.substring(_uploadPrefix.length);
      expect(b.inserts, hasLength(1));
      expect(json.decode(b.inserts.single.body)['pdf_path'], uploaded);
      expect(b.removes, hasLength(1), reason: 'the unfiled upload must not be left behind');
      expect(json.decode(b.removes.single.body), {'prefixes': [uploaded]});
      expect(printed, isEmpty);
    });

    test('a failed cleanup still reports failure and prints nothing', () async {
      final b = _Backend(insertStatus: 403, removeStatus: 400);
      final printed = <String>[];
      expect(await upload(b, printed), isFalse);
      expect(b.removes, hasLength(1));
      expect(printed, isEmpty);
    });

    test('a failed upload files nothing and removes nothing', () async {
      final b = _Backend(uploadStatus: 403);
      final printed = <String>[];
      expect(await upload(b, printed), isFalse);
      expect(b.inserts, isEmpty);
      expect(b.removes, isEmpty);
      expect(printed, isEmpty);
    });

    test('no linked patient record: nothing is uploaded', () async {
      final b = _Backend(orgRows: const []);
      expect(await upload(b, []), isFalse);
      expect(b.uploads, isEmpty);
      expect(b.inserts, isEmpty);
    });

    test('a successful upload is not removed', () async {
      final b = _Backend();
      expect(await upload(b, []), isTrue);
      expect(b.removes, isEmpty);
    });
  });

  group('signed link (TC-036)', () {
    test('lifetime is 5 minutes, within the 10-minute cap', () {
      expect(HealthDataRepository.labReportLinkLifetime, const Duration(minutes: 5));
      expect(HealthDataRepository.labReportLinkLifetime <= const Duration(minutes: 10), isTrue);
    });

    test('opening a report asks storage to sign its path for 300 s and returns that link', () async {
      final b = _Backend();
      final printed = <String>[];
      final url = await _run(b, printed, () => HealthDataRepository.signedLabReportUrl(_path));
      expect(b.signs, hasLength(1));
      expect(b.signs.single.url.path, '$_signPrefix$_path');
      expect(json.decode(b.signs.single.body), {'expiresIn': 300});
      expect(url, startsWith('https://example.test/storage/v1/object/sign/lab-reports/$_path?token='));
      expect(url, isNot(contains('/object/public/')));
      expect(printed, isEmpty, reason: 'a signed link is a bearer credential; never logged');
      expect(b.requests.where((r) => r.url.path.startsWith('/rest/v1/')), isEmpty,
          reason: 'the link is never written back anywhere');
    });

    test('a refused signature (no access / no object) returns null and prints nothing', () async {
      final b = _Backend(signStatus: 400);
      final printed = <String>[];
      expect(await _run(b, printed, () => HealthDataRepository.signedLabReportUrl(_path)), isNull);
      expect(printed, isEmpty);
    });

    test('only a bare object path is ever signed (no URL, no traversal, no empty)', () async {
      for (final bad in [
        'https://example.test/storage/v1/object/public/lab-reports/$_path',
        '$_patientId/../00000000-0000-0000-0000-0000000b1001/x.pdf',
        '/$_path',
        '',
        '$_patientId/x.pdf?download',
      ]) {
        final b = _Backend();
        expect(await _run(b, [], () => HealthDataRepository.signedLabReportUrl(bad)), isNull, reason: bad);
        expect(b.signs, isEmpty, reason: bad);
      }
    });
  });

  group('path, not URL (TC-036)', () {
    test('a row maps its pdf_path column onto LabReport.pdfPath', () {
      final r = HealthDataRepository.labReportFromRow({
        'id': 'r1',
        'report_type': 'patient_upload',
        'created_at': '2026-10-30T08:00:00Z',
        'pdf_path': _path,
        'data': {'title': 'Fictional', 'markers': []},
      });
      expect(r.pdfPath, _path);
    });

    test('a legacy pdf_url in the payload is ignored and never re-emitted', () {
      final r = HealthDataRepository.labReportFromRow({
        'id': 'r2',
        'report_type': 'legacy',
        'created_at': '2026-10-30T08:00:00Z',
        'pdf_path': null,
        'data': {
          'title': 'Fictional legacy',
          'pdf_url': 'https://demo.example.test/storage/v1/object/public/lab-reports/$_path',
          'pdf_path': '00000000-0000-0000-0000-0000000b1001/x.pdf',
        },
      });
      expect(r.pdfPath, isNull, reason: 'only the real column is trusted');
      final out = json.encode(r.toJson());
      expect(out, isNot(contains('http')));
      expect(r.toJson().containsKey('pdf_url'), isFalse);
    });

    test('new uploads get <patient_id>/<fresh uuid>.<ext>, never the user file name', () {
      final a = HealthDataRepository.newLabReportObjectPath(_patientId, 'My Labs (Dr Fictional).PDF');
      final b = HealthDataRepository.newLabReportObjectPath(_patientId, 'scan.JPEG');
      expect(a, matches(RegExp('^$_patientId/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\.pdf\$')));
      expect(b, endsWith('.jpg'));
      expect(a, isNot(contains('Labs')));
      expect(HealthDataRepository.newLabReportObjectPath(_patientId, 'x.pdf'),
          isNot(HealthDataRepository.newLabReportObjectPath(_patientId, 'x.pdf')));
      expect(() => HealthDataRepository.newLabReportObjectPath(_patientId, 'x.exe'), throwsArgumentError);
    });
  });

  group('delete (TC-036)', () {
    test('a refused delete returns false and prints nothing', () async {
      final b = _Backend();
      final printed = <String>[];
      final ok = await _run(b, printed, () => HealthDataRepository.deleteLabReport('r1', _patientId, _path));
      expect(ok, isFalse);
      expect(printed, isEmpty);
    });
  });
}
