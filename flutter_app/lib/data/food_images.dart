import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/supabase_config.dart';

/// APP-08: meal photos live in the PRIVATE `food-images` bucket under the
/// patient's own folder (`<patient_id>/<name>`), on the same model as lab
/// reports (TC-036). Screens show them through short-lived signed links made
/// on demand; a link is never stored or logged.
const foodImagesBucket = 'food-images';
const foodImageLinkLifetime = Duration(minutes: 10);

final _objectPathPattern = RegExp(r'^[0-9a-f-]{36}/[A-Za-z0-9_][A-Za-z0-9._-]*$');

/// A signed link to a meal photo, or '' when there is none (empty or
/// malformed path, a legacy full URL, or storage refused). Storage checks the
/// caller's access (storage.objects RLS) before signing.
final foodImageUrlProvider = FutureProvider.autoDispose.family<String, String>((ref, path) async {
  if (!_objectPathPattern.hasMatch(path) || path.contains('..')) return '';
  final client = SupabaseConfig.client;
  if (client == null) return '';
  try {
    return await client.storage
        .from(foodImagesBucket)
        .createSignedUrl(path, foodImageLinkLifetime.inSeconds);
  } catch (_) {
    return '';
  }
});
