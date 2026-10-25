// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meditation_state_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MeditationNotifier)
final meditationProvider = MeditationNotifierProvider._();

final class MeditationNotifierProvider
    extends $NotifierProvider<MeditationNotifier, MeditationState> {
  MeditationNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'meditationProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$meditationNotifierHash();

  @$internal
  @override
  MeditationNotifier create() => MeditationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MeditationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MeditationState>(value),
    );
  }
}

String _$meditationNotifierHash() =>
    r'5a8039d8b4b8d255678b4054efad11ef0dc99a8b';

abstract class _$MeditationNotifier extends $Notifier<MeditationState> {
  MeditationState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<MeditationState, MeditationState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<MeditationState, MeditationState>,
        MeditationState,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
