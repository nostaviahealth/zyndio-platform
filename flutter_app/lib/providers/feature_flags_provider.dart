import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TC-025 patient feature flags (specs §11, Z2).
///
/// Both flags default to **false** for the 7 Nov store build:
/// * [patientExtrasEnabled] — Shop, Meditate, Cycle Tracking (hidden, not deleted).
/// * [longevityScoreEnabled] — the Today Longevity ring (hidden until Zyndio
///   supplies a formula/value).
///
/// The compile-time defaults can only ever turn a flag **on** via an explicit
/// `--dart-define`; the safe default is always off. There is no remote/org
/// config source in the app today (see QUESTIONS.md), so the flags resolve to
/// the compile-time defaults and fall back to false on any future fetch/parse
/// error. The provider is a plain [Provider] so tests (and a future remote
/// source) can override it.
class FeatureFlags {
  const FeatureFlags({
    this.patientExtrasEnabled = false,
    this.longevityScoreEnabled = false,
  });

  final bool patientExtrasEnabled;
  final bool longevityScoreEnabled;

  /// Compile-time defaults. Off unless explicitly enabled at build time.
  static const FeatureFlags compileDefaults = FeatureFlags(
    patientExtrasEnabled:
        bool.fromEnvironment('PATIENT_EXTRAS_ENABLED', defaultValue: false),
    longevityScoreEnabled:
        bool.fromEnvironment('LONGEVITY_SCORE_ENABLED', defaultValue: false),
  );

  FeatureFlags copyWith({
    bool? patientExtrasEnabled,
    bool? longevityScoreEnabled,
  }) =>
      FeatureFlags(
        patientExtrasEnabled: patientExtrasEnabled ?? this.patientExtrasEnabled,
        longevityScoreEnabled:
            longevityScoreEnabled ?? this.longevityScoreEnabled,
      );
}

/// Resolved patient feature flags. No remote source exists yet, so this returns
/// the compile-time defaults (false). Override in tests / a future remote
/// config loader.
final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => FeatureFlags.compileDefaults,
);
