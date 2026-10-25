import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/logic/upload_queue.dart';

void main() {
  group('UploadQueue', () {
    test('offline enqueue shows "Waiting for connection"', () {
      final queue = UploadQueue(isOnline: false);
      final item = queue.enqueue('lab-report.jpg');

      expect(item.status, UploadStatus.queued);
      expect(queue.labelFor(item), 'Waiting for connection');
    });

    test('retry succeeds when connectivity returns', () {
      final queue = UploadQueue(isOnline: false);
      final item = queue.enqueue('lab-report.jpg');
      expect(item.status, UploadStatus.queued);

      queue.setOnline(true);
      expect(item.status, UploadStatus.uploading);

      queue.markSaved(item.id);
      expect(item.status, UploadStatus.saved);
    });

    test('online enqueue starts uploading immediately', () {
      final queue = UploadQueue(isOnline: true);
      final item = queue.enqueue('lab-report.jpg');
      expect(item.status, UploadStatus.uploading);
    });
  });

  group('UploadQueue persistence (T-LAB-05)', () {
    test('a queued item survives a new UploadQueue instance (app kill/reopen)', () {
      final store = InMemoryQueueStore();
      final queue = UploadQueue(isOnline: false, store: store);
      final item = queue.enqueue('lab-report.jpg');
      expect(queue.labelFor(item), UploadQueue.waitingForConnectionLabel);

      // "App kill/reopen": a brand-new UploadQueue built on the same
      // app-private store, not the same in-memory instance.
      final reopened = UploadQueue(isOnline: false, store: store);
      expect(reopened.items, hasLength(1));
      expect(reopened.items.single.fileName, 'lab-report.jpg');
      expect(reopened.labelFor(reopened.items.single), UploadQueue.waitingForConnectionLabel);
    });

    test('uploads exactly once on reconnect even if reconnect fires twice', () {
      final store = InMemoryQueueStore();
      final queue = UploadQueue(isOnline: false, store: store);
      final item = queue.enqueue('lab-report.jpg');

      queue.setOnline(true);
      expect(item.status, UploadStatus.uploading);
      queue.markSaved(item.id);

      // A second reconnect event must not re-queue or re-upload an item
      // that's already saved.
      queue.setOnline(false);
      queue.setOnline(true);
      expect(item.status, UploadStatus.saved);

      final reopened = UploadQueue(isOnline: true, store: store);
      expect(reopened.items.single.status, UploadStatus.saved);
    });
  });
}
