import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';
import '../data/body_composition.dart';

/// The signed-in patient's bound scans. RLS decides which rows exist.
/// No client when Supabase is not configured: an empty list, not sample scans.
final bodyCompositionScansProvider =
    FutureProvider<List<StoredBodyScan>>((ref) async {
  final client = SupabaseConfig.client;
  if (client == null) return const [];
  final rows = await client
      .from('body_composition_scans')
      .select('scan_date,device_vendor,device_model,software_version,measures')
      .order('scan_date', ascending: false);
  return parseStoredBodyScans(rows);
});
