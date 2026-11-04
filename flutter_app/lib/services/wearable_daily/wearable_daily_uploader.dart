import 'package:supabase_flutter/supabase_flutter.dart';

import 'wearable_daily_aggregator.dart';

/// APP-07: writes daily rows to public.wearable_daily.
///
/// Each batch is one PostgREST upsert on the table's unique key, so sending
/// the same day again replaces the stored value (never adds a second row).
/// RLS (wearable_daily_self_insert / _self_update) only accepts the signed-in
/// patient's own rows filed under their own clinic, so the clinic is looked
/// up from public.patients first. Errors are thrown to the caller; nothing is
/// printed (no health values or backend text in device logs).
class WearableDailyUploader {
  WearableDailyUploader(this._client);

  final SupabaseClient _client;

  static const table = 'wearable_daily';
  static const onConflict = 'patient_id,metric_date,metric,source_app';

  /// Rows per request; keeps a 90-day backfill to a handful of requests.
  static const batchSize = 500;

  Future<String> _ownOrgId(String patientId) async {
    final rows =
        await _client.from('patients').select('org_id').eq('id', patientId);
    if (rows.isEmpty || rows.first['org_id'] is! String) {
      throw StateError('No linked patient record');
    }
    return rows.first['org_id'] as String;
  }

  /// Upserts [rows] for [patientId]. Returns the number of rows sent.
  Future<int> upload(String patientId, List<WearableDailyRow> rows) async {
    if (rows.isEmpty) return 0;
    final orgId = await _ownOrgId(patientId);
    // One row per key, even if the caller passed overlapping windows.
    final byKey = <String, WearableDailyRow>{for (final r in rows) r.key: r};
    final body = byKey.values
        .map((r) => r.toUpsertJson(patientId: patientId, orgId: orgId))
        .toList();
    for (var i = 0; i < body.length; i += batchSize) {
      final end = i + batchSize < body.length ? i + batchSize : body.length;
      await _client
          .from(table)
          .upsert(body.sublist(i, end), onConflict: onConflict);
    }
    return body.length;
  }
}
