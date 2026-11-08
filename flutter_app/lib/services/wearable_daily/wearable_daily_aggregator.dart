import 'dart:math' as math;

import 'wearable_metric.dart';

/// APP-07: on-device daily aggregation for `wearable_daily`.
///
/// Rules (pure Dart, no plugin calls, so it is unit-tested directly):
///  * one value per metric per local calendar day PER SOURCE - samples from
///    different sources are never added together;
///  * per metric and day exactly one source is `selected`, chosen by
///    [WearableSourcePolicy]; readers use only the selected row;
///  * sleep is one value per night (the longest sleep episode), filed under
///    the local date the episode ends (the wake date); naps are not counted;
///  * values outside the metric's plausibility limits are dropped (the server
///    refuses them and would reject the whole upload batch).

/// Coarse device class. Device display names are never uploaded (they often
/// carry the patient's name, e.g. "NAME's Apple Watch").
enum WearableDeviceClass { watch, phone, ring, scale, other }

class WearableSample {
  const WearableSample({
    required this.metric,
    required this.value,
    required this.start,
    required this.end,
    required this.sourceApp,
    this.sourceDevice,
    this.isSleepSession = false,
  });

  final WearableMetric metric;

  /// The reading, in [metric]'s unit. Ignored for sleep (the interval is
  /// what counts).
  final double value;
  final DateTime start;
  final DateTime end;

  /// Bundle id / package name of the recording app.
  final String sourceApp;
  final WearableDeviceClass? sourceDevice;

  /// Sleep only: a whole sleep session without stage detail (Health
  /// Connect). Used only where the same source has no asleep-stage samples.
  final bool isSleepSession;
}

class WearableDailyRow {
  const WearableDailyRow({
    required this.metricDate,
    required this.metric,
    required this.value,
    required this.sourceApp,
    this.sourceDevice,
    this.coverage,
    this.selected = false,
  });

  /// Local calendar date (time part is midnight).
  final DateTime metricDate;
  final WearableMetric metric;
  final double value;
  final String sourceApp;
  final WearableDeviceClass? sourceDevice;
  final double? coverage;
  final bool selected;

  String get dateKey => formatWearableDate(metricDate);

  /// The table's unique key: patient + date + metric + source.
  String get key => '$dateKey|${metric.wireName}|$sourceApp';

  WearableDailyRow copyWith({bool? selected}) => WearableDailyRow(
        metricDate: metricDate,
        metric: metric,
        value: value,
        sourceApp: sourceApp,
        sourceDevice: sourceDevice,
        coverage: coverage,
        selected: selected ?? this.selected,
      );

  /// The upsert body for one row (column names of public.wearable_daily).
  Map<String, dynamic> toUpsertJson(
          {required String patientId, required String orgId}) =>
      {
        'org_id': orgId,
        'patient_id': patientId,
        'metric_date': dateKey,
        'metric': metric.wireName,
        'value': value,
        'unit': metric.unit,
        'source_app': sourceApp,
        'source_device': sourceDevice?.name,
        'coverage': coverage,
        'selected': selected,
      };

  @override
  String toString() => 'WearableDailyRow($key=$value${selected ? ' *' : ''})';
}

String formatWearableDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Which source wins a metric's day. Order of tests:
///  1. [preferredApps]: the first prefix that matches the source app;
///  2. the metric's device-class order ([activityDeviceOrder], or
///     [bodyDeviceOrder] for weight, BMI and blood pressure);
///  3. higher coverage, then more samples, then source app name (so the
///     choice is deterministic and repeat uploads pick the same source).
class WearableSourcePolicy {
  const WearableSourcePolicy({
    this.preferredApps = const [],
    this.activityDeviceOrder = const [
      WearableDeviceClass.watch,
      WearableDeviceClass.ring,
      WearableDeviceClass.other,
      WearableDeviceClass.scale,
      WearableDeviceClass.phone,
    ],
    this.bodyDeviceOrder = const [
      WearableDeviceClass.scale,
      WearableDeviceClass.other,
      WearableDeviceClass.watch,
      WearableDeviceClass.ring,
      WearableDeviceClass.phone,
    ],
  });

  final List<String> preferredApps;
  final List<WearableDeviceClass> activityDeviceOrder;
  final List<WearableDeviceClass> bodyDeviceOrder;

  static const _bodyMetrics = {
    WearableMetric.weightKg,
    WearableMetric.bmi,
    WearableMetric.bpSystolic,
    WearableMetric.bpDiastolic,
  };

  int _appRank(String sourceApp) {
    for (var i = 0; i < preferredApps.length; i++) {
      if (sourceApp.startsWith(preferredApps[i])) return i;
    }
    return preferredApps.length;
  }

  int _deviceRank(WearableMetric metric, WearableDeviceClass? device) {
    final order =
        _bodyMetrics.contains(metric) ? bodyDeviceOrder : activityDeviceOrder;
    final i = order.indexOf(device ?? WearableDeviceClass.other);
    return i < 0 ? order.length : i;
  }

  int _compare(_Candidate a, _Candidate b) {
    var c = _appRank(a.row.sourceApp).compareTo(_appRank(b.row.sourceApp));
    if (c != 0) return c;
    c = _deviceRank(a.row.metric, a.row.sourceDevice)
        .compareTo(_deviceRank(b.row.metric, b.row.sourceDevice));
    if (c != 0) return c;
    c = (b.row.coverage ?? 0).compareTo(a.row.coverage ?? 0);
    if (c != 0) return c;
    c = b.sampleCount.compareTo(a.sampleCount);
    if (c != 0) return c;
    return a.row.sourceApp.compareTo(b.row.sourceApp);
  }
}

/// Max gap between two asleep intervals of the same night.
const sleepEpisodeGap = Duration(hours: 3);

/// Aggregates [samples] into daily rows. Only dates in [fromDate]..[toDate]
/// (inclusive, local) are returned when given; read a day earlier than
/// [fromDate] so the first night's sleep is complete.
List<WearableDailyRow> aggregateWearableDaily(
  Iterable<WearableSample> samples, {
  WearableSourcePolicy policy = const WearableSourcePolicy(),
  DateTime? fromDate,
  DateTime? toDate,
}) {
  final from = fromDate == null ? null : _day(fromDate);
  final to = toDate == null ? null : _day(toDate);

  // metric -> source -> samples
  final grouped = <WearableMetric, Map<String, List<WearableSample>>>{};
  for (final s in samples) {
    if (s.sourceApp.isEmpty || s.end.isBefore(s.start)) continue;
    grouped
        .putIfAbsent(s.metric, () => {})
        .putIfAbsent(s.sourceApp, () => [])
        .add(s);
  }

  final candidates = <String, List<_Candidate>>{}; // date|metric -> per-source
  grouped.forEach((metric, bySource) {
    bySource.forEach((sourceApp, list) {
      final device = _deviceOf(list);
      for (final c in _aggregateSource(metric, sourceApp, device, list)) {
        final d = c.row.metricDate;
        if (from != null && d.isBefore(from)) continue;
        if (to != null && d.isAfter(to)) continue;
        if (!metric.isPlausible(c.row.value)) continue;
        candidates
            .putIfAbsent('${c.row.dateKey}|${metric.wireName}', () => [])
            .add(c);
      }
    });
  });

  final rows = <WearableDailyRow>[];
  final keys = candidates.keys.toList()..sort();
  for (final k in keys) {
    final list = candidates[k]!..sort(policy._compare);
    for (var i = 0; i < list.length; i++) {
      rows.add(list[i].row.copyWith(selected: i == 0));
    }
  }
  return rows;
}

class _Candidate {
  _Candidate(this.row, this.sampleCount);
  final WearableDailyRow row;
  final int sampleCount;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
DateTime _nextDay(DateTime d) => DateTime(d.year, d.month, d.day + 1);

double _round(double v, int decimals) {
  final f = math.pow(10, decimals);
  return (v * f).round() / f;
}

WearableDeviceClass? _deviceOf(List<WearableSample> list) {
  // A source app can report several devices; keep the most common class.
  final counts = <WearableDeviceClass, int>{};
  for (final s in list) {
    final d = s.sourceDevice;
    if (d != null) counts[d] = (counts[d] ?? 0) + 1;
  }
  if (counts.isEmpty) return null;
  final entries = counts.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.index.compareTo(b.key.index);
    });
  return entries.first.key;
}

Iterable<_Candidate> _aggregateSource(
  WearableMetric metric,
  String sourceApp,
  WearableDeviceClass? device,
  List<WearableSample> list,
) {
  switch (metric.aggregation) {
    case WearableAggregation.sum:
      return _sum(metric, sourceApp, device, list);
    case WearableAggregation.mean:
      return _mean(metric, sourceApp, device, list);
    case WearableAggregation.last:
      return _last(metric, sourceApp, device, list);
    case WearableAggregation.sleep:
      return _sleep(metric, sourceApp, device, list);
  }
}

/// Summed metrics: a sample that spans midnight is split across the days in
/// proportion to time. Coverage = clock hours of the day holding a sample.
Iterable<_Candidate> _sum(WearableMetric metric, String sourceApp,
    WearableDeviceClass? device, List<WearableSample> list) {
  final totals = <DateTime, double>{};
  final hours = <DateTime, Set<int>>{};
  final counts = <DateTime, int>{};
  // The same record can come back twice (e.g. overlapping read windows).
  final seen = <String>{};
  for (final s in list) {
    if (!s.value.isFinite || s.value < 0) continue;
    final id = '${s.start.microsecondsSinceEpoch}|'
        '${s.end.microsecondsSinceEpoch}|${s.value}';
    if (!seen.add(id)) continue;
    if (!s.end.isAfter(s.start)) {
      final d = _day(s.start);
      totals[d] = (totals[d] ?? 0) + s.value;
      hours.putIfAbsent(d, () => {}).add(s.start.hour);
      counts[d] = (counts[d] ?? 0) + 1;
      continue;
    }
    final total = s.end.difference(s.start).inMicroseconds;
    for (var d = _day(s.start); d.isBefore(s.end); d = _nextDay(d)) {
      final segStart = s.start.isAfter(d) ? s.start : d;
      final next = _nextDay(d);
      final segEnd = s.end.isBefore(next) ? s.end : next;
      final part = segEnd.difference(segStart).inMicroseconds;
      if (part <= 0) continue;
      totals[d] = (totals[d] ?? 0) + s.value * part / total;
      counts[d] = (counts[d] ?? 0) + 1;
      final lastInstant = segEnd.subtract(const Duration(microseconds: 1));
      final hs = hours.putIfAbsent(d, () => {});
      for (var h = segStart.hour; h <= lastInstant.hour; h++) {
        hs.add(h);
      }
    }
  }
  return totals.entries.map((e) => _Candidate(
        WearableDailyRow(
          metricDate: e.key,
          metric: metric,
          value: _round(e.value, metric.decimals),
          sourceApp: sourceApp,
          sourceDevice: device,
          coverage: _round(math.min(1.0, hours[e.key]!.length / 24), 3),
        ),
        counts[e.key]!,
      ));
}

Iterable<_Candidate> _mean(WearableMetric metric, String sourceApp,
    WearableDeviceClass? device, List<WearableSample> list) {
  final byDay = <DateTime, List<double>>{};
  for (final s in list) {
    if (!metric.isPlausible(s.value)) continue;
    byDay.putIfAbsent(_day(s.start), () => []).add(s.value);
  }
  return byDay.entries.map((e) => _Candidate(
        WearableDailyRow(
          metricDate: e.key,
          metric: metric,
          value: _round(e.value.reduce((a, b) => a + b) / e.value.length,
              metric.decimals),
          sourceApp: sourceApp,
          sourceDevice: device,
        ),
        e.value.length,
      ));
}

Iterable<_Candidate> _last(WearableMetric metric, String sourceApp,
    WearableDeviceClass? device, List<WearableSample> list) {
  final latest = <DateTime, WearableSample>{};
  final counts = <DateTime, int>{};
  for (final s in list) {
    if (!metric.isPlausible(s.value)) continue;
    final d = _day(s.start);
    counts[d] = (counts[d] ?? 0) + 1;
    final cur = latest[d];
    if (cur == null || s.start.isAfter(cur.start)) latest[d] = s;
  }
  return latest.entries.map((e) => _Candidate(
        WearableDailyRow(
          metricDate: e.key,
          metric: metric,
          value: _round(e.value.value, metric.decimals),
          sourceApp: sourceApp,
          sourceDevice: device,
        ),
        counts[e.key]!,
      ));
}

class _Interval {
  _Interval(this.start, this.end);
  DateTime start;
  DateTime end;
}

List<_Interval> _union(Iterable<_Interval> input) {
  final sorted = input.where((i) => i.end.isAfter(i.start)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  final out = <_Interval>[];
  for (final i in sorted) {
    if (out.isNotEmpty && !i.start.isAfter(out.last.end)) {
      if (i.end.isAfter(out.last.end)) out.last.end = i.end;
    } else {
      out.add(_Interval(i.start, i.end));
    }
  }
  return out;
}

/// Sleep: asleep intervals (stages) of one source are merged (overlapping
/// stage records never count twice), grouped into episodes (gaps up to
/// [sleepEpisodeGap]), and each wake date keeps its longest episode.
Iterable<_Candidate> _sleep(WearableMetric metric, String sourceApp,
    WearableDeviceClass? device, List<WearableSample> list) {
  final stages = _union(list
      .where((s) => !s.isSleepSession)
      .map((s) => _Interval(s.start, s.end)));
  final asleep = [...stages];
  // A stage-less session counts only where the source has no stages for it.
  for (final s in list.where((s) => s.isSleepSession)) {
    final overlapsStages =
        stages.any((i) => i.start.isBefore(s.end) && s.start.isBefore(i.end));
    if (!overlapsStages) asleep.add(_Interval(s.start, s.end));
  }
  final merged = _union(asleep);

  final nights = <DateTime, double>{};
  final counts = <DateTime, int>{};
  var i = 0;
  while (i < merged.length) {
    var minutes = 0.0;
    var end = merged[i].end;
    var n = 0;
    var j = i;
    while (j < merged.length &&
        (j == i || merged[j].start.difference(end) <= sleepEpisodeGap)) {
      minutes += merged[j].end.difference(merged[j].start).inSeconds / 60;
      end = merged[j].end;
      n++;
      j++;
    }
    final wake = _day(end);
    if (minutes > (nights[wake] ?? -1)) {
      nights[wake] = minutes;
      counts[wake] = n;
    }
    i = j;
  }
  return nights.entries.map((e) => _Candidate(
        WearableDailyRow(
          metricDate: e.key,
          metric: metric,
          value: _round(e.value, metric.decimals),
          sourceApp: sourceApp,
          sourceDevice: device,
        ),
        counts[e.key]!,
      ));
}
