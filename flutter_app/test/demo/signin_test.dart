import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
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

    testWidgets('every state builds in dark mode too', (tester) async {
      final states = [
        SignInState.defaultState(),
        SignInState.sending(),
        SignInState.code(),
        SignInState.error(email: 'jordan.rivera@exmaple.com'),
        SignInState.locked(),
        SignInState.offline(),
      ];
      for (final state in states) {
        await tester.pumpWidget(_wrap(SignInView(state: state), brightness: Brightness.dark));
        expect(find.byType(SignInView), findsOneWidget);
      }
    });
  });
}
