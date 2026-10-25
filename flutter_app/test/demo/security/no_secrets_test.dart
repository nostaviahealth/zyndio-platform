import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Key-like literals that must never appear in source or a built bundle.
/// Keep this list obviously generic (no real secret), so matching it can't
/// itself leak anything.
const List<String> _secretLikePatterns = [
  'service_role',
  'supabase.co',
  'eyJhbGci', // JWT header prefix shared by Supabase anon/service keys
  'sk-', // common API-key prefix (OpenAI etc.)
];

Directory _findProjectRoot() {
  var dir = Directory.current;
  while (!File(p.join(dir.path, 'pubspec.yaml')).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not locate flutter_app (pubspec.yaml not found).');
    }
    dir = parent;
  }
  return dir;
}

List<String> _scan(Directory dir) {
  final hits = <String>[];
  if (!dir.existsSync()) return hits;
  for (final entity in dir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    // Binary assets (fonts, images, wasm, maps) can contain incidental byte
    // sequences that happen to decode as these substrings; scan only the
    // text-ish source/bundle files that could plausibly embed a literal key.
    const scannableExtensions = {'.dart', '.js', '.json', '.html', '.css', '.txt'};
    if (!scannableExtensions.contains(p.extension(entity.path))) continue;
    final content = entity.readAsStringSync();
    for (final pattern in _secretLikePatterns) {
      if (content.contains(pattern)) {
        hits.add('${entity.path}: contains "$pattern"');
      }
    }
  }
  return hits;
}

void main() {
  test('no key-like literals in lib/', () {
    final root = _findProjectRoot();
    final hits = _scan(Directory(p.join(root.path, 'lib')));
    expect(hits, isEmpty, reason: hits.join('\n'));
  });

  test('no key-like literals in the built web bundle, if it exists', () {
    final root = _findProjectRoot();
    final buildWeb = Directory(p.join(root.path, 'build', 'web'));
    if (!buildWeb.existsSync()) {
      // Nothing to check until `flutter build web` has been run; this test
      // still runs (and passes trivially) so CI doesn't need a conditional.
      return;
    }
    final hits = _scan(buildWeb);
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
