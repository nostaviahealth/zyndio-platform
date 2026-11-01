// TC-026 card item 2 / required test (a): purchase_provider.dart must never
// write is_premium/subscription_plan to Supabase from the client - the
// column-level revoke in the patient_accounts migration means it can't
// anymore, and only the service-role RevenueCat webhook may set them.
//
// Drives PurchaseNotifier through a real expiration-detected cycle (profile
// says Plus, RevenueCat says Free, boot-grace period elapsed) using a mocked
// purchases_flutter platform channel (the plugin boundary - not the thing
// under test) and the shared FakeSupabaseRest harness, then asserts no
// request body sent to Supabase ever contains the premium columns.
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/supabase_config.dart';
import 'package:zyndio_patient/main.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/providers/purchase_provider.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/fake_supabase_rest.dart';

const _patientId = '00000000-0000-0000-0000-0000000a2001';
const _purchasesChannel = MethodChannel('purchases_flutter');

Future<void> _signInAndWaitForUser(ProviderContainer container, FakeSupabaseRest fake, SupabaseClient client) async {
  container.listen(currentUserProvider, (_, __) {});
  await fake.signIn(client, _patientId);
  for (var i = 0; i < 200; i++) {
    if (container.read(currentUserProvider) != null) return;
    await Future.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('currentUserProvider never saw the signed-in user');
}

Map<String, dynamic> _customerInfoJson({required bool plusActive}) => {
      'entitlements': {
        'all': plusActive
            ? {
                'Zyndio Plus': {
                  'identifier': 'Zyndio Plus',
                  'isActive': true,
                  'willRenew': true,
                  'periodType': 'NORMAL',
                  'latestPurchaseDate': '2024-01-01T00:00:00Z',
                  'originalPurchaseDate': '2024-01-01T00:00:00Z',
                  'productIdentifier': 'plus_monthly',
                  'isSandbox': false,
                  'store': 'PLAY_STORE',
                  'ownershipType': 'PURCHASED',
                },
              }
            : {},
        'active': plusActive
            ? {
                'Zyndio Plus': {
                  'identifier': 'Zyndio Plus',
                  'isActive': true,
                  'willRenew': true,
                  'periodType': 'NORMAL',
                  'latestPurchaseDate': '2024-01-01T00:00:00Z',
                  'originalPurchaseDate': '2024-01-01T00:00:00Z',
                  'productIdentifier': 'plus_monthly',
                  'isSandbox': false,
                  'store': 'PLAY_STORE',
                  'ownershipType': 'PURCHASED',
                },
              }
            : {},
      },
      'allPurchaseDates': <String, String?>{},
      'activeSubscriptions': <String>[],
      'allPurchasedProductIdentifiers': <String>[],
      'nonSubscriptionTransactions': <dynamic>[],
      'firstSeen': '2024-01-01T00:00:00Z',
      'originalAppUserId': _patientId,
      'allExpirationDates': <String, String?>{},
      'requestDate': '2024-01-01T00:00:00Z',
    };

/// Mocks the purchases_flutter plugin boundary (not the thing under test) so
/// PurchaseNotifier can run its real reconciliation logic with no entitlement
/// on RevenueCat's side, deterministically.
void _installFreeRevenueCatMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_purchasesChannel, (call) async {
    switch (call.method) {
      case 'logIn':
        return {'customerInfo': _customerInfoJson(plusActive: false), 'created': false};
      case 'getCustomerInfo':
        return _customerInfoJson(plusActive: false);
      case 'getOfferings':
        return {'all': <String, dynamic>{}};
      case 'getAppUserID':
        return _patientId;
      case 'syncPurchases':
        return _customerInfoJson(plusActive: false);
      default:
        return null;
    }
  });
}

class _FixedPatientProfileNotifier extends PatientProfileNotifier {
  _FixedPatientProfileNotifier(this._profile);
  final PatientProfile _profile;

  @override
  Future<PatientProfile?> build() async => _profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    SupabaseConfig.debugClientOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_purchasesChannel, null);
  });

  test(
    'detecting an expired manual-grant profile against a Free RevenueCat status never writes premium columns to Supabase',
    () async {
      final fake = FakeSupabaseRest();
      _installFreeRevenueCatMock();

      await http.runWithClient(() async {
        final client = fake.buildClient();
        SupabaseConfig.debugClientOverride = client;

        // Profile says Plus with no active manual-grant expiry (so RC=Free,
        // profile=Plus is read as "needs downgrade", the same branch a real
        // expired subscription takes) - this is the one path in
        // purchase_provider.dart that used to write back to Supabase.
        final fixedProfile = PatientProfile(
          id: _patientId,
          userId: _patientId,
          name: 'Fictional Patient',
          isPremium: true,
          subscriptionPlan: 'plus',
        );

        final container = ProviderContainer(overrides: [
          supabaseInitializedProvider.overrideWithValue(true),
          patientProfileProvider.overrideWith(() => _FixedPatientProfileNotifier(fixedProfile)),
        ]);
        addTearDown(container.dispose);

        await _signInAndWaitForUser(container, fake, client);

        final notifier = container.read(purchaseProvider.notifier);
        // Let build()'s Future.microtask(_init) run its course.
        await Future.delayed(const Duration(milliseconds: 100));

        // _init()'s own reconciliation lands inside the 3s boot-grace window,
        // which trusts the (stale) Plus profile and never reaches the
        // downgrade branch - wait it out, then force a second pass the same
        // way an app resume does, so the expiration path actually runs.
        await Future.delayed(const Duration(seconds: 4));
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future.delayed(const Duration(milliseconds: 200));

        final allWrites = fake.requests.where((r) => r.method != 'GET' && r.url.path.startsWith('/rest/v1/'));
        for (final r in allWrites) {
          final body = r is http.Request ? r.body : '';
          expect(body, isNot(contains('is_premium')), reason: 'request to ${r.url.path}: $body');
          expect(body, isNot(contains('subscription_plan')), reason: 'request to ${r.url.path}: $body');
        }
      }, () => fake.mockClient);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
