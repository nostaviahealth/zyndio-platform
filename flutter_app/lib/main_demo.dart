import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'demo/demo_app.dart';
import 'demo/providers/demo_providers.dart';
import 'demo/storage/queue_store_factory_web.dart'
    if (dart.library.io) 'demo/storage/queue_store_factory_io.dart';

/// Separate entrypoint for the fully offline, fictional-data demo build.
/// Production `main.dart` (Supabase/Firebase) is never touched or started.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Non-web only (see queue_store_factory_web.dart): resolves an app-private
  // file-backed upload queue so a queued item survives an app kill. `null`
  // on web, or if the directory can't be resolved, keeps the in-memory
  // default.
  final queueStoreFactory = await resolveQueueStoreFactory();
  runApp(
    ProviderScope(
      overrides: [
        if (queueStoreFactory != null)
          queueStoreFactoryProvider.overrideWithValue(queueStoreFactory),
      ],
      child: const DemoApp(),
    ),
  );
}
