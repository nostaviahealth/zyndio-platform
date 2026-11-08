import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/models/patient_profile.dart';
import 'package:zyndio_patient/providers/feature_flags_provider.dart';
import 'package:zyndio_patient/providers/patient_provider.dart';
import 'package:zyndio_patient/screens/settings/settings_screen.dart';

class _Profile extends PatientProfileNotifier {
  @override
  Future<PatientProfile?> build() async =>
      PatientProfile(id: 'p1', name: 'Jordan Rivera');
}

Future<void> _pump(WidgetTester tester,
    {Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = const Size(402 * 3, 2600 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Widget dest(String t) => Scaffold(body: Text(t));
  final router = GoRouter(initialLocation: '/settings', routes: [
    GoRoute(path: '/', builder: (c, s) => dest('HOME')),
    GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (c, s) => const SettingsScreen()),
    GoRoute(path: '/delete-account', builder: (c, s) => dest('DELETE')),
    GoRoute(
        path: '/settings/partner_outcomes',
        builder: (c, s) => dest('PARTNER OUTCOMES')),
    GoRoute(
        path: '/settings/edit_profile', builder: (c, s) => dest('EDIT')),
    GoRoute(path: '/login', builder: (c, s) => dest('LOGIN')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      featureFlagsProvider.overrideWithValue(const FeatureFlags()),
      patientProfileProvider.overrideWith(_Profile.new),
    ],
    child: MaterialApp.router(
      theme: brightness == Brightness.light
          ? BrandTheme.lightTheme
          : BrandTheme.darkTheme,
      routerConfig: router,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('programme-first sections; consumer extras hidden by default',
      (tester) async {
    await _pump(tester);
    expect(find.text('Profile & settings'), findsOneWidget);
    expect(find.text('Jordan Rivera'), findsOneWidget);
    for (final label in [
      'YOUR RECORDS',
      'PRIVACY AND SHARING',
      'NOTIFICATIONS',
      'HELP',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Partner outcomes sharing'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    // Flag off: no membership upsell, wellness tools or shop.
    expect(find.text('Membership'), findsNothing);
    expect(find.text('WELLNESS TOOLS'), findsNothing);
    expect(find.text('Leagues and rewards'), findsNothing);
    expect(find.text('MORE FROM ZYNDIO'), findsNothing);
  });

  testWidgets('delete account opens the deletion request', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('DELETE'), findsOneWidget);
  });

  testWidgets('partner outcomes sharing is one tap away', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Partner outcomes sharing'));
    await tester.pumpAndSettle();
    expect(find.text('PARTNER OUTCOMES'), findsOneWidget);
  });

  testWidgets('edit profile opens the profile form', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    expect(find.text('EDIT'), findsOneWidget);
  });

  testWidgets('sign out asks first; cancel keeps you here', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
  });

  testWidgets('renders in dark mode without layout errors', (tester) async {
    await _pump(tester, brightness: Brightness.dark);
    expect(tester.takeException(), isNull);
  });
}
