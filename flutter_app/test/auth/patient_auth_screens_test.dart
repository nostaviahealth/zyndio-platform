import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/screens/auth/delete_account_screen.dart';
import 'package:zyndio_patient/screens/auth/forgot_password_screen.dart';
import 'package:zyndio_patient/screens/auth/signup_screen.dart';
import 'package:zyndio_patient/screens/auth/verify_email_screen.dart';
import 'package:zyndio_patient/widgets/password_rules_checklist.dart';

Widget _wrap(Widget child) =>
    ProviderScope(child: MaterialApp(home: child));

void main() {
  group('checkPasswordRules (TC-011/TC-012 shared 5 rules)', () {
    test('rejects a password missing length/case/digit/symbol', () {
      final checks = checkPasswordRules('short');
      expect(checks.allClientRulesMet, isFalse);
      expect(checks.length, isFalse);
    });

    test('accepts a password meeting every client-checkable rule', () {
      final checks = checkPasswordRules('Correct-Horse-Battery9');
      expect(checks.length, isTrue);
      expect(checks.hasCase, isTrue);
      expect(checks.digit, isTrue);
      expect(checks.symbol, isTrue);
      expect(checks.allClientRulesMet, isTrue);
    });

    test('requires both upper and lower case, not just mixed-looking text', () {
      expect(checkPasswordRules('alllowercase123!').hasCase, isFalse);
      expect(checkPasswordRules('ALLUPPERCASE123!').hasCase, isFalse);
    });
  });

  testWidgets('PasswordRulesChecklist collapses to one line once every rule (incl. server) passes',
      (tester) async {
    await tester.pumpWidget(_wrap(
      const PasswordRulesChecklist(password: 'Correct-Horse-Battery9', commonPasswordOk: true),
    ));
    expect(find.text('Your password meets every rule'), findsOneWidget);
    expect(find.text('12+ characters'), findsNothing);
  });

  testWidgets('PasswordRulesChecklist lists unmet rules while the password is still weak',
      (tester) async {
    await tester.pumpWidget(_wrap(const PasswordRulesChecklist(password: 'short')));
    expect(find.text('12+ characters'), findsOneWidget);
    expect(find.text('Not commonly used'), findsOneWidget);
    expect(find.text('Your password meets every rule'), findsNothing);
  });

  group('SignupScreen (PSU-PW-01)', () {
    testWidgets('shows the live password checklist and blocks submit on a weak password',
        (tester) async {
      await tester.pumpWidget(_wrap(const SignupScreen()));
      await tester.enterText(find.byType(TextFormField).at(0), 'Jordan Rivera');
      await tester.enterText(find.byType(TextFormField).at(1), 'jordan.rivera@example.test');
      await tester.enterText(find.byType(TextFormField).at(2), 'short');
      await tester.pump();

      expect(find.text('12+ characters'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
      await tester.pump();

      expect(find.text('Your password needs to meet every rule below'), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen (PSU-ENUM-03)', () {
    testWidgets('always shows the generic "if an account exists" copy after submit',
        (tester) async {
      await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
      await tester.enterText(find.byType(TextFormField), 'jordan.rivera@example.test');
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining("If there's an account for"), findsOneWidget);
    });
  });

  group('DeleteAccountScreen (PSU-DEL-01, Apple 5.1.1(v))', () {
    testWidgets('requires reauth before showing the destructive confirm step', (tester) async {
      await tester.pumpWidget(_wrap(const ProviderScope(child: DeleteAccountScreen())));
      expect(find.text('Delete my account'), findsNothing);

      await tester.enterText(find.byType(TextFormField), 'Testpassw0rd!123');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Delete my account'), findsOneWidget);
      expect(find.textContaining('clinic records stay with your clinic'), findsOneWidget);
    });

    testWidgets('"Keep my account" is reachable without confirming deletion', (tester) async {
      await tester.pumpWidget(_wrap(const ProviderScope(child: DeleteAccountScreen())));
      await tester.enterText(find.byType(TextFormField), 'Testpassw0rd!123');
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Keep my account'), findsOneWidget);
    });
  });

  group('VerifyEmailScreen (PSU-EV, 60s resend cooldown)', () {
    testWidgets('shows the sent copy and starts the cooldown after a manual resend',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const ProviderScope(child: VerifyEmailScreen(email: 'jordan.rivera@example.test')),
      ));
      expect(find.textContaining('We sent a confirmation link'), findsOneWidget);

      await tester.tap(find.text('Resend email'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.textContaining('Resend email in 1:00'), findsOneWidget);
    });
  });
}
