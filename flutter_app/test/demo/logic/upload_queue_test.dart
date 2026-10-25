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
}
