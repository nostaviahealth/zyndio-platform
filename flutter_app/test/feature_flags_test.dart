import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/providers/feature_flags_provider.dart';

void main() {
  group('featureFlagsProvider', () {
    test('both flags default to false (store build)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final flags = container.read(featureFlagsProvider);
      expect(flags.patientExtrasEnabled, isFalse);
      expect(flags.longevityScoreEnabled, isFalse);
      expect(flags.appointmentsEnabled, isFalse);
    });

    test('compileDefaults are false', () {
      expect(FeatureFlags.compileDefaults.patientExtrasEnabled, isFalse);
      expect(FeatureFlags.compileDefaults.longevityScoreEnabled, isFalse);
      expect(FeatureFlags.compileDefaults.appointmentsEnabled, isFalse);
    });

    test('is overridable (for a future remote source / tests)', () {
      final container = ProviderContainer(overrides: [
        featureFlagsProvider.overrideWithValue(
          const FeatureFlags(patientExtrasEnabled: true),
        ),
      ]);
      addTearDown(container.dispose);
      final flags = container.read(featureFlagsProvider);
      expect(flags.patientExtrasEnabled, isTrue);
      expect(flags.longevityScoreEnabled, isFalse);
    });
  });
}
