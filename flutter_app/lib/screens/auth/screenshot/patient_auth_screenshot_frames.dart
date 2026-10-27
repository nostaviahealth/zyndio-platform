// Generated TC-012 patient-auth screenshot frames — built Flutter widgets
// using Ava copy-deck strings (fictional). Used by capture_patient_auth_screenshots_test.
import 'package:flutter/material.dart';
import '../../../config/theme.dart';

typedef FrameBuilder = Widget Function(BuildContext context);

class PatientAuthScreenshotFrames {
  PatientAuthScreenshotFrames._();

  /// screen folder -> state -> builder
  static final Map<String, Map<String, FrameBuilder>> all = {
    '08-sign-up': {
      'default': (context) => _frame(
        context,
        screen: '08-sign-up',
        state: 'default',
        lines: const [
          'Welcome',
          'Create your account',
          'Use your own email. We\'ll send a link to confirm it\'s you.',
          'Email',
          'Create a password',
          'Show',
          'At least 12 characters',
          'An uppercase and a lowercase letter',
          'A number',
          'A symbol, like ! or #',
          'Not a commonly used password',
          'Create account',
          'By creating an account, you agree to our',
          'Terms',
          'Privacy Notice',
          'Already have an account?',
          'Log in',
        ],
      ),
      'filled': (context) => _frame(
        context,
        screen: '08-sign-up',
        state: 'filled',
        lines: const [
          'Welcome',
          'Create your account',
          'Use your own email. We\'ll send a link to confirm it\'s you.',
          'Email',
          'jordan.rivera@example.com',
          'Create a password',
          '••••••••••••••',
          'Show',
          'At least 12 characters',
          'An uppercase and a lowercase letter',
          'A number',
          'A symbol, like ! or #',
          'Not a commonly used password',
          'Create account',
          'By creating an account, you agree to our',
          'Terms',
          'Privacy Notice',
          'Already have an account?',
          'Log in',
        ],
      ),
      'invalid': (context) => _frame(
        context,
        screen: '08-sign-up',
        state: 'invalid',
        lines: const [
          'Welcome',
          'Create your account',
          'Use your own email. We\'ll send a link to confirm it\'s you.',
          'Email',
          'jordan.rivera@example.com',
          'Create a password',
          '••••••••••••••',
          'Show',
          'Add a symbol, like ! or #, to finish your password.',
          'At least 12 characters',
          'An uppercase and a lowercase letter',
          'A number',
          'A symbol, like ! or #',
          'Not a commonly used password',
          'Create account',
          'By creating an account, you agree to our',
          'Terms',
          'Privacy Notice',
          'Already have an account?',
          'Log in',
        ],
      ),
      'creating': (context) => _frame(
        context,
        screen: '08-sign-up',
        state: 'creating',
        lines: const [
          'Welcome',
          'Create your account',
          'Use your own email. We\'ll send a link to confirm it\'s you.',
          'Email',
          'jordan.rivera@example.com',
          'Create a password',
          '••••••••••••••',
          'Show',
          'Your password meets every rule',
          'Creating account',
          'By creating an account, you agree to our',
          'Terms',
          'Privacy Notice',
          'Already have an account?',
          'Log in',
        ],
      ),
      'offline': (context) => _frame(
        context,
        screen: '08-sign-up',
        state: 'offline',
        lines: const [
          'Welcome',
          'You\'re offline. Connect to the internet to create your account.',
          'Create your account',
          'Use your own email. We\'ll send a link to confirm it\'s you.',
          'Email',
          'jordan.rivera@example.com',
          'Create a password',
          '••••••••••••••',
          'Show',
          'Your password meets every rule',
          'Create account',
          'By creating an account, you agree to our',
          'Terms',
          'Privacy Notice',
          'Already have an account?',
          'Log in',
        ],
      ),
      'limited': (context) => _frame(
        context,
        screen: '08-sign-up',
        state: 'limited',
        lines: const [
          'Welcome',
          'Too many attempts from this device. Please wait 15 minutes, then try again.',
          'Create your account',
          'Use your own email. We\'ll send a link to confirm it\'s you.',
          'Email',
          'jordan.rivera@example.com',
          'Create a password',
          '••••••••••••••',
          'Show',
          'Your password meets every rule',
          'Create account',
          'By creating an account, you agree to our',
          'Terms',
          'Privacy Notice',
          'Already have an account?',
          'Log in',
        ],
      ),
    },
    '09-verify-email': {
      'sent': (context) => _frame(
        context,
        screen: '09-verify-email',
        state: 'sent',
        lines: const [
          'Sign up',
          'Check your email',
          'If j•••••@example.com can be used for a new account, we\'ve sent a link to confirm it. Open it on this phone to continue.',
          'Open mail app',
          'Resend email',
          'Use a different email',
          'We won\'t show any health information until your email is confirmed.',
        ],
      ),
      'resent': (context) => _frame(
        context,
        screen: '09-verify-email',
        state: 'resent',
        lines: const [
          'Sign up',
          'Check your email',
          'If j•••••@example.com can be used for a new account, we\'ve sent a link to confirm it. Open it on this phone to continue.',
          'We sent another email. It can take a minute to arrive.',
          'Open mail app',
          'Resend email',
          'Use a different email',
          'We won\'t show any health information until your email is confirmed.',
        ],
      ),
      'wait': (context) => _frame(
        context,
        screen: '09-verify-email',
        state: 'wait',
        lines: const [
          'Sign up',
          'Check your email',
          'If j•••••@example.com can be used for a new account, we\'ve sent a link to confirm it. Open it on this phone to continue.',
          'You can send another email in 42 seconds.',
          'Open mail app',
          'Resend email in 0:42',
          'Use a different email',
          'We won\'t show any health information until your email is confirmed.',
        ],
      ),
      'expired': (context) => _frame(
        context,
        screen: '09-verify-email',
        state: 'expired',
        lines: const [
          'Sign up',
          'This link has expired',
          'Confirmation links work once and expire after 24 hours. We\'ll send you a fresh one.',
          'Send a new link',
          'Log in',
        ],
      ),
      'verified': (context) => _frame(
        context,
        screen: '09-verify-email',
        state: 'verified',
        lines: const [
          'Email confirmed',
          'Thanks, Jordan. Next, link your clinic record so your care team\'s plan and results can show here.',
          'Continue',
        ],
      ),
    },
    '10-log-in': {
      'default': (context) => _frame(
        context,
        screen: '10-log-in',
        state: 'default',
        lines: const [
          'ZYNDIOPLACEHOLDER',
          'GLP-1 WEIGHT LOSS CARE',
          'Log in',
          'Welcome back to your care program.',
          'Email',
          'jordan.rivera@example.com',
          'Password',
          'Show',
          'Forgot password?',
          'Log in',
          'Create an account',
        ],
      ),
      'signing': (context) => _frame(
        context,
        screen: '10-log-in',
        state: 'signing',
        lines: const [
          'ZYNDIOPLACEHOLDER',
          'GLP-1 WEIGHT LOSS CARE',
          'Log in',
          'Welcome back to your care program.',
          'Email',
          'jordan.rivera@example.com',
          'Password',
          '••••••••••••••',
          'Show',
          'Forgot password?',
          'Logging in',
          'Create an account',
        ],
      ),
      'error': (context) => _frame(
        context,
        screen: '10-log-in',
        state: 'error',
        lines: const [
          'ZYNDIOPLACEHOLDER',
          'GLP-1 WEIGHT LOSS CARE',
          'Log in',
          'Welcome back to your care program.',
          'Email',
          'jordan.rivera@example.com',
          'Password',
          '••••••••••••••',
          'Show',
          'That email and password don\'t match. Try again, or reset your password.',
          'Forgot password?',
          'Log in',
          'Create an account',
        ],
      ),
      'locked': (context) => _frame(
        context,
        screen: '10-log-in',
        state: 'locked',
        lines: const [
          'ZYNDIOPLACEHOLDER',
          'GLP-1 WEIGHT LOSS CARE',
          'Too many tries. For your security, log in is paused for 15 minutes. You can reset your password now.',
          'Log in',
          'Welcome back to your care program.',
          'Email',
          'jordan.rivera@example.com',
          'Password',
          '••••••••••••••',
          'Show',
          'Forgot password?',
          'Log in',
          'Create an account',
        ],
      ),
      'offline': (context) => _frame(
        context,
        screen: '10-log-in',
        state: 'offline',
        lines: const [
          'ZYNDIOPLACEHOLDER',
          'GLP-1 WEIGHT LOSS CARE',
          'You\'re offline. Connect to the internet to log in.',
          'Log in',
          'Welcome back to your care program.',
          'Email',
          'jordan.rivera@example.com',
          'Password',
          '••••••••••••••',
          'Show',
          'Forgot password?',
          'Log in',
          'Create an account',
        ],
      ),
    },
    '11-reset-password': {
      'request': (context) => _frame(
        context,
        screen: '11-reset-password',
        state: 'request',
        lines: const [
          'Log in',
          'Reset your password',
          'Enter the email you use for Zyndio. We\'ll send you a link to set a new password.',
          'Email',
          'jordan.rivera@example.com',
          'Send reset link',
        ],
      ),
      'sent': (context) => _frame(
        context,
        screen: '11-reset-password',
        state: 'sent',
        lines: const [
          'Log in',
          'Check your email',
          'If there\'s an account for j•••••@example.com, we\'ve sent a reset link. It works once and expires after 1 hour.',
          'Open mail app',
          'Back to log in',
          'No email after a few minutes? Check spam, or try again.',
        ],
      ),
      'new': (context) => _frame(
        context,
        screen: '11-reset-password',
        state: 'new',
        lines: const [
          'Log in',
          'Set a new password',
          'Choose a password you don\'t use anywhere else.',
          'New password',
          '••••••••••••••',
          'Show',
          'At least 12 characters',
          'An uppercase and a lowercase letter',
          'A number',
          'A symbol, like ! or #',
          'Not a commonly used password',
          'Save password',
          'Saving signs you out on your other devices.',
        ],
      ),
      'saved': (context) => _frame(
        context,
        screen: '11-reset-password',
        state: 'saved',
        lines: const [
          'Password updated',
          'You\'re logged in on this phone and signed out everywhere else.',
          'Continue',
        ],
      ),
      'expired': (context) => _frame(
        context,
        screen: '11-reset-password',
        state: 'expired',
        lines: const [
          'Log in',
          'This reset link has expired',
          'Reset links work once and expire after 1 hour. Request a new one to continue.',
          'Send a new link',
          'Back to log in',
        ],
      ),
    },
    '12-delete-account': {
      'settings': (context) => _frame(
        context,
        screen: '12-delete-account',
        state: 'settings',
        lines: const [
          'Profile',
          'Account',
          'Manage how you sign in to Zyndio.',
          'Personal details',
          'Emailj•••••@example.com',
          'Password and security',
          'Delete account',
          'Permanently deletes your Zyndio app account and the data you added in the app.',
        ],
      ),
      'reauth': (context) => _frame(
        context,
        screen: '12-delete-account',
        state: 'reauth',
        lines: const [
          'Account',
          'Confirm it\'s you',
          'Enter your password to continue deleting your account.',
          'Password',
          '••••••••••••••',
          'Show',
          'Continue',
          'Forgot password?',
        ],
      ),
      'confirm': (context) => _frame(
        context,
        screen: '12-delete-account',
        state: 'confirm',
        lines: const [
          'Account',
          'Delete your account?',
          'This can\'t be undone. We\'ll delete:',
          'Your app account, plus the lab uploads, logs and messages you added in the app.',
          'Your sign-in on every device. You\'ll be signed out everywhere.',
          'The link to your clinic record.',
          'Records your clinic holds, like visit notes and prescriptions, stay with your clinic. Deleting the app doesn\'t cancel your care program.',
          'Delete my account',
          'Keep my account',
        ],
      ),
      'deleting': (context) => _frame(
        context,
        screen: '12-delete-account',
        state: 'deleting',
        lines: const [
          'Account',
          'Delete your account?',
          'This can\'t be undone. We\'ll delete:',
          'Your app account, plus the lab uploads, logs and messages you added in the app.',
          'Your sign-in on every device. You\'ll be signed out everywhere.',
          'The link to your clinic record.',
          'Records your clinic holds, like visit notes and prescriptions, stay with your clinic. Deleting the app doesn\'t cancel your care program.',
          'Deleting account',
          'Keep my account',
        ],
      ),
      'error': (context) => _frame(
        context,
        screen: '12-delete-account',
        state: 'error',
        lines: const [
          'Account',
          'We couldn\'t delete your account. Nothing was changed. Check your connection and try again.',
          'Delete your account?',
          'This can\'t be undone. We\'ll delete:',
          'Your app account, plus the lab uploads, logs and messages you added in the app.',
          'Your sign-in on every device. You\'ll be signed out everywhere.',
          'The link to your clinic record.',
          'Records your clinic holds, like visit notes and prescriptions, stay with your clinic. Deleting the app doesn\'t cancel your care program.',
          'Delete my account',
          'Keep my account',
        ],
      ),
      'deleted': (context) => _frame(
        context,
        screen: '12-delete-account',
        state: 'deleted',
        lines: const [
          'Your account is deleted',
          'We\'ve sent a confirmation to j•••••@example.com. You\'ve been signed out on every device.',
          'Records your clinic holds stay with your clinic. To ask about them, contact your care team.',
          'Done',
        ],
      ),
    },
    '13-link-record': {
      'intro': (context) => _frame(
        context,
        screen: '13-link-record',
        state: 'intro',
        lines: const [
          'Today',
          'Link your clinic record',
          'Your care plan and results appear here once we know your clinic record is yours. It takes about a minute.',
          'Link my record',
          'We never link a record just because a name, email or birth date matches. You confirm it with a code only you can get.',
        ],
      ),
      'choose': (context) => _frame(
        context,
        screen: '13-link-record',
        state: 'choose',
        lines: const [
          'Back',
          'How do you want to confirm?',
          'Pick one. Either way, the code works once and only for your record.',
          'Send a code to my clinic\'s patient messages',
          'We\'ll send a 6-digit code to your clinic\'s patient messages.',
          'I have a code from my clinic',
          'Your clinic can give you a code that\'s only for you.',
        ],
      ),
      'code': (context) => _frame(
        context,
        screen: '13-link-record',
        state: 'code',
        lines: const [
          'Back',
          'Enter your code',
          'If your details match a clinic record, we\'ve sent a 6-digit code to your clinic\'s patient messages.',
          '5',
          '0',
          '2',
          'The code expires after 10 minutes and works once.',
          'Link record',
          'Send a new code',
        ],
      ),
      'wrong': (context) => _frame(
        context,
        screen: '13-link-record',
        state: 'wrong',
        lines: const [
          'Back',
          'Enter your code',
          'If your details match a clinic record, we\'ve sent a 6-digit code to your clinic\'s patient messages.',
          '5',
          '0',
          '2',
          '8',
          '1',
          '9',
          'That code didn\'t work. Check it, or send a new one.',
          'Link record',
          'Send a new code',
        ],
      ),
      'locked': (context) => _frame(
        context,
        screen: '13-link-record',
        state: 'locked',
        lines: const [
          'Back',
          'Enter your code',
          'If your details match a clinic record, we\'ve sent a 6-digit code to your clinic\'s patient messages.',
          'Too many tries. You can try again in 15 minutes, or ask your clinic for a code.',
          'Link record',
          'Send a new code',
        ],
      ),
      'clinic': (context) => _frame(
        context,
        screen: '13-link-record',
        state: 'clinic',
        lines: const [
          'Back',
          'Enter your clinic code',
          'Use the code your clinic gave you. It\'s only for you, so don\'t share it.',
          'Clinic code',
          'K7Q4-2MRX',
          '8 letters and numbers, like K7Q4-2MRX. It works once, within 72 hours of when your clinic gave it to you.',
          'Link record',
        ],
      ),
      'review': (context) => _frame(
        context,
        screen: '13-link-record',
        state: 'review',
        lines: const [
          'Back',
          'No code yet?',
          'Codes usually arrive within a few minutes. If nothing comes, your clinic can confirm it\'s you and give you a clinic code instead.',
          'I have a clinic code',
          'Send a new code',
          'Until your record is linked, no clinic data is shown in the app.',
        ],
      ),
      'linked': (context) => _frame(
        context,
        screen: '13-link-record',
        state: 'linked',
        lines: const [
          'FICTIONAL DATA',
          'Your record is linked',
          'Your care plan and results from Brightway Weight Care will show here.',
          'PatientJordan Rivera',
          'ClinicBrightway Weight Care',
          'In care sinceApr 2, 2026',
          'Go to Today',
          'We\'ve also sent a notice to your email and your clinic\'s patient messages.',
          'Not you? Unlink',
        ],
      ),
    },
  };
}

Widget _frame(
  BuildContext context, {
  required String screen,
  required String state,
  required List<String> lines,
}) {
  final c = Theme.of(context).extension<ZyndioColors>()!;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final title = lines.isNotEmpty ? lines.first : screen;
  final body = lines.length > 1 ? lines.sublist(1) : <String>[];

  return ColoredBox(
    color: c.bgCanvas,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ZYNDIO',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
                color: c.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$screen / $state',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: c.textTertiary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.25,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  for (final line in body) ...[
                    _lineCard(context, line, isDark),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'FICTIONAL DATA · Flutter capture',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: c.textTertiary),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _lineCard(BuildContext context, String line, bool isDark) {
  final c = Theme.of(context).extension<ZyndioColors>()!;
  final looksButton = line.length < 40 && (
      line.contains('account') ||
      line.contains('Link') ||
      line.contains('Send') ||
      line.contains('Create') ||
      line.contains('Sign') ||
      line.contains('Delete') ||
      line.contains('Go to') ||
      line.contains('Keep') ||
      line.startsWith('I have') ||
      line == 'Done' ||
      line == 'Back');
  if (looksButton) {
    return SizedBox(
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.brandPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            line,
            style: TextStyle(
              fontFamily: 'Inter',
              color: c.brandOnPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
  return DecoratedBox(
    decoration: BoxDecoration(
      color: c.bgSurface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: c.borderSubtle),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        line,
        style: TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.3, color: c.textSecondary),
      ),
    ),
  );
}
