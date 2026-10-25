import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo/demo_app.dart';

/// Separate entrypoint for the fully offline, fictional-data demo build.
/// Production `main.dart` (Supabase/Firebase) is never touched or started.
void main() {
  runApp(const ProviderScope(child: DemoApp()));
}
