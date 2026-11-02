import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/demo_app.dart';
import 'package:zyndio_patient/demo/router/demo_state.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_state.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_view.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? BrandTheme.lightTheme : BrandTheme.darkTheme,
    home: child,
  );
}

void main() {
  group('SignInView', () {
    testWidgets('default: shows the intro copy, empty focused field and info card', (tester) async {
      await tester.pumpWidget(_wrap(SignInView(state: SignInState.defaultState())));

      expect(find.text('Sign in to your care program'), findsOneWidget);
      expect(
        find.textContaining("We'll send a 6-digit code. No password needed."),
        findsOneWidget,
      );
      expect(
        find.textContaining('New to Zyndio? Accounts are created by your care team when you enroll.'),
        findsOneWidget,
      );
      expect(find.text('Send code'), findsOneWidget);
    });

    testWidgets('sending: shows the busy label and ignores repeat taps', (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(
        _wrap(SignInView(state: SignInState.sending(), onSendCode: () => tapCount++)),
      );

      expect(find.text('Sending code'), findsOneWidget);
      await tester.tap(find.text('Sending code'), warnIfMissed: false);
      await tester.tap(find.text('Sending code'), warnIfMissed: false);
      expect(tapCount, 0);
    });

    testWidgets('code: shows the 10-minute expiry copy and masked email', (tester) async {
      await tester.pumpWidget(_wrap(SignInView(state: SignInState.code())));

      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.textContaining('Code expires after 10 minutes.'), findsOneWidget);
      expect(find.textContaining('j•••••@example.com.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Send a new code'), findsOneWidget);
    });

    testWidgets('error: shows the inline error and hides the info card', (tester) async {
      await tester.pumpWidget(
        _wrap(SignInView(state: SignInState.error(email: 'jordan.rivera@exmaple.com'))),
      );

      expect(
        find.textContaining("We couldn't find an enrolment for this email."),
        findsOneWidget,
      );
      expect(find.textContaining('New to Zyndio?'), findsNothing);
    });

    testWidgets('locked: shows the 15-minute lockout copy', (tester) async {
      await tester.pumpWidget(_wrap(SignInView(state: SignInState.locked())));

      expect(find.text('Too many attempts. Try again in 15 minutes.'), findsOneWidget);
    });

    testWidgets('offline: shows the offline banner and still allows sending', (tester) async {
      await tester.pumpWidget(_wrap(SignInView(state: SignInState.offline())));

      expect(
        find.text("You're offline. Connect to the internet to get your code."),
        findsOneWidget,
      );
      expect(find.text('Send code'), findsOneWidget);
    });

    testWidgets('TC-029: an error on the code step renders the inline message under the code field', (tester) async {
      // Fail-first: before TC-029 the code step passed only `hasError` to
      // CodeInput and never rendered `errorText`, so a wrong code showed no
      // message at all (BUG-1 in the TC-028 recording).
      const message = "That code isn't right. Check it and try again.";
      await tester.pumpWidget(
        _wrap(const SignInView(
          state: SignInState(
            stage: SignInStage.codeEntry,
            email: 'jordan.rivera@example.com',
            code: '000000',
            errorText: message,
          ),
        )),
      );

      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.byKey(const Key('signin-code-error')), findsOneWidget);
      expect(find.text(message), findsOneWidget);
    });

    testWidgets('TC-029 review (Clara H2): a locked account shows the lock message on the code step itself', (tester) async {
      // Fail-first: before the fix the "Too many attempts" banner rendered
      // only on the email step, so from the 5th wrong try Continue looked dead.
      await tester.pumpWidget(
        _wrap(const SignInView(
          state: SignInState(
            stage: SignInStage.codeEntry,
            email: 'jordan.rivera@example.com',
            code: '000000',
            isLocked: true,
          ),
        )),
      );

      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.byKey(const Key('signin-code-locked')), findsOneWidget);
      expect(find.text('Too many attempts. Try again in 15 minutes.'), findsOneWidget);
    });

    testWidgets('every state builds in dark mode too', (tester) async {
      final states = [
        SignInState.defaultState(),
        SignInState.sending(),
        SignInState.code(),
        SignInState.error(email: 'jordan.rivera@exmaple.com'),
        SignInState.locked(),
        SignInState.offline(),
        const SignInState(stage: SignInStage.codeEntry, email: 'jordan.rivera@example.com', isLocked: true),
      ];
      for (final state in states) {
        await tester.pumpWidget(_wrap(SignInView(state: state), brightness: Brightness.dark));
        expect(find.byType(SignInView), findsOneWidget);
      }
    });
  });

  // End-to-end BUG-1 repro through the real controller + offline backend: a
  // wrong code typed on the interactive sign-in screen must surface an inline
  // error, not fail silently. Uses the default offline repository (no issued
  // code needed since any wrong entry is invalid), so it runs under the plain
  // `flutter test` gate without DEMO_BUILD.
  testWidgets('TC-029 BUG-1: a wrong code on the interactive sign-in shows an inline error', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: DemoApp(initialParams: DemoRouteParams(screen: 'signin')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('signin-email-field')), 'jordan.rivera@example.com');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();

    expect(find.text('Enter your code'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Still on the code step, now with the inline error visible.
    expect(find.text('Enter your code'), findsOneWidget);
    expect(find.byKey(const Key('signin-code-error')), findsOneWidget);
    expect(find.textContaining("isn't right"), findsOneWidget);
  });

  // End-to-end Clara H2 repro through the real controller + offline backend:
  // keep typing wrong codes past the 5-attempt limit and the code step itself
  // must say the account is locked. Also: incomplete entries on the way must
  // not count as attempts (3 short taps first, then 5 wrong codes to lock).
  testWidgets('TC-029 review (Clara H2): wrong codes to lockout show the lock message on the code screen', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: DemoApp(initialParams: DemoRouteParams(screen: 'signin')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('signin-email-field')), 'jordan.rivera@example.com');
    await tester.pump();
    await tester.tap(find.text('Send code'));
    await tester.pump();
    expect(find.text('Enter your code'), findsOneWidget);

    // Incomplete entries: inline hint, no attempt used.
    for (final entry in ['', '12', '12345']) {
      await tester.enterText(find.byType(TextField), entry);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter the 6-digit code.'), findsOneWidget, reason: 'entry "$entry"');
      expect(find.byKey(const Key('signin-code-locked')), findsNothing);
    }

    // Four wrong codes: still the "isn't right" error, not locked yet.
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining("isn't right"), findsOneWidget, reason: 'wrong try ${i + 1}');
      expect(find.byKey(const Key('signin-code-locked')), findsNothing);
    }

    // 5th wrong code locks; the code screen must say so, and keep saying so.
    for (var i = 0; i < 2; i++) {
      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.byKey(const Key('signin-code-locked')), findsOneWidget, reason: 'try ${5 + i}');
      expect(find.text('Too many attempts. Try again in 15 minutes.'), findsOneWidget);
    }
  });
}
