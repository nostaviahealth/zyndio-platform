import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/storage/file_queue_store.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('file_queue_store_test');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('FileQueueStore', () {
    test('load() on a missing file returns an empty queue', () {
      final store = FileQueueStore.forPatient(tempDir, 'patient-0');
      expect(store.load(), isEmpty);
    });

    test('save() then load() round-trips the queue contents', () {
      final store = FileQueueStore.forPatient(tempDir, 'patient-0');
      final items = [
        {'id': 'upload-0', 'fileName': 'lab-report.jpg', 'status': 'queued'},
      ];

      store.save(items);

      expect(store.load(), items);
    });

    test('save() is atomic: no .tmp file remains afterwards', () {
      final store = FileQueueStore.forPatient(tempDir, 'patient-0');
      store.save([
        {'id': 'upload-0', 'fileName': 'lab-report.jpg', 'status': 'queued'},
      ]);

      final files = tempDir.listSync().map((f) => f.path).toList();
      expect(files.where((p) => p.endsWith('.tmp')), isEmpty);
      expect(files.where((p) => p.endsWith('upload_queue_patient-0.json')), hasLength(1));
    });

    test('corrupt file contents -> load() returns empty, never throws', () {
      final store = FileQueueStore.forPatient(tempDir, 'patient-0');
      File('${tempDir.path}/upload_queue_patient-0.json').writeAsStringSync('not json {{{');

      expect(store.load, returnsNormally);
      expect(store.load(), isEmpty);
    });

    test('wrong JSON shape (not a list) -> load() returns empty, never throws', () {
      final store = FileQueueStore.forPatient(tempDir, 'patient-0');
      File('${tempDir.path}/upload_queue_patient-0.json').writeAsStringSync('{"not": "a list"}');

      expect(store.load, returnsNormally);
      expect(store.load(), isEmpty);
    });

    test('patient ids are sanitised to a safe file name', () {
      final store = FileQueueStore.forPatient(tempDir, 'patient/0 weird?.id');
      store.save([
        {'id': 'upload-0', 'fileName': 'lab-report.jpg', 'status': 'queued'},
      ]);

      final names = tempDir.listSync().map((f) => f.uri.pathSegments.last);
      expect(names, contains(matches(RegExp(r'^upload_queue_[A-Za-z0-9_-]+\.json$'))));
    });

    test('patient isolation: another patient on the same directory has an empty queue', () {
      final storeA = FileQueueStore.forPatient(tempDir, 'patient-0');
      storeA.save([
        {'id': 'upload-0', 'fileName': 'lab-report.jpg', 'status': 'queued'},
      ]);

      final storeB = FileQueueStore.forPatient(tempDir, 'patient-1');
      expect(storeB.load(), isEmpty);
    });
  });
}
