import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/demo_build_flag.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';

/// Finding 4 / plan D+F.5: the demo's plaintext-code debug hook and
/// silent-auto-sign-in fallback must compile out of every non-demo build.
/// `kDemoBuild` is only ever `true` when the app is built/run with
/// `--dart-define=DEMO_BUILD=true` (the demo entrypoint); the default
/// `flutter test` invocation (and the production app) never sets it.
void main() {
  test('kDemoBuild is false under the default test invocation', () {
    expect(kDemoBuild, isFalse);
  });

  test('debugLastIssuedCode throws when not a demo build', () {
    final backend = DemoBackend();
    expect(
      () => backend.debugLastIssuedCode('jordan@example.test'),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('requireDemoSession throws when not a demo build', () {
    final refProvider = Provider<Ref>((ref) => ref);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ref = container.read(refProvider);

    expect(
      () => requireDemoSession(ref),
      throwsA(isA<UnsupportedError>()),
    );
  });
}
