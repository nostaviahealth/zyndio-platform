// TC-026: protocol_provider.dart (ProtocolNotifier.fetchLibrary) and
// protocol_progress_provider.dart (ProtocolProgressNotifier._computeAdherence,
// via its local-cache fallback path) used the same "look up profiles.id by
// user_id" indirection as protocol_repository.dart. Same fix: use the auth
// user id directly, no profiles lookup.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/main.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/providers/blueprint_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/providers/protocol_progress_provider.dart';
import 'package:zyndio_patient/providers/protocol_provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_supabase_rest.dart';

const _patientId = '00000000-0000-0000-0000-0000000a6001';

Future<void> _signInAndWaitForUser(ProviderContainer container, FakeSupabaseRest fake, SupabaseClient client) async {
  container.listen(currentUserProvider, (_, __) {});
  await fake.signIn(client, _patientId);
  for (var i = 0; i < 200; i++) {
    if (container.read(currentUserProvider) != null) return;
    await Future.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('currentUserProvider never saw the signed-in user');
}

class _FixedPatientProfileNotifier extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async => PatientProfile(id: _patientId, userId: _patientId, name: 'Fictional Patient');
}

/// No cloud blueprint - forces ProtocolProgressNotifier down its legacy
/// SharedPreferences-seeded path (see setUp below), the one that still does
/// the profiles lookup today.
class _NoBlueprintNotifier extends BlueprintNotifier {
  @override
  BlueprintState build() => const BlueprintState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
  });

  test('ProtocolNotifier.fetchLibrary() never queries profiles to resolve a profile id', () async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeSupabaseRest();
    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;

      final container = ProviderContainer(overrides: [
        supabaseInitializedProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);

      await _signInAndWaitForUser(container, fake, client);
      container.read(protocolProvider); // triggers build() -> _init() -> fetchLibrary()
      await Future.delayed(const Duration(milliseconds: 200));

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
    }, () => fake.mockClient);
  });

  test('ProtocolProgressNotifier adherence calc never queries profiles to resolve a profile id', () async {
    // Seeds the legacy SharedPreferences path _init() falls back to when
    // there's no cloud blueprint, with a start date 5 days in the past so
    // the elapsed window is non-zero and _computeAdherence actually reaches
    // its Supabase/local-fallback code.
    final startDate = DateTime.now().subtract(const Duration(days: 5));
    SharedPreferences.setMockInitialValues({
      'protocol_start_date_protocol-1': startDate.toIso8601String(),
      'protocol_duration_weeks_protocol-1': 12,
    });
    final fake = FakeSupabaseRest();
    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;

      final container = ProviderContainer(overrides: [
        supabaseInitializedProvider.overrideWithValue(true),
        patientProfileProvider.overrideWith(() => _FixedPatientProfileNotifier()),
        blueprintProvider.overrideWith(() => _NoBlueprintNotifier()),
      ]);
      addTearDown(container.dispose);

      await _signInAndWaitForUser(container, fake, client);
      container.read(protocolProgressProvider); // triggers build() -> _init() -> _computeAdherence()
      await Future.delayed(const Duration(milliseconds: 200));

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
    }, () => fake.mockClient);
  });
}
