// Client walkthrough (19 Nov 2026): the companion offers "Supplements for My
// Labs" once blood work is uploaded, and "What does my longevity score
// mean?" once there is a score; its CTA opens Precision Nutrition.
// Fictional data only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/models/lab_report.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/chat_provider.dart';
import 'package:zyndio_patient/providers/feature_flags_provider.dart';
import 'package:zyndio_patient/providers/lab_reports_provider.dart';
import 'package:zyndio_patient/providers/longevity_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/providers/protocol_provider.dart';
import 'package:zyndio_patient/providers/suggestion_provider.dart';
import 'package:zyndio_patient/screens/chat/chat_cta_strip.dart';

class _NoProfile extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async => null;
}

class _NoProtocol extends ProtocolNotifier {
  @override
  ProtocolState build() => const ProtocolState();
}

LabReport _report() => LabReport(
      id: 'r1',
      date: '2026-11-01',
      title: 'Fictional panel',
      summary: '',
      markers: [
        LabMarker(
            name: 'Vitamin D', value: '22', range: '30-100', status: 'Low'),
      ],
    );

Future<List<String>> _chipIds(
    {required bool labs, int? score, bool scoreFlag = true}) async {
  final container = ProviderContainer(overrides: [
    patientProfileProvider.overrideWith(() => _NoProfile()),
    protocolProvider.overrideWith(() => _NoProtocol()),
    labReportsProvider
        .overrideWith((ref) async => labs ? [_report()] : <LabReport>[]),
    featureFlagsProvider.overrideWithValue(FeatureFlags.compileDefaults
        .copyWith(longevityScoreEnabled: scoreFlag)),
    longevityScoreProvider.overrideWithValue(
        score == null ? null : LongevityScore(score: score)),
  ]);
  addTearDown(container.dispose);
  // Riverpod pauses providers nobody listens to, so listen before awaiting.
  final sub = container.listen(suggestionProvider, (_, __) {});
  container.listen(labReportsProvider, (_, __) {});
  await container.read(labReportsProvider.future);
  return sub.read().map((s) => s.id).toList();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uploaded blood work brings the supplements chip near the front',
      () async {
    final ids = await _chipIds(labs: true);
    expect(ids.take(2), ['analyze_labs', 'supplements_for_labs']);
  });

  test('no blood work, no supplements chip', () async {
    expect(await _chipIds(labs: false), isNot(contains('supplements_for_labs')));
  });

  test('a longevity score adds "what does my score mean"', () async {
    final ids = await _chipIds(labs: true, score: 84);
    expect(ids, contains('longevity_score_meaning'));
    expect(ids.length, lessThanOrEqualTo(4));
  });

  test('no score chip while the score is switched off, like Today', () async {
    final ids = await _chipIds(labs: true, score: 84, scoreFlag: false);
    expect(ids, isNot(contains('longevity_score_meaning')));
  });

  testWidgets('the navigate_to_supplements CTA opens Precision Nutrition',
      (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: ChatCtaStrip(actions: [
            CtaAction(label: 'See Zyndio supplements', action: 'navigate_to_supplements'),
          ]),
        ),
      ),
      GoRoute(
        path: '/supplements',
        builder: (_, __) => const Scaffold(body: Text('Precision Nutrition')),
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(
        theme: BrandTheme.lightTheme, routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See Zyndio supplements'));
    await tester.pumpAndSettle();
    expect(find.text('Precision Nutrition'), findsOneWidget);
  });
}
