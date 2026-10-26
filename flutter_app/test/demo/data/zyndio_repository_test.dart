import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/data/supabase_repository.dart';
import 'package:zyndio_patient/demo/data/zyndio_repository.dart';
import 'package:zyndio_patient/demo/logic/upload_queue.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';
import 'package:zyndio_patient/demo/storage/file_queue_store.dart';

void main() {
  group('zyndioRepositoryProvider', () {
    test('defaults to the offline data source', () {
      expect(dataSource, 'offline');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(zyndioRepositoryProvider), isA<OfflineDemoRepository>());
    });
  });

  group('OfflineDemoRepository', () {
    test(
      'every interface call is scoped by session, mirroring DemoBackend',
      tags: ['demo_flow'],
      () {
      final backend = DemoBackend();
      final repo = OfflineDemoRepository(backend);

      repo.sendCode(demoPatient.email);
      final code = repo.debugLastIssuedCode(demoPatient.email)!;
      final (result, session) = repo.verifyCode(demoPatient.email, code);

      expect(result, CodeVerifyResult.success);
      expect(session, isNotNull);
      expect(session!.patientId, isNotEmpty);

      repo.agreeToDoc(session, 'terms');
      expect(repo.consentRecordsFor(session), hasLength(1));
      expect(repo.hba1cTrendFor(session), hba1cTrend);
    });

    test(
      'a different seeded patient never sees the primary patient\'s trend data',
      tags: ['demo_flow'],
      () {
      final backend = DemoBackend();
      final repo = OfflineDemoRepository(backend);
      final samEmail = secondaryDemoPatients.first.email;

      repo.sendCode(samEmail);
      final code = repo.debugLastIssuedCode(samEmail)!;
      final (_, session) = repo.verifyCode(samEmail, code);

      expect(repo.hba1cTrendFor(session!), isEmpty);
    });

    test(
      'T-LAB-05: a queued upload survives a fresh OfflineDemoRepository on '
      'the same app-private dir (app kill)',
      tags: ['demo_flow'],
      () {
        final tempDir = Directory.systemTemp.createTempSync('zyndio_repository_test');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        QueueStore storeFor(String patientId) => FileQueueStore.forPatient(tempDir, patientId);

        final repoA = OfflineDemoRepository(DemoBackend(), queueStoreFor: storeFor);
        repoA.sendCode(demoPatient.email);
        final codeA = repoA.debugLastIssuedCode(demoPatient.email)!;
        final (_, sessionA) = repoA.verifyCode(demoPatient.email, codeA);

        final queueA = repoA.uploadQueueFor(sessionA!);
        queueA.isOnline = false;
        final item = queueA.enqueue('lab-report.jpg');
        expect(item.status, UploadStatus.queued);

        // "App kill": a brand-new backend + repository, same app-private dir.
        final repoB = OfflineDemoRepository(DemoBackend(), queueStoreFor: storeFor);
        repoB.sendCode(demoPatient.email);
        final codeB = repoB.debugLastIssuedCode(demoPatient.email)!;
        final (_, sessionB) = repoB.verifyCode(demoPatient.email, codeB);

        final queueB = repoB.uploadQueueFor(sessionB!);
        expect(queueB.items, hasLength(1));
        expect(queueB.items.single.fileName, 'lab-report.jpg');
        expect(queueB.items.single.status, UploadStatus.queued);
        expect(queueB.labelFor(queueB.items.single), UploadQueue.waitingForConnectionLabel);
      },
    );
  });

  group('SupabaseRepository', () {
    test('fails closed when unconfigured, before touching the network', () {
      const repo = SupabaseRepository();
      expect(() => repo.sendCode('x@example.com'), throwsStateError);
      expect(() => repo.verifyCode('x@example.com', '000000'), throwsStateError);
      expect(repo.debugLastIssuedCode('x@example.com'), isNull);
    });
  });
}
