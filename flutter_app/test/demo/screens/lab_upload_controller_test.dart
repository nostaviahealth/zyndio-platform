@Tags(['demo_flow'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/logic/clock.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';
import 'package:zyndio_patient/demo/screens/lab_upload/lab_upload_controller.dart';
import 'package:zyndio_patient/demo/screens/lab_upload/lab_upload_state.dart';

Uint8List _bytes(String content) => Uint8List.fromList(utf8.encode(content));

void main() {
  group('LabUploadController duplicate detection (T-LAB-03)', () {
    test('same file for the same patient shows the duplicate banner, never blocks', () {
      final backend = DemoBackend(clock: FakeClock(DateTime(2026, 1, 1, 9, 0, 0)));
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(labUploadControllerProvider.notifier);
      final bytes = _bytes('fixture report');

      controller.addFile('report.pdf', bytes);
      expect(container.read(labUploadControllerProvider).banner, LabUploadBannerKind.none);
      expect(container.read(labUploadControllerProvider).rows, hasLength(1));

      // Same file again: warns, but the first upload is still queued/present
      // — the warning never blocks or removes anything.
      controller.addFile('report.pdf', bytes);
      expect(container.read(labUploadControllerProvider).banner, LabUploadBannerKind.duplicate);
      expect(container.read(labUploadControllerProvider).rows, hasLength(1));
    });

    test('"Upload anyway" stores a second item, "Cancel" stores nothing', () {
      final backend = DemoBackend(clock: FakeClock(DateTime(2026, 1, 1, 9, 0, 0)));
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(labUploadControllerProvider.notifier);
      final bytes = _bytes('fixture report');
      controller.addFile('report.pdf', bytes);

      // Cancel: nothing new is stored.
      controller.addFile('report.pdf', bytes);
      controller.cancelDuplicate();
      expect(container.read(labUploadControllerProvider).banner, LabUploadBannerKind.none);
      expect(container.read(labUploadControllerProvider).rows, hasLength(1));

      // Upload anyway: the duplicate is stored too.
      controller.addFile('report.pdf', bytes);
      controller.confirmUploadAnyway();
      expect(container.read(labUploadControllerProvider).rows, hasLength(2));
    });

    test('T-LAB-03 duplicate for a different patient gives no warning', () {
      final backend = DemoBackend(clock: FakeClock(DateTime(2026, 1, 1, 9, 0, 0)));
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(labUploadControllerProvider.notifier);
      final bytes = _bytes('fixture report');

      // Jordan (the default demo session) uploads first.
      controller.addFile('report.pdf', bytes);
      expect(container.read(labUploadControllerProvider).banner, LabUploadBannerKind.none);

      // Switch the active session to a different seeded patient (Sam) and
      // upload the exact same bytes: the hash check is scoped per patient,
      // so this must never warn or hint that Jordan has the same file.
      final repo = container.read(zyndioRepositoryProvider);
      final samEmail = secondaryDemoPatients.first.email;
      repo.sendCode(samEmail);
      final samCode = repo.debugLastIssuedCode(samEmail)!;
      final (result, samSession) = repo.verifyCode(samEmail, samCode);
      expect(result, CodeVerifyResult.success);
      container.read(currentSessionProvider.notifier).set(samSession);

      controller.addFile('report.pdf', bytes);
      expect(container.read(labUploadControllerProvider).banner, LabUploadBannerKind.none);
      expect(container.read(labUploadControllerProvider).rows, hasLength(1));
    });
  });

  group('LabUploadController offline queue (T-LAB-05)', () {
    test('an item added while offline shows "Waiting for connection" and uploads once reconnected', () {
      final backend = DemoBackend(clock: FakeClock(DateTime(2026, 1, 1, 9, 0, 0)));
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final controller = container.read(labUploadControllerProvider.notifier);
      controller.setOnline(false);
      controller.addFile('report.pdf', _bytes('offline report'));

      final queuedState = container.read(labUploadControllerProvider);
      expect(queuedState.banner, LabUploadBannerKind.offline);
      expect(queuedState.rows.single.subline, 'Waiting for connection');

      controller.setOnline(true);
      final onlineState = container.read(labUploadControllerProvider);
      expect(onlineState.banner, LabUploadBannerKind.none);
      expect(onlineState.rows.single.subline, isNot('Waiting for connection'));
    });
  });
}
