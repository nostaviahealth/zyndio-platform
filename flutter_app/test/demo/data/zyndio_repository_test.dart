import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/data/demo_backend.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/data/supabase_repository.dart';
import 'package:zyndio_patient/demo/data/zyndio_repository.dart';
import 'package:zyndio_patient/demo/providers/demo_providers.dart';

void main() {
  group('zyndioRepositoryProvider', () {
    test('defaults to the offline data source', () {
      expect(dataSource, 'offline');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(zyndioRepositoryProvider), isA<OfflineDemoRepository>());
    });
  });

  group('OfflineDemoRepository', () {
    test('every interface call is scoped by session, mirroring DemoBackend', () {
      final backend = DemoBackend();
      final repo = OfflineDemoRepository(backend);

      repo.sendCode(demoPatient.email);
      final code = repo.debugLastIssuedCode(demoPatient.email)!;
      final (result, session) = repo.verifyCode(demoPatient.email, code);

      expect(result, CodeVerifyResult.success);
      expect(session, isNotNull);
      expect(session!.patientId, isNotEmpty);

      repo.agreeToDoc(session, 'terms');
      expect(repo.consentRecordsFor(session), hasLength(1));
      expect(repo.hba1cTrendFor(session), hba1cTrend);
    });

    test('a different seeded patient never sees the primary patient\'s trend data', () {
      final backend = DemoBackend();
      final repo = OfflineDemoRepository(backend);
      final samEmail = secondaryDemoPatients.first.email;

      repo.sendCode(samEmail);
      final code = repo.debugLastIssuedCode(samEmail)!;
      final (_, session) = repo.verifyCode(samEmail, code);

      expect(repo.hba1cTrendFor(session!), isEmpty);
    });
  });

  group('SupabaseRepository', () {
    test('fails closed when unconfigured, before touching the network', () {
      const repo = SupabaseRepository();
      expect(() => repo.sendCode('x@example.com'), throwsStateError);
      expect(() => repo.verifyCode('x@example.com', '000000'), throwsStateError);
      expect(repo.debugLastIssuedCode('x@example.com'), isNull);
    });
  });
}
