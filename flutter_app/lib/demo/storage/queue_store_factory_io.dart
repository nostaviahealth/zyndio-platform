import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logic/upload_queue.dart';
import 'file_queue_store.dart';

/// Resolves a [FileQueueStore]-backed factory rooted in an `upload_queue`
/// subdirectory of the app-private support directory, so queued uploads
/// survive an app kill. Falls back to `null` (in-memory) if the directory
/// can't be resolved or created — the demo must still start.
Future<QueueStore Function(String patientId)?> resolveQueueStoreFactory() async {
  try {
    final supportDir = await getApplicationSupportDirectory();
    final queueDir = Directory('${supportDir.path}/upload_queue')
      ..createSync(recursive: true);
    return (patientId) => FileQueueStore.forPatient(queueDir, patientId);
  } catch (e) {
    developer.log(
      'Falling back to in-memory upload queue storage',
      name: 'queue_store_factory_io',
      error: e.runtimeType.toString(),
    );
    return null;
  }
}
