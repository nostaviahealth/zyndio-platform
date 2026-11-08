// Security: the production router must fail closed when Supabase is not set up.
//
// It used to treat "Supabase not initialised" as demo mode and return null from
// the redirect, so a build without SUPABASE_URL / SUPABASE_ANON_KEY (or one
// whose Supabase setup threw) opened Today, Biomarkers, Settings, Chat... with
// no session at all.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/routes.dart';
import 'package:zyndio_patient/main.dart' show supabaseInitializedProvider;
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/screens/common/service_unavailable_screen.dart';

void main() {
  group('backendReadyRedirect (pure rule)', () {
    test('without a backend every in-app location goes to the unavailable screen', () {
      for (final loc in [
        '/',
        '/biomarkers',
        '/my-plan',
        '/care',
        '/progress',
        '/settings',
        '/chat',
        '/delete-account',
        '/login',
      ]) {
        expect(backendReadyRedirect(loc, backendReady: false), kServiceUnavailablePath,
            reason: loc);
      }
    });

    test('without a backend the unavailable screen itself stays put', () {
      expect(backendReadyRedirect(kServiceUnavailablePath, backendReady: false), isNull);
    });

    test('with a backend it never interferes, and the unavailable screen leaves', () {
      expect(backendReadyRedirect('/', backendReady: true), isNull);
      expect(backendReadyRedirect('/login', backendReady: true), isNull);
      expect(backendReadyRedirect(kServiceUnavailablePath, backendReady: true), '/');
    });
  });

  test('isDemoModeProvider is not derived from Supabase being uninitialised', () {
    final container = ProviderContainer(overrides: [
      supabaseInitializedProvider.overrideWithValue(false),
    ]);
    addTearDown(container.dispose);
    expect(container.read(isDemoModeProvider), isFalse);
  });

  testWidgets('router with no backend lands on the unavailable screen, not Today',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [supabaseInitializedProvider.overrideWithValue(false)],
        child: Consumer(
          builder: (context, ref, _) =>
              MaterialApp.router(routerConfig: ref.watch(routerProvider)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ServiceUnavailableScreen), findsOneWidget);
    final router = ProviderScope.containerOf(
      tester.element(find.byType(ServiceUnavailableScreen)),
    ).read(routerProvider);
    expect(router.routerDelegate.currentConfiguration.uri.path, kServiceUnavailablePath);

    router.go('/biomarkers');
    await tester.pump();
    expect(router.routerDelegate.currentConfiguration.uri.path, kServiceUnavailablePath);
  });
}
