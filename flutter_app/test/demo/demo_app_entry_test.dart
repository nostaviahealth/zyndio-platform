import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/demo/demo_app.dart';
import 'package:zyndio_patient/demo/router/demo_state.dart';
import 'package:zyndio_patient/demo/screens/flow_router.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_view.dart';

/// TC-029 (BUG-2): native builds have no web URL query string, so `?flow=` and
/// `?screen=` are both absent and screen choice used to fall through to the
/// "Zyndio demo — coming soon" placeholder. With no deep-link, the app must now
/// open the real entry (the sign-in journey); web `?flow=`/`?screen=` routing
/// is unchanged.
Future<void> _pump(WidgetTester tester, DemoRouteParams params) async {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(child: DemoApp(initialParams: params)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('DemoApp entry screen', () {
    testWidgets('no query params (native build) opens the real sign-in journey, not the placeholder', (tester) async {
      // Fail-first: before TC-029 this showed "Zyndio demo — coming soon".
      await _pump(tester, const DemoRouteParams());

      expect(find.text('Zyndio demo — coming soon'), findsNothing);
      expect(find.byType(DemoJourneyFlow), findsOneWidget);
      expect(find.text('Sign in to your care program'), findsOneWidget);
    });

    testWidgets('web ?flow=journey still opens the journey', (tester) async {
      await _pump(tester, const DemoRouteParams(flow: 'journey'));

      expect(find.byType(DemoJourneyFlow), findsOneWidget);
      expect(find.text('Sign in to your care program'), findsOneWidget);
      expect(find.text('Zyndio demo — coming soon'), findsNothing);
    });

    testWidgets('web ?screen=signin still opens the single interactive sign-in screen', (tester) async {
      await _pump(tester, const DemoRouteParams(screen: 'signin'));

      // The single-screen route, not the multi-step journey.
      expect(find.byType(DemoJourneyFlow), findsNothing);
      expect(find.byType(SignInView), findsOneWidget);
      expect(find.text('Sign in to your care program'), findsOneWidget);
      expect(find.text('Zyndio demo — coming soon'), findsNothing);
    });

    testWidgets('web ?screen=<unknown> still shows its "coming soon" placeholder', (tester) async {
      await _pump(tester, const DemoRouteParams(screen: 'zzz'));

      expect(find.text('Screen "zzz" coming soon'), findsOneWidget);
      expect(find.byType(DemoJourneyFlow), findsNothing);
    });
  });
}
