// TC-037: the patient's lab-report list (Biomarkers, Today, chat context)
// must query the REAL lab_reports schema and must not swallow errors.
//
// Before TC-037, HealthDataRepository.fetchReports filtered on `profile_id`
// and sorted on `date` - neither column exists (real columns: id, org_id,
// patient_id, report_type, data, created_at, needs_review, flagged_at,
// flagged_by, identity_hold; see supabase/migrations/*tc005_schema.sql and
// *tc015_schema.sql). PostgREST answers that with 400 / 42703, the repository
// caught it, printed the error text and returned [], so Biomarkers showed
// "No lab results yet" instead of its error state - on every real backend.
//
// These tests drive the real repository + real SupabaseClient through
// package:http's MockClient (test/support/fake_supabase_rest.dart pattern).
// The exact request is pinned by tests/contracts/patient-lab-reports-query.json,
// which tests/integration/patient-lab-reports-query.test.ts replays against
// the migrated schema + RLS through real PostgREST. Fictional data only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/data/health_data_repository.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/screens/biomarkers/biomarkers_screen.dart';

const _patientId = '00000000-0000-0000-0000-0000000a1001';

Map<String, dynamic> _contract() => json.decode(
      File('../tests/contracts/patient-lab-reports-query.json').readAsStringSync(),
    ) as Map<String, dynamic>;

/// A PostgREST-shaped lab_reports row (only the selected real columns).
Map<String, dynamic> _row({
  required String id,
  required String createdAt,
  String reportType = 'basic_panel',
  Map<String, dynamic>? data,
}) =>
    {
      'id': id,
      'report_type': reportType,
      'data': data ?? <String, dynamic>{},
      'created_at': createdAt,
    };

/// What real PostgREST returns for the pre-TC-037 query.
http.Response _undefinedColumn(http.Request r) => http.Response(
      json.encode({
        'code': '42703',
        'details': null,
        'hint': null,
        'message': 'column lab_reports.profile_id does not exist',
      }),
      400,
      headers: {'content-type': 'application/json'},
      request: r,
    );

class _Harness {
  _Harness(this.respond);
  final http.Response Function(http.Request) respond;
  final requests = <http.Request>[];
  late final MockClient mock = MockClient((r) async {
    requests.add(r);
    return respond(r);
  });
  List<http.Request> get rest =>
      requests.where((r) => r.url.path.startsWith('/rest/v1/')).toList();
}

http.Response _json(http.Request r, Object body) => http.Response(
      json.encode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: r,
    );

/// Builds a real SupabaseClient on [h]'s MockClient and runs [body] with it
/// installed as SupabaseConfig.client.
Future<T> _withClient<T>(_Harness h, Future<T> Function() body) =>
    http.runWithClient(() async {
      SupabaseConfig.debugClientOverride =
          SupabaseClient('https://example.test', 'fake-anon-key');
      return body();
    }, () => h.mock);

class _FixedProfile extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async => PatientProfile(id: _patientId);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => SupabaseConfig.debugClientOverride = null);

  group('HealthDataRepository.fetchReports (TC-037)', () {
    test('sends exactly the pinned real-schema request for the signed-in patient', () async {
      final h = _Harness((r) => _json(r, []));
      await _withClient(h, () => HealthDataRepository.fetchReports(_patientId));

      final c = _contract();
      expect(h.rest, hasLength(1));
      final req = h.rest.single;
      expect(req.method, c['method']);
      expect(req.url.path, c['path']);
      final expected = (c['query'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, (v as String).replaceAll('{patient_id}', _patientId)),
      );
      expect(req.url.queryParameters, expected);
    });

    test('never names a column that does not exist on lab_reports', () async {
      final h = _Harness((r) => _json(r, []));
      await _withClient(h, () => HealthDataRepository.fetchReports(_patientId));
      final q = h.rest.single.url.queryParameters;
      expect(q.containsKey('profile_id'), isFalse, reason: q.toString());
      expect(q['order'], isNot(startsWith('date')), reason: q.toString());
    });

    test('maps real rows (data payload + created_at) into LabReports, newest first', () async {
      final h = _Harness((r) => _json(r, [
            _row(
              id: '00000000-0000-0000-0000-0000000a3102',
              createdAt: '2026-06-01T08:00:00+00:00',
              reportType: 'metabolic_panel',
              data: {
                'title': 'Fictional metabolic panel',
                'markers': [
                  {'name': 'HbA1c', 'value': '5.2', 'unit': '%', 'range': '4.0-5.6', 'status': 'Normal'},
                ],
              },
            ),
            _row(
              id: '00000000-0000-0000-0000-0000000a3101',
              createdAt: '2026-01-01T08:00:00+00:00',
              data: {'result': 'fictional'},
            ),
          ]));
      final reports =
          await _withClient(h, () => HealthDataRepository.fetchReports(_patientId));

      expect(reports.map((r) => r.id), [
        '00000000-0000-0000-0000-0000000a3102',
        '00000000-0000-0000-0000-0000000a3101',
      ]);
      final latest = reports.first;
      expect(latest.date, '2026-06-01');
      expect(latest.title, 'Fictional metabolic panel');
      expect(latest.reportType, 'metabolic_panel');
      expect(latest.markers.single.name, 'HbA1c');
      expect(latest.markers.single.value, '5.2');
      // A payload with no markers is still a report, just an empty one.
      expect(reports.last.date, '2026-01-01');
      expect(reports.last.reportType, 'basic_panel');
      expect(reports.last.markers, isEmpty);
    });

    test('a backend error is thrown to the caller, not turned into an empty list', () async {
      final h = _Harness(_undefinedColumn);
      await expectLater(
        _withClient(h, () => HealthDataRepository.fetchReports(_patientId)),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('a backend error does not print its error text', () async {
      final h = _Harness(_undefinedColumn);
      final printed = <String>[];
      await runZonedPrinting(printed, () async {
        try {
          await _withClient(h, () => HealthDataRepository.fetchReports(_patientId));
        } catch (_) {}
      });
      expect(printed.where((l) => l.contains('does not exist') || l.contains('HealthRepo Error')),
          isEmpty,
          reason: printed.join('\n'));
    });

    test('no signed-in patient: empty list and no request', () async {
      final h = _Harness((r) => _json(r, []));
      final reports = await _withClient(h, () => HealthDataRepository.fetchReports(null));
      expect(reports, isEmpty);
      expect(h.rest, isEmpty);
    });
  });

  group('Biomarkers through the real repository (TC-037)', () {
    Future<void> pump(WidgetTester tester, _Harness h,
        {int rounds = 40, Duration step = const Duration(seconds: 1)}) async {
      tester.view.physicalSize = const Size(1200, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() => http.runWithClient(() async {
            SupabaseConfig.debugClientOverride =
                SupabaseClient('https://example.test', 'fake-anon-key');
          }, () => h.mock));
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => const Scaffold(body: BiomarkersScreen())),
        GoRoute(
            path: '/health_data/upload',
            name: 'upload_report',
            builder: (c, s) => const Scaffold(body: Text('UPLOAD'))),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [patientProfileProvider.overrideWith(_FixedProfile.new)],
        child: MaterialApp.router(theme: BrandTheme.lightTheme, routerConfig: router),
      ));
      // Let the real (mocked-transport) HTTP round trips complete, advancing
      // fake time too so any provider retry backoff runs out.
      for (var i = 0; i < rounds; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(step);
      }
    }

    testWidgets('a failed query shows the error state, not the empty state', (tester) async {
      final h = _Harness(_undefinedColumn);
      await pump(tester, h);
      expect(h.rest, isNotEmpty);
      expect(find.text("We couldn't load your results"), findsOneWidget);
      expect(find.text('No lab results yet'), findsNothing);
    });

    testWidgets('a failed query shows the error state promptly, without a hidden retry loop',
        (tester) async {
      // Riverpod 3 retries a failed provider up to 10 times (200 ms .. 6.4 s
      // backoff, ~38 s) and shows the loading skeleton meanwhile. A query the
      // server rejected will not succeed on retry; the card's own "Try again"
      // button is the retry.
      final h = _Harness(_undefinedColumn);
      await pump(tester, h, rounds: 5, step: const Duration(milliseconds: 100));
      expect(find.text("We couldn't load your results"), findsOneWidget);
      expect(h.rest.length, 1, reason: 'one request, no automatic retries');
    });

    testWidgets('an empty result shows the empty state', (tester) async {
      final h = _Harness((r) => _json(r, []));
      await pump(tester, h);
      expect(find.text('No lab results yet'), findsOneWidget);
      expect(find.text("We couldn't load your results"), findsNothing);
    });

    testWidgets('the owner sees their results', (tester) async {
      final h = _Harness((r) => _json(r, [
            _row(
              id: '00000000-0000-0000-0000-0000000a3102',
              createdAt: '2026-06-01T08:00:00+00:00',
              data: {
                'markers': [
                  {'name': 'Intracellular NAD+', 'value': '41', 'unit': 'µM', 'status': 'Normal'},
                ],
              },
            ),
          ]));
      await pump(tester, h);
      expect(find.text('No lab results yet'), findsNothing);
      expect(find.text("We couldn't load your results"), findsNothing);
      expect(find.textContaining('NAD+'), findsWidgets);
    });
  });
}

/// Captures print() output from [body] (debugPrint is routed through print).
Future<void> runZonedPrinting(List<String> sink, Future<void> Function() body) {
  final previous = debugPrint;
  debugPrint = (String? m, {int? wrapWidth}) => sink.add(m ?? '');
  return runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => sink.add(line),
    ),
  ).whenComplete(() => debugPrint = previous);
}
