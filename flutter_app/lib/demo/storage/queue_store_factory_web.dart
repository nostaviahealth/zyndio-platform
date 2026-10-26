import '../logic/upload_queue.dart';

/// Web stub: no app-private filesystem to persist to, so the web demo keeps
/// the in-memory [QueueStore] ([OfflineDemoRepository]'s default).
Future<QueueStore Function(String patientId)?> resolveQueueStoreFactory() async => null;
