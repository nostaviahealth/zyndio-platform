// APP-07: the wearable_daily uploader and sync. Drives a real SupabaseClient
// through package:http's MockClient and asserts the exact PostgREST upsert
// (table, on_conflict key, merge-duplicates), the 90-day backfill on connect
// (30 days until Health Connect's history permission is granted), the
// incremental window after that, and that repeat uploads send the same rows
// (the server replaces, never adds). Nothing is printed. Fictional data only.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zyndio_patient/services/wearable_daily/wearable_daily_aggregator.dart';
import 'package:zyndio_patient/services/wearable_daily/wearable_daily_sync.dart';
import 'package:zyndio_patient/services/wearable_daily/wearable_daily_uploader.dart';
import 'package:zyndio_patient/services/wearable_daily/wearable_metric.dart';

import '../../support/fake_supabase_rest.dart';

const _patientId = '00000000-0000-0000-0000-0000000a1001';
const _orgId = '00000000-0000-0000-0000-00000000000a';
const _watch = 'com.example.fictional.watchapp';

class _Backend {
  final auth = FakeSupabaseRest();
  final upserts = <http.Request>[];
  final orgLookups = <http.Request>[];
  bool linked = true;
  int upsertStatus = 201;

  late final MockClient mock = MockClient((r) async {
    if (r.url.path == '/rest/v1/patients') {
      orgLookups.add(r);
      return http.Response(
          json.encode(linked
              ? [
                  {'org_id': _orgId}
                ]
              : []),
          200,
          headers: {'content-type': 'application/json'},
          request: r);
    }
    if (r.url.path == '/rest/v1/${WearableDailyUploader.table}') {
      upserts.add(r);
      return upsertStatus < 300
          ? http.Response('', upsertStatus, request: r)
          : http.Response(
              json.encode({'code': '23514', 'message': 'fictional failure'}),
              upsertStatus,
              headers: {'content-type': 'application/json'},
              request: r);
    }
    // Auth (the signed-in session) goes to the shared fake; a finalized
    // request can't be sent twice, so forward a copy.
    final copy = http.Request(r.method, r.url)
      ..headers.addAll(r.headers)
      ..bodyBytes = r.bodyBytes;
    return http.Response.fromStream(await auth.mockClient.send(copy));
  });

  List<Map<String, dynamic>> get sentRows => [
        for (final r in upserts)
          ...(json.decode(r.body) as List).cast<Map<String, dynamic>>(),
      ];
}

class _FakeReader implements WearableSampleReader {
  _FakeReader({this.history = true});
  bool history;
  final windows = <(DateTime, DateTime)>[];

  @override
  Future<bool> historyAuthorized() async => history;

  @override
  Future<List<WearableSample>> read(DateTime start, DateTime end) async {
    windows.add((start, end));
    // A fictional walk at 09:00 every day of the window + one night.
    final out = <WearableSample>[];
    for (var d = DateTime(start.year, start.month, start.day);
        d.isBefore(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final walk = DateTime(d.year, d.month, d.day, 9);
      if (walk.isBefore(start) || !walk.isBefore(end)) continue;
      out.add(WearableSample(
        metric: WearableMetric.steps,
        value: 4200,
        start: walk,
        end: walk.add(const Duration(minutes: 40)),
        sourceApp: _watch,
        sourceDevice: WearableDeviceClass.watch,
      ));
    }
    return out;
  }
}

/// Runs [body] with a signed-in patient on a real SupabaseClient routed to
/// [b], collecting everything printed.
Future<T> _run<T>(_Backend b, List<String> printed,
        Future<T> Function(SupabaseClient client) body) =>
    runZoned(
      () => http.runWithClient(() async {
        final client = SupabaseClient(fakeSupabaseUrl, fakeSupabaseAnonKey);
        await b.auth.signIn(client, _patientId);
        return body(client);
      }, () => b.mock),
      zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => printed.add(line)),
    );

WearableDailyRow _row(int day, {String app = _watch, double value = 1000}) =>
    WearableDailyRow(
      metricDate: DateTime(2026, 10, 1).add(Duration(days: day)),
      metric: WearableMetric.steps,
      value: value,
      sourceApp: app,
      sourceDevice: WearableDeviceClass.watch,
      coverage: 0.5,
      selected: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WearableDailyUploader', () {
    test('upserts on the table key with merge-duplicates, in batches',
        () async {
      final b = _Backend();
      final printed = <String>[];
      final rows = [
        for (var i = 0; i < 300; i++)
          _row(i % 30, app: 'com.example.fictional.app$i'),
        for (var i = 0; i < 300; i++)
          _row(i % 30, app: 'com.example.fictional.other$i'),
      ];
      final sent = await _run(
          b, printed, (c) => WearableDailyUploader(c).upload(_patientId, rows));

      expect(sent, 600);
      expect(b.orgLookups, hasLength(1));
      expect(b.orgLookups.single.url.queryParameters,
          {'select': 'org_id', 'id': 'eq.$_patientId'});
      expect(b.upserts, hasLength(2),
          reason: '${WearableDailyUploader.batchSize} rows per request');
      for (final r in b.upserts) {
        expect(r.method, 'POST');
        expect(r.url.queryParameters['on_conflict'],
            'patient_id,metric_date,metric,source_app');
        expect(r.headers['Prefer'], contains('resolution=merge-duplicates'));
      }
      final first = b.sentRows.first;
      expect(first.keys.toSet(), {
        'org_id',
        'patient_id',
        'metric_date',
        'metric',
        'value',
        'unit',
        'source_app',
        'source_device',
        'coverage',
        'selected',
      });
      expect(first['patient_id'], _patientId);
      expect(first['org_id'], _orgId);
      expect(printed, isEmpty);
    });

    test('rows with the same key are sent once', () async {
      final b = _Backend();
      await _run(
          b,
          [],
          (c) => WearableDailyUploader(c)
              .upload(_patientId, [_row(0), _row(0, value: 2000)]));
      expect(b.sentRows, hasLength(1));
      expect(b.sentRows.single['value'], 2000);
    });

    test('no linked patient record: nothing is sent', () async {
      final b = _Backend()..linked = false;
      await expectLater(
        _run(b, [],
            (c) => WearableDailyUploader(c).upload(_patientId, [_row(0)])),
        throwsStateError,
      );
      expect(b.upserts, isEmpty);
    });
  });

  group('WearableDailySync', () {
    final now = DateTime(2026, 11, 4, 10, 30);

    setUp(() => SharedPreferences.setMockInitialValues({}));

    WearableDailySync sync(SupabaseClient c, _FakeReader reader,
            {DateTime? at, bool linked = true}) =>
        WearableDailySync(
          reader: reader,
          client: () => c,
          isLinked: () async => linked,
          now: () => at ?? now,
        );

    test('first sync backfills 90 days, in 30-day chunks, and records progress',
        () async {
      final b = _Backend();
      final reader = _FakeReader();
      final printed = <String>[];
      final outcome = await _run(b, printed, (c) => sync(c, reader).sync());

      expect(outcome.status, WearableSyncStatus.uploaded);
      expect(outcome.rows, 90);
      final dates = b.sentRows.map((r) => r['metric_date'] as String).toSet();
      expect(dates, hasLength(90));
      expect(dates, contains('2026-08-07'));
      expect(dates, contains('2026-11-04'));
      expect(dates, isNot(contains('2026-08-06')),
          reason: 'the lead-in day is read but not uploaded');
      expect(reader.windows, hasLength(3));
      expect(reader.windows.first.$1, DateTime(2026, 8, 6),
          reason: 'one day of lead-in for the first night');
      expect(reader.windows.last.$2, now);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(WearableDailySync.backfillKey(_patientId)), 90);
      expect(prefs.getString(WearableDailySync.lastSyncKey(_patientId)),
          '2026-11-04');
      expect(printed, isEmpty);
    });

    test('later syncs re-send only the last days (overlap for late data)',
        () async {
      SharedPreferences.setMockInitialValues({
        WearableDailySync.backfillKey(_patientId): 90,
        WearableDailySync.lastSyncKey(_patientId): '2026-11-04',
      });
      final b = _Backend();
      final reader = _FakeReader();
      final next = DateTime(2026, 11, 5, 8);
      await _run(b, [], (c) => sync(c, reader, at: next).sync());
      expect(reader.windows, [(DateTime(2026, 10, 31), next)]);
      expect(b.sentRows.map((r) => r['metric_date']).toSet(),
          {'2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04'},
          reason: 'the lead-in day is not re-sent; today has no data yet');
    });

    test(
        'a repeat upload sends identical rows (the upsert replaces, never adds)',
        () async {
      SharedPreferences.setMockInitialValues({
        WearableDailySync.backfillKey(_patientId): 90,
        WearableDailySync.lastSyncKey(_patientId): '2026-11-04',
      });
      final b1 = _Backend();
      final b2 = _Backend();
      await _run(b1, [], (c) => sync(c, _FakeReader()).sync());
      await _run(b2, [], (c) => sync(c, _FakeReader()).sync());
      expect(b1.sentRows, isNotEmpty);
      expect(json.encode(b2.sentRows), json.encode(b1.sentRows));
    });

    test(
        'Health Connect without history permission: 30 days now, 90 once granted',
        () async {
      final b = _Backend();
      final reader = _FakeReader(history: false);
      await _run(b, [], (c) => sync(c, reader).sync());
      expect(b.sentRows.map((r) => r['metric_date']).toSet(), hasLength(30));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(WearableDailySync.backfillKey(_patientId)), 30);

      reader.history = true;
      final b2 = _Backend();
      await _run(b2, [], (c) => sync(c, reader).sync());
      expect(b2.sentRows.map((r) => r['metric_date']).toSet(), hasLength(90));
      expect(prefs.getInt(WearableDailySync.backfillKey(_patientId)), 90);
    });

    test('not connected / no linked patient: nothing is read or sent',
        () async {
      final b = _Backend();
      final reader = _FakeReader();
      final outcome =
          await _run(b, [], (c) => sync(c, reader, linked: false).sync());
      expect(outcome.status, WearableSyncStatus.skipped);
      expect(reader.windows, isEmpty);
      expect(b.upserts, isEmpty);

      final noClient =
          await WearableDailySync(reader: reader, client: () => null).sync();
      expect(noClient.status, WearableSyncStatus.skipped);
    });

    test('a refused upload fails quietly and is retried in full next time',
        () async {
      final b = _Backend()..upsertStatus = 400;
      final printed = <String>[];
      final outcome =
          await _run(b, printed, (c) => sync(c, _FakeReader()).sync());
      expect(outcome.status, WearableSyncStatus.failed);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(WearableDailySync.backfillKey(_patientId)), isNull);
      expect(
          prefs.getString(WearableDailySync.lastSyncKey(_patientId)), isNull);
      expect(printed, isEmpty);
    });

    test('a second call while syncing joins the running sync', () async {
      final b = _Backend();
      final reader = _FakeReader();
      await _run(b, [], (c) async {
        final s = sync(c, reader);
        await Future.wait([s.sync(), s.sync()]);
      });
      expect(reader.windows, hasLength(3));
      expect(b.sentRows.map((r) => r['metric_date']).toSet(), hasLength(90));
      expect(b.sentRows, hasLength(90));
    });
  });
}
