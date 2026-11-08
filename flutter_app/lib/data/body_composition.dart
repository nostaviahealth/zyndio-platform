/// A body-composition scan as stored. Values are the partner payload, not
/// a score or a clinical interpretation.
class StoredBodyScan {
  const StoredBodyScan({
    required this.scanDate,
    required this.deviceVendor,
    required this.deviceModel,
    required this.softwareVersion,
    required this.measures,
  });

  final String scanDate;
  final String deviceVendor;
  final String deviceModel;
  final String softwareVersion;

  /// Stored measure name and the value exactly as persisted, as text.
  final List<({String name, String value})> measures;

  String get deviceLine {
    final parts = [deviceVendor, deviceModel, softwareVersion]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    return parts.join(' · ');
  }
}

/// Parses rows from `body_composition_scans`. Drops rows that are not objects.
/// Does not invent a number when `measures` is missing.
List<StoredBodyScan> parseStoredBodyScans(Object? rows) {
  if (rows is! List) return const [];
  final out = <StoredBodyScan>[];
  for (final row in rows) {
    if (row is! Map) continue;
    final measures = <({String name, String value})>[];
    final raw = row['measures'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final name = entry.key.toString().trim();
        if (name.isEmpty || entry.value == null) continue;
        measures.add((name: name, value: '${entry.value}'));
      }
    }
    out.add(StoredBodyScan(
      scanDate: '${row['scan_date'] ?? ''}'.trim(),
      deviceVendor: '${row['device_vendor'] ?? ''}'.trim(),
      deviceModel: '${row['device_model'] ?? ''}'.trim(),
      softwareVersion: '${row['software_version'] ?? ''}'.trim(),
      measures: measures,
    ));
  }
  return out;
}
