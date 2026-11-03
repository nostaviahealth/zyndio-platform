import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/demo_app.dart';
import 'package:zyndio_patient/demo/router/demo_state.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_state.dart';
import 'package:zyndio_patient/demo/screens/signin/signin_view.dart';

void _noop() {}

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

    testWidgets('locked: shows the countdown lockout copy with a next step', (tester) async {
      // TC-030 item 14: the banner now reports the real remaining minutes and
      // offers an alternative, replacing the fixed "Try again in 15 minutes."
      await tester.pumpWidget(_wrap(SignInView(state: SignInState.locked(minutesRemaining: 12))));

      expect(
        find.text('Too many attempts. Try again in 12 min, or contact your care team.'),
        findsOneWidget,
      );
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
            lockedMinutesRemaining: 15,
          ),
        )),
      );

      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.byKey(const Key('signin-code-locked')), findsOneWidget);
      // TC-030 item 14: countdown copy with a next step, not "15 minutes".
      expect(
        find.text('Too many attempts. Try again in 15 min, or contact your care team.'),
        findsOneWidget,
      );
    });

    testWidgets('TC-030 item 13: the inline code error is wrapped in a live region', (tester) async {
      // Fail-first: before the fix the error was a plain Text, so a screen
      // reader didn't announce "That code isn't right..." when it appeared.
      await tester.pumpWidget(
        _wrap(const SignInView(
          state: SignInState(
            stage: SignInStage.codeEntry,
            email: 'jordan.rivera@example.com',
            code: '000000',
            errorText: "That code isn't right. Check it and try again.",
          ),
        )),
      );

      final liveRegion = tester.widget<Semantics>(
        find.ancestor(
          of: find.byKey(const Key('signin-code-error')),
          matching: find.byType(Semantics),
        ).first,
      );
      expect(liveRegion.properties.liveRegion, isTrue);
    });

    testWidgets('TC-030 item 14: Continue and "Send a new code" are disabled while locked', (tester) async {
      // Fail-first: before the fix both buttons stayed enabled while locked,
      // so a tap still fired (and looked live) with nothing it could do.
      await tester.pumpWidget(
        _wrap(const SignInView(
          state: SignInState(
            stage: SignInStage.codeEntry,
            email: 'jordan.rivera@example.com',
            code: '000000',
            isLocked: true,
            lockedMinutesRemaining: 15,
          ),
          onContinue: _noop,
          onSendNewCode: _noop,
        )),
      );

      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Send a new code')).onPressed,
        isNull,
      );
    });

    testWidgets('TC-030 item 14: Continue and "Send a new code" stay enabled when not locked', (tester) async {
      await tester.pumpWidget(
        _wrap(const SignInView(
          state: SignInState(
            stage: SignInStage.codeEntry,
            email: 'jordan.rivera@example.com',
            code: '000000',
          ),
          onContinue: _noop,
          onSendNewCode: _noop,
        )),
      );

      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed,
        isNotNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Send a new code')).onPressed,
        isNotNull,
      );
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
      await tester.tap(find.text('Continue'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Enter your code'), findsOneWidget);
      expect(find.byKey(const Key('signin-code-locked')), findsOneWidget, reason: 'try ${5 + i}');
      // TC-030 item 14: real countdown (15 min at lock) plus a next step.
      expect(
        find.text('Too many attempts. Try again in 15 min, or contact your care team.'),
        findsOneWidget,
      );
    }
  });

  // TC-030 item 16 (Clara L-r2-2): tap Continue twice on an unchanged full
  // wrong code. The second tap must be handled correctly - it spends a real
  // attempt - and, once the 5 attempts lock the account, Continue must be
  // disabled rather than keep firing.
  testWidgets('TC-030 item 16: tapping Continue twice on an unchanged code spends two attempts and then locks', (tester) async {
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

    // Type the wrong code once, then tap Continue repeatedly WITHOUT editing
    // it. Each tap is a fresh attempt, so five taps lock the account.
    await tester.enterText(find.byType(TextField), '000000');
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.textContaining("isn't right"), findsOneWidget, reason: 'tap ${i + 1}');
      expect(find.byKey(const Key('signin-code-locked')), findsNothing);
    }
    // 5th tap (still the same unchanged code) locks.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('signin-code-locked')), findsOneWidget);

    // Fail-first for item 14: once locked, Continue is disabled, so a further
    // tap can't fire. On the old code the button stayed live.
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed,
      isNull,
    );
  });

  // TC-030 item 17 (Clara L-r2-3): while locked, submitting an incomplete
  // code must render only the lock banner, not also "Enter the 6-digit code."
  // Driven off a locked state built from a short code to prove the view shows
  // the banner alone - the controller guard is covered in the controller test.
  testWidgets('TC-030 item 17: a locked code step with a short code shows only the lock banner', (tester) async {
    await tester.pumpWidget(
      _wrap(const SignInView(
        state: SignInState(
          stage: SignInStage.codeEntry,
          email: 'jordan.rivera@example.com',
          code: '12',
          isLocked: true,
          lockedMinutesRemaining: 15,
        ),
      )),
    );

    expect(find.byKey(const Key('signin-code-locked')), findsOneWidget);
    expect(find.text('Enter the 6-digit code.'), findsNothing);
  });
}
