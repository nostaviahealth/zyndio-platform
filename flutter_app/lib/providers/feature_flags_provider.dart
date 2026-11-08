import 'package:flutter_riverpod/flutter_riverpod.dart';

/// TC-025 patient feature flags (specs §11, Z2).
///
/// Both flags default to **false** for the 7 Nov store build:
/// * [patientExtrasEnabled] — Shop, Meditate, Cycle Tracking (hidden, not deleted).
/// * [longevityScoreEnabled] — the Today Longevity ring (hidden until Zyndio
///   supplies a formula/value).
/// * [appointmentsEnabled] — Appointments booking. Still backed by
///   MockAppointmentRepository (fictional doctors and slots), so it must not
///   reach store users; its routes redirect to Today and its entry points
///   (Progress "Book my baseline scan", Care "Appointments") are hidden.
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
    this.appointmentsEnabled = false,
    this.recoveryScoreEnabled = false,
  });

  final bool patientExtrasEnabled;
  final bool longevityScoreEnabled;
  final bool appointmentsEnabled;

  /// Today's Recovery tile. Off until a validated recovery source exists
  /// (TC-025 guardrail: never shown from an app-derived composite).
  final bool recoveryScoreEnabled;

  /// Compile-time defaults. Off unless explicitly enabled at build time.
  static const FeatureFlags compileDefaults = FeatureFlags(
    patientExtrasEnabled:
        bool.fromEnvironment('PATIENT_EXTRAS_ENABLED', defaultValue: false),
    longevityScoreEnabled:
        bool.fromEnvironment('LONGEVITY_SCORE_ENABLED', defaultValue: false),
    appointmentsEnabled:
        bool.fromEnvironment('APPOINTMENTS_ENABLED', defaultValue: false),
    recoveryScoreEnabled:
        bool.fromEnvironment('RECOVERY_SCORE_ENABLED', defaultValue: false),
  );

  FeatureFlags copyWith({
    bool? patientExtrasEnabled,
    bool? longevityScoreEnabled,
    bool? appointmentsEnabled,
    bool? recoveryScoreEnabled,
  }) =>
      FeatureFlags(
        patientExtrasEnabled: patientExtrasEnabled ?? this.patientExtrasEnabled,
        longevityScoreEnabled:
            longevityScoreEnabled ?? this.longevityScoreEnabled,
        appointmentsEnabled: appointmentsEnabled ?? this.appointmentsEnabled,
        recoveryScoreEnabled: recoveryScoreEnabled ?? this.recoveryScoreEnabled,
      );
}

/// Resolved patient feature flags. No remote source exists yet, so this returns
/// the compile-time defaults (false). Override in tests / a future remote
/// config loader.
final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => FeatureFlags.compileDefaults,
);
