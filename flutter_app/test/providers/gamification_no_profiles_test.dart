// TC-026: gamification_provider.dart (GamificationNotifier.refresh) and
// gamification_service.dart (fetchBalance, fetchStandings) must read
// patient_accounts (xp/coins/league_xp/league_badges, and the
// patient_leaderboard_top10() RPC for cross-patient standings), never the
// removed profiles table.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/main.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/providers/gamification_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/services/gamification_service.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_supabase_rest.dart';

const _patientId = '00000000-0000-0000-0000-0000000a3001';

Future<void> _signInAndWaitForUser(ProviderContainer container, FakeSupabaseRest fake, SupabaseClient client) async {
  container.listen(currentUserProvider, (_, __) {});
  await fake.signIn(client, _patientId);
  for (var i = 0; i < 200; i++) {
    if (container.read(currentUserProvider) != null) return;
    await Future.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('currentUserProvider never saw the signed-in user');
}

class _NullProfileNotifier extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
  });

  test('GamificationService.fetchBalance() touches patient_accounts, not profiles', () async {
    final fake = FakeSupabaseRest();
    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;
      await fake.signIn(client, _patientId);
      await client.auth.setSession('fake-refresh-token');

      await GamificationService.fetchBalance();

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
      expect(fake.tableNames, contains('patient_accounts'), reason: fake.tableNames.toString());
    }, () => fake.mockClient);
  });

  test('GamificationService.fetchStandings() calls patient_leaderboard_top10(), not profiles', () async {
    final fake = FakeSupabaseRest();
    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;
      await fake.signIn(client, _patientId);
      await client.auth.setSession('fake-refresh-token');

      await GamificationService.fetchStandings(League.bronze);

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
      expect(
        fake.tableNames.any((t) => t.startsWith('rpc/patient_leaderboard_top10')),
        isTrue,
        reason: fake.tableNames.toString(),
      );
    }, () => fake.mockClient);
  });

  test('fetchStandings() maps is_me and never exposes a user/patient id', () async {
    final fake = FakeSupabaseRest();
    fake.rpcResponses['patient_leaderboard_top10'] = [
      {'name': 'Casey L.', 'avatar_url': null, 'league_xp': 70, 'is_me': false},
      {'name': 'Jordan R.', 'avatar_url': null, 'league_xp': 50, 'is_me': true},
    ];
    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;
      await fake.signIn(client, _patientId);
      await client.auth.setSession('fake-refresh-token');

      final standings = await GamificationService.fetchStandings(League.bronze);

      expect(standings, hasLength(2));
      expect(standings.map((r) => r['name']), ['Casey L.', 'Jordan R.']);
      expect(standings.map((r) => r['is_me']), [false, true]);
      expect(standings.map(GamificationService.isLeaderboardSelf), [false, true]);
      for (final r in standings) {
        expect(r.containsKey('user_id'), isFalse, reason: r.toString());
        expect(r.containsKey('patient_id'), isFalse, reason: r.toString());
      }
    }, () => fake.mockClient);
  });

  test('isLeaderboardSelf() is true only for is_me == true', () {
    expect(GamificationService.isLeaderboardSelf({'is_me': true}), isTrue);
    expect(GamificationService.isLeaderboardSelf({'is_me': false}), isFalse);
    expect(GamificationService.isLeaderboardSelf({'is_me': null}), isFalse);
    expect(GamificationService.isLeaderboardSelf(<String, dynamic>{}), isFalse);
    // A stray id that happens to equal the signed-in user's id must not
    // highlight a row - only the server's is_me flag does.
    expect(GamificationService.isLeaderboardSelf({'user_id': _patientId}), isFalse);
    expect(GamificationService.standingFromRow({'name': 'X', 'patient_id': _patientId, 'is_me': 'true'}),
        {'name': 'X', 'avatar_url': null, 'league_xp': null, 'is_me': false});
  });

  test('GamificationNotifier.refresh() touches patient_accounts, not profiles', () async {
    final fake = FakeSupabaseRest();
    await http.runWithClient(() async {
      final client = fake.buildClient();
      SupabaseConfig.debugClientOverride = client;

      final container = ProviderContainer(overrides: [
        supabaseInitializedProvider.overrideWithValue(true),
        patientProfileProvider.overrideWith(() => _NullProfileNotifier()),
      ]);
      addTearDown(container.dispose);

      await _signInAndWaitForUser(container, fake, client);
      await container.read(gamificationProvider.notifier).refresh();

      expect(fake.tableNames, isNot(contains('profiles')), reason: fake.tableNames.toString());
      final reads = fake.requestsFor('patient_accounts').where((r) => r.method == 'GET');
      expect(reads, isNotEmpty, reason: fake.tableNames.toString());
      for (final r in reads) {
        expect(r.url.query, contains('patient_id'));
      }
    }, () => fake.mockClient);
  });
}
