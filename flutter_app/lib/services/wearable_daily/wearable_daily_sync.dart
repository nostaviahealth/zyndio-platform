import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../data/health_repository.dart';
import '../vo2_max_service.dart';
import 'health_sample_mapper.dart';
import 'wearable_daily_aggregator.dart';
import 'wearable_daily_uploader.dart';
import 'wearable_metric.dart';

/// Where daily samples come from. The real one reads Apple Health / Health
/// Connect; tests pass a fake.
abstract class WearableSampleReader {
  Future<List<WearableSample>> read(DateTime start, DateTime end);

  /// Health Connect only lets an app read data older than 30 days before its
  /// first permission grant with READ_HEALTH_DATA_HISTORY. Always true on iOS.
  Future<bool> historyAuthorized();
}

class HealthPluginSampleReader implements WearableSampleReader {
  HealthPluginSampleReader([Health? health]) : _health = health ?? Health();

  final Health _health;

  @override
  Future<bool> historyAuthorized() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _health.isHealthDataHistoryAuthorized();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<WearableSample>> read(DateTime start, DateTime end) async {
    await _health.configure();
    final types =
        Platform.isIOS ? wearableUploadTypesIOS : wearableUploadTypesAndroid;
    final out = <WearableSample>[];
    // One type per query: a type the patient didn't grant must not cost the
    // others (Health Connect fails a whole multi-type read).
    for (final type in types) {
      try {
        final points = await _health.getHealthDataFromTypes(
          types: [type],
          startTime: start,
          endTime: end,
        );
        for (final p in _health.removeDuplicates(points)) {
          final s = wearableSampleFromHealthPoint(p);
          if (s != null) out.add(s);
        }
      } catch (_) {
        // Not granted / not available on this device: no data for this type.
      }
    }
    if (Platform.isIOS) out.addAll(await _readVo2Max(start, end));
    return out;
  }

  /// VO2 max is not in package:health; the app reads it over its own
  /// HealthKit channel (iOS only). Health Connect VO2 max is not read yet.
  Future<List<WearableSample>> _readVo2Max(DateTime start, DateTime end) async {
    final days = end.difference(start).inDays + 1;
    final history = await Vo2MaxService.getVo2MaxHistory(days: days);
    final out = <WearableSample>[];
    for (final h in history) {
      final date = h['date'];
      final value = h['value'];
      if (date is! DateTime || value is! double) continue;
      if (date.isBefore(start) || !date.isBefore(end)) continue;
      out.add(WearableSample(
        metric: WearableMetric.vo2max,
        value: value,
        start: date,
        end: date,
        sourceApp: 'com.apple.health',
        sourceDevice: wearableDeviceClassFor(
          sourceId: 'com.apple.health',
          sourceName: h['source'] as String?,
        ),
      ));
    }
    return out;
  }
}

/// Extra read permissions the upload needs beyond the app's existing
/// Connect flow (HealthRepository.requestUnifiedPermissions).
class WearableUploadPermissions {
  WearableUploadPermissions([Health? health]) : _health = health ?? Health();

  final Health _health;

  /// Android: body measurements (weight, height for BMI, blood pressure) and
  /// READ_HEALTH_DATA_HISTORY for the 90-day backfill, each best-effort -
  /// a refusal just means less data. iOS: the native unified request already
  /// covers every uploaded type.
  Future<void> request() async {
    if (!Platform.isAndroid) return;
    try {
      const extras = [
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      ];
      await _health.requestAuthorization(
        extras,
        permissions: extras.map((_) => HealthDataAccess.READ).toList(),
      );
    } catch (_) {}
    try {
      if (await _health.isHealthDataHistoryAvailable() &&
          !await _health.isHealthDataHistoryAuthorized()) {
        await _health.requestHealthDataHistoryAuthorization();
      }
    } catch (_) {}
  }
}

enum WearableSyncStatus { uploaded, skipped, failed }

class WearableSyncOutcome {
  const WearableSyncOutcome(this.status, [this.rows = 0]);
  final WearableSyncStatus status;
  final int rows;
}

/// APP-07: aggregates on the device and uploads to wearable_daily.
///
///  * First sync after connecting: backfills [backfillDays] days (30 on
///    Health Connect until READ_HEALTH_DATA_HISTORY is granted; the longer
///    backfill runs once it is).
///  * Later syncs: from the last synced day minus [overlapDays] (late
///    arriving watch data, edits) up to today. Repeat uploads are idempotent.
///  * Runs on app start, on every return to the foreground (at most every
///    [minAutoInterval]) and right after connecting. There is no OS
///    background task yet (no background-fetch plugin in the app).
class WearableDailySync with WidgetsBindingObserver {
  WearableDailySync({
    WearableSampleReader? reader,
    SupabaseClient? Function()? client,
    Future<bool> Function()? isLinked,
    Future<SharedPreferences> Function()? prefs,
    DateTime Function()? now,
    this.policy = const WearableSourcePolicy(),
  })  : _reader = reader ?? HealthPluginSampleReader(),
        _client = client ?? (() => SupabaseConfig.client),
        _isLinked = isLinked ?? (() => HealthRepository().isLinked()),
        _prefs = prefs ?? SharedPreferences.getInstance,
        _now = now ?? DateTime.now;

  static final instance = WearableDailySync();

  static const backfillDays = 90;
  static const historyLimitedDays = 30;
  static const overlapDays = 3;
  static const chunkDays = 30;
  static const minAutoInterval = Duration(minutes: 15);

  final WearableSampleReader _reader;
  final SupabaseClient? Function() _client;
  final Future<bool> Function() _isLinked;
  final Future<SharedPreferences> Function() _prefs;
  final DateTime Function() _now;
  final WearableSourcePolicy policy;

  Future<WearableSyncOutcome>? _running;
  DateTime? _lastAutoRun;
  bool _observing = false;

  static String backfillKey(String patientId) =>
      'wearable_daily_backfill_days_$patientId';
  static String lastSyncKey(String patientId) =>
      'wearable_daily_last_sync_$patientId';

  /// Syncs now; a call while a sync is running joins that sync.
  Future<WearableSyncOutcome> sync() =>
      _running ??= _sync().whenComplete(() => _running = null);

  Future<WearableSyncOutcome> _sync() async {
    try {
      final client = _client();
      final patientId = client?.auth.currentUser?.id;
      if (client == null || patientId == null || !await _isLinked()) {
        return const WearableSyncOutcome(WearableSyncStatus.skipped);
      }

      final prefs = await _prefs();
      final now = _now();
      final today = DateTime(now.year, now.month, now.day);
      final wanted =
          await _reader.historyAuthorized() ? backfillDays : historyLimitedDays;
      final done = prefs.getInt(backfillKey(patientId)) ?? 0;
      final earliest =
          DateTime(today.year, today.month, today.day - (wanted - 1));
      final backfilling = done < wanted;

      var from = earliest;
      if (!backfilling) {
        final last =
            DateTime.tryParse(prefs.getString(lastSyncKey(patientId)) ?? '') ??
                today;
        from = DateTime(last.year, last.month, last.day - overlapDays);
        if (from.isBefore(earliest)) from = earliest;
      }

      final uploader = WearableDailyUploader(client);
      var sent = 0;
      for (var chunkStart = from;
          !chunkStart.isAfter(today);
          chunkStart = DateTime(
              chunkStart.year, chunkStart.month, chunkStart.day + chunkDays)) {
        var chunkEnd = DateTime(
            chunkStart.year, chunkStart.month, chunkStart.day + chunkDays - 1);
        if (chunkEnd.isAfter(today)) chunkEnd = today;
        // One day of lead-in so the first night's sleep and samples that
        // cross midnight are complete.
        final readStart =
            DateTime(chunkStart.year, chunkStart.month, chunkStart.day - 1);
        final readEnd = chunkEnd == today
            ? now
            : DateTime(chunkEnd.year, chunkEnd.month, chunkEnd.day + 1);
        final samples = await _reader.read(readStart, readEnd);
        final rows = aggregateWearableDaily(samples,
            policy: policy, fromDate: chunkStart, toDate: chunkEnd);
        sent += await uploader.upload(patientId, rows);
      }

      if (backfilling) await prefs.setInt(backfillKey(patientId), wanted);
      await prefs.setString(lastSyncKey(patientId), formatWearableDate(today));
      return WearableSyncOutcome(WearableSyncStatus.uploaded, sent);
    } catch (_) {
      // Retried on the next sync; nothing printed (no health data in logs).
      return const WearableSyncOutcome(WearableSyncStatus.failed);
    }
  }

  /// Called right after the patient connects Apple Health / Health Connect:
  /// asks for the upload's extra permissions, then starts the backfill.
  Future<WearableSyncOutcome> onConnected(
      {WearableUploadPermissions? permissions}) async {
    try {
      await (permissions ?? WearableUploadPermissions()).request();
    } catch (_) {}
    return sync();
  }

  /// Syncs now and whenever the app returns to the foreground.
  void startAutoSync() {
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _autoSync();
  }

  void _autoSync() {
    final now = _now();
    final last = _lastAutoRun;
    if (last != null && now.difference(last) < minAutoInterval) return;
    _lastAutoRun = now;
    unawaited(sync());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoSync();
  }
}
