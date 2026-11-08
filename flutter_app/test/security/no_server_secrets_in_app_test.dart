// Security: server-side secrets must never be compiled into the patient app.
//
// Anything read with String.fromEnvironment ends up in the shipped binary,
// where it can be extracted. The app used to read GEMINI_API_KEY (sent to
// Google in a URL query), ELEVENLABS_API_KEY and WEARABLES_API_KEY this way.
// Model calls go through the `intelligence` / memory Edge Functions, and the
// wearables client authenticates with the patient's own session token.
//
// Allowed defines are public by design: the Supabase URL + anon key, RevenueCat
// public SDK keys, and the Shopify Storefront token.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const forbidden = <String>[
  'GEMINI_API_KEY',
  'ELEVENLABS_API_KEY',
  'WEARABLES_API_KEY',
  'SERVICE_ROLE',
  'SUPABASE_SERVICE_KEY',
  'REVENUECAT_WEBHOOK_AUTH',
  'OPENAI_API_KEY',
  'JWT_SECRET',
];

Iterable<File> dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  test('no lib/ or wearables package source reads a server-side secret define', () {
    final read = RegExp(r'''fromEnvironment\(\s*['"]([A-Za-z0-9_]+)['"]''');
    final offenders = <String>[];
    var definesSeen = 0;
    for (final root in ['lib', '../packages/platform_wearables/lib']) {
      for (final file in dartFiles(root)) {
        for (final m in read.allMatches(file.readAsStringSync())) {
          definesSeen++;
          final name = m.group(1)!;
          if (forbidden.any(name.contains)) offenders.add('${file.path}: $name');
        }
      }
    }
    // Positive control: the scan really sees the app's defines (SUPABASE_URL etc.).
    expect(definesSeen, greaterThan(0));
    expect(offenders, isEmpty);
  });

  test('dart_defines.example.json lists no server-side secret', () {
    final defines =
        jsonDecode(File('dart_defines.example.json').readAsStringSync()) as Map<String, dynamic>;
    for (final key in defines.keys) {
      for (final name in forbidden) {
        expect(key.contains(name), isFalse, reason: key);
      }
    }
  });
}
