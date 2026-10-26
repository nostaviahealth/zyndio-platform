@Tags(['demo_flow'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/logic/clock.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';
import 'package:zyndio_patient/demo/screens/lab_trends/lab_trends_controller.dart';

void main() {
  group('LabTrendsController', () {
    test('the default demo session reads the fixture patient\'s own 4-point trend', () {
      final backend = DemoBackend(clock: FakeClock(DateTime(2026, 1, 1, 9, 0, 0)));
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      container.read(labTrendsControllerProvider.notifier).refresh();
      final state = container.read(labTrendsControllerProvider);

      expect(state.points, hba1cTrend);
      expect(state.isLoading, isFalse);
      expect(state.isSingle, isFalse);
    });

    test('T-BIO-03 a different seeded patient with no trend data never sees Jordan\'s points', () {
      final backend = DemoBackend(clock: FakeClock(DateTime(2026, 1, 1, 9, 0, 0)));
      final container = ProviderContainer(
        overrides: [demoBackendProvider.overrideWithValue(backend)],
      );
      addTearDown(container.dispose);

      final repo = container.read(zyndioRepositoryProvider);
      final samEmail = secondaryDemoPatients.first.email;
      repo.sendCode(samEmail);
      final samCode = repo.debugLastIssuedCode(samEmail)!;
      final (result, samSession) = repo.verifyCode(samEmail, samCode);
      expect(result, CodeVerifyResult.success);
      container.read(currentSessionProvider.notifier).set(samSession);

      container.read(labTrendsControllerProvider.notifier).refresh();
      final state = container.read(labTrendsControllerProvider);

      expect(state.points, isNot(hba1cTrend));
      expect(state.isLoading, isTrue);
    });
  });
}
