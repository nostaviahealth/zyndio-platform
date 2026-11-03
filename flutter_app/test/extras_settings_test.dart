import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/feature_flags_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/screens/settings/settings_screen.dart';

/// A4: "More from Zyndio" (Shop / Meditate / Cycle Tracking) lives behind the
/// patient-extras flag. These prove the flag gates the settings rows; the
/// flag-off deep-link redirects to Today are covered in tc025_shell_test.dart.

class _Profile extends PatientProfileNotifier {
  _Profile(this.gender);
  final String? gender;
  @override
  Future<PatientProfile?> build() async => PatientProfile(
        id: 'p1',
        name: 'Jordan Rivera',
        questionnaireData: gender == null ? null : {'gender': gender},
      );
}

Future<void> _pump(
  WidgetTester tester, {
  required bool extras,
  String? gender,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => const Scaffold(
          body: SingleChildScrollView(child: MoreFromZyndioSection()),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        featureFlagsProvider
            .overrideWithValue(FeatureFlags(patientExtrasEnabled: extras)),
        patientProfileProvider.overrideWith(() => _Profile(gender)),
      ],
      child: MaterialApp.router(
        theme: BrandTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('flag off: no More from Zyndio section or extra rows',
      (tester) async {
    await _pump(tester, extras: false, gender: 'Female');
    expect(find.text('MORE FROM ZYNDIO'), findsNothing);
    expect(find.text('Shop'), findsNothing);
    expect(find.text('Meditate'), findsNothing);
    expect(find.text('Cycle Tracking'), findsNothing);
  });

  testWidgets('flag on, female: Shop + Meditate + Cycle Tracking', (tester) async {
    await _pump(tester, extras: true, gender: 'Female');
    expect(find.text('MORE FROM ZYNDIO'), findsOneWidget);
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Meditate'), findsOneWidget);
    expect(find.text('Cycle Tracking'), findsOneWidget);
  });

  testWidgets('flag on, male: Cycle Tracking hidden', (tester) async {
    await _pump(tester, extras: true, gender: 'Male');
    expect(find.text('Shop'), findsOneWidget);
    expect(find.text('Meditate'), findsOneWidget);
    expect(find.text('Cycle Tracking'), findsNothing);
  });
}
