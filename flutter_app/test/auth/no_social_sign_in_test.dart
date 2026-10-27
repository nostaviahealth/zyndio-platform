import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/screens/auth/login_screen.dart';
import 'package:zyndio_patient/screens/auth/signup_screen.dart';

/// Clara H-M1: patient auth is email+password only. Social / ID-token
/// sign-in skips patient-signup (no self-signup marker, no password /
/// email-verification / rate-limit checks) and must not ship.
void main() {
  Widget wrap(Widget child) => ProviderScope(
      child: MaterialApp(theme: BrandTheme.lightTheme, home: child));

  group('LoginScreen offers email+password only (H-M1)', () {
    testWidgets('no Google or Apple button and no social entry point', (tester) async {
      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.pump();

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('or'), findsNothing);
      expect(find.byIcon(Icons.apple), findsNothing);
      // Email + password fields still present.
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  });

  group('SignupScreen offers email+password only (H-M1)', () {
    testWidgets('no Google or Apple button and no social entry point', (tester) async {
      await tester.pumpWidget(wrap(const SignupScreen()));
      await tester.pump();

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('or'), findsNothing);
    });
  });

  group('lib/ forbids social / ID-token sign-in (H-M1 grep guard)', () {
    test('no signInWithIdToken / OAuth / Google / Apple in patient lib/', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue, reason: 'run from flutter_app/');

      const forbidden = <String>[
        'signInWithIdToken',
        'signInWithOAuth',
        'signInWithGoogle',
        'signInWithApple',
        'GoogleSignIn',
        'SignInWithApple',
        'package:google_sign_in',
        'package:sign_in_with_apple',
      ];

      final hits = <String>[];
      for (final f in lib.listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final body = f.readAsStringSync();
        for (final needle in forbidden) {
          if (body.contains(needle)) {
            hits.add('${f.path}: $needle');
          }
        }
      }
      expect(hits, isEmpty, reason: 'social/ID-token sign-in must not ship:\n${hits.join('\n')}');
    });
  });
}
