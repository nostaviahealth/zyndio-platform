import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/providers/auth_provider.dart';
import 'package:zyndio_patient/screens/auth/delete_account_screen.dart';
import 'package:zyndio_patient/screens/auth/forgot_password_screen.dart';
import 'package:zyndio_patient/screens/auth/link_record_screen.dart';
import 'package:zyndio_patient/screens/auth/login_screen.dart';
import 'package:zyndio_patient/screens/auth/reset_password_screen.dart';
import 'package:zyndio_patient/screens/auth/signup_screen.dart';
import 'package:zyndio_patient/screens/auth/verify_email_screen.dart';

import 'capture_auth_fakes.dart';

/// Captures TC-012 patient-auth by pumping REAL production screens
/// (SignupScreen, LoginScreen, …, LinkRecordScreen) under BrandTheme
/// light/dark at 390×844 (physical 780×1688, DPR 2) with Inter + MaterialIcons.
///
/// Run:
///   flutter test test/auth/capture_patient_auth_screenshots_test.dart --update-goldens
///
/// States that cannot be reached through the real widget are listed in
/// docs/screenshots/tc-012/INDEX.md under "Missing".

const _logical = Size(390, 844);
const _dpr = 2.0;

Future<void> _loadAppFonts() async {
  final inter = FontLoader('Inter')
    ..addFont(rootBundle.load('assets/fonts/Inter-VariableFont_opsz,wght.ttf'));
  await inter.load();

  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/home/box/sdk/flutter';
  final iconsPath =
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final iconsBytes = File(iconsPath).readAsBytesSync();
  await (FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(iconsBytes.buffer))))
      .load();

  final robotoPath =
      '$flutterRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
  if (File(robotoPath).existsSync()) {
    final robotoBytes = File(robotoPath).readAsBytesSync();
    await (FontLoader('Roboto')
          ..addFont(Future.value(ByteData.view(robotoBytes.buffer))))
        .load();
  }

  final home = Platform.environment['HOME'] ?? '/home/box';
  for (final path in <String>[
    '$home/.pub-cache/hosted/pub.dev/lucide_icons_flutter-4.0.1/assets/lucide.ttf',
    'build/app/intermediates/flutter/debug/flutter_assets/packages/lucide_icons_flutter/assets/lucide.ttf',
  ]) {
    final f = File(path);
    if (f.existsSync()) {
      final bytes = f.readAsBytesSync();
      await (FontLoader('packages/lucide_icons_flutter/Lucide')
            ..addFont(Future.value(ByteData.view(bytes.buffer))))
          .load();
      break;
    }
  }
}

typedef _Setup = Future<void> Function(
  WidgetTester tester,
  CaptureAuthNotifier auth,
);

class _Capture {
  const _Capture(this.screen, this.state, this.setup);
  final String screen;
  final String state;
  final _Setup setup;
}

bool _captureDark = false;

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Widget home,
  required bool dark,
  required CaptureAuthNotifier auth,
}) async {
  dark = _captureDark; // harness drives light/dark via this flag
  tester.view.physicalSize = Size(_logical.width * _dpr, _logical.height * _dpr);
  tester.view.devicePixelRatio = _dpr;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final theme = dark ? BrandTheme.darkTheme : BrandTheme.lightTheme;
  final themed = theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: 'Inter'),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: 'Inter'),
  );

  final router = GoRouter(
    initialLocation: '/shot',
    routes: [
      GoRoute(path: '/shot', builder: (_, __) => home),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, __) =>
            const VerifyEmailScreen(email: 'jordan.rivera@example.com'),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, __) => const ResetPasswordScreen(token: 'tok'),
      ),
      GoRoute(path: '/home', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [...captureOverrides(auth)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: themed,
        themeMode: ThemeMode.light,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump(); // first frame
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _settleBrief(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
}

final _captures = <_Capture>[
  // ---- 08-sign-up ----
  _Capture('08-sign-up', 'default', (t, a) async {
    await _pumpScreen(t, home: const SignupScreen(), dark: false, auth: a);
  }),
  _Capture('08-sign-up', 'filled', (t, a) async {
    await _pumpScreen(t, home: const SignupScreen(), dark: false, auth: a);
    await t.enterText(find.byType(TextFormField).at(0), 'Jordan Rivera');
    await t.enterText(
        find.byType(TextFormField).at(1), 'jordan.rivera@example.com');
    await t.enterText(
        find.byType(TextFormField).at(2), 'Correct-Horse-Battery9!');
    await _settleBrief(t);
  }),
  _Capture('08-sign-up', 'invalid', (t, a) async {
    await _pumpScreen(t, home: const SignupScreen(), dark: false, auth: a);
    await t.enterText(find.byType(TextFormField).at(0), 'Jordan Rivera');
    await t.enterText(
        find.byType(TextFormField).at(1), 'jordan.rivera@example.com');
    await t.enterText(find.byType(TextFormField).at(2), 'nonsymbol12AB');
    await t.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await _settleBrief(t);
  }),
  _Capture('08-sign-up', 'creating', (t, a) async {
    a.hangSignUp = Completer<void>();
    await _pumpScreen(t, home: const SignupScreen(), dark: false, auth: a);
    await t.enterText(find.byType(TextFormField).at(0), 'Jordan Rivera');
    await t.enterText(
        find.byType(TextFormField).at(1), 'jordan.rivera@example.com');
    await t.enterText(
        find.byType(TextFormField).at(2), 'Correct-Horse-Battery9!');
    await t.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await _settleBrief(t); // stays on creating/loading
  }),
  _Capture('08-sign-up', 'offline', (t, a) async {
    a.signUpError = Exception('SocketException: Failed host lookup');
    await _pumpScreen(t, home: const SignupScreen(), dark: false, auth: a);
    await t.enterText(find.byType(TextFormField).at(0), 'Jordan Rivera');
    await t.enterText(
        find.byType(TextFormField).at(1), 'jordan.rivera@example.com');
    await t.enterText(
        find.byType(TextFormField).at(2), 'Correct-Horse-Battery9!');
    await t.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await t.pump(); // start
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('08-sign-up', 'limited', (t, a) async {
    a.signUpError = PatientAuthException('rate_limited');
    await _pumpScreen(t, home: const SignupScreen(), dark: false, auth: a);
    await t.enterText(find.byType(TextFormField).at(0), 'Jordan Rivera');
    await t.enterText(
        find.byType(TextFormField).at(1), 'jordan.rivera@example.com');
    await t.enterText(
        find.byType(TextFormField).at(2), 'Correct-Horse-Battery9!');
    await t.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),

  // ---- 09-verify-email ----
  _Capture('09-verify-email', 'sent', (t, a) async {
    await _pumpScreen(
      t,
      home: const VerifyEmailScreen(email: 'jordan.rivera@example.com'),
      dark: false,
      auth: a,
    );
  }),
  _Capture('09-verify-email', 'resent', (t, a) async {
    await _pumpScreen(
      t,
      home: const VerifyEmailScreen(email: 'jordan.rivera@example.com'),
      dark: false,
      auth: a,
    );
    await t.tap(find.text('Resend email'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('09-verify-email', 'wait', (t, a) async {
    // Same path as resent: cooldown label is the "wait" state.
    await _pumpScreen(
      t,
      home: const VerifyEmailScreen(email: 'jordan.rivera@example.com'),
      dark: false,
      auth: a,
    );
    await t.tap(find.text('Resend email'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('09-verify-email', 'expired', (t, a) async {
    a.verifyError = PatientAuthException('invalid_or_expired_link');
    await _pumpScreen(
      t,
      home: const VerifyEmailScreen(
        email: 'jordan.rivera@example.com',
        token: 'bad-token',
      ),
      dark: false,
      auth: a,
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('09-verify-email', 'verified', (t, a) async {
    await _pumpScreen(
      t,
      home: const VerifyEmailScreen(
        email: 'jordan.rivera@example.com',
        token: 'good-token',
      ),
      dark: false,
      auth: a,
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),

  // ---- 10-log-in ----
  _Capture('10-log-in', 'default', (t, a) async {
    await _pumpScreen(t, home: const LoginScreen(), dark: false, auth: a);
  }),
  _Capture('10-log-in', 'signing', (t, a) async {
    a.hangSignIn = Completer<void>();
    await _pumpScreen(t, home: const LoginScreen(), dark: false, auth: a);
    await t.enterText(
        find.byType(TextFormField).at(0), 'jordan.rivera@example.com');
    await t.enterText(
        find.byType(TextFormField).at(1), 'Correct-Horse-Battery9!');
    await t.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await _settleBrief(t);
  }),
  _Capture('10-log-in', 'error', (t, a) async {
    a.signInError = PatientAuthException('invalid_credentials');
    await _pumpScreen(t, home: const LoginScreen(), dark: false, auth: a);
    await t.enterText(
        find.byType(TextFormField).at(0), 'jordan.rivera@example.com');
    await t.enterText(
        find.byType(TextFormField).at(1), 'Wrong-Password-99!');
    await t.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('10-log-in', 'locked', (t, a) async {
    a.signInError = Exception('account locked after several wrong attempts');
    await _pumpScreen(t, home: const LoginScreen(), dark: false, auth: a);
    await t.enterText(
        find.byType(TextFormField).at(0), 'jordan.rivera@example.com');
    await t.enterText(
        find.byType(TextFormField).at(1), 'Wrong-Password-99!');
    await t.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('10-log-in', 'offline', (t, a) async {
    a.signInError = Exception('SocketException: Failed host lookup');
    await _pumpScreen(t, home: const LoginScreen(), dark: false, auth: a);
    await t.enterText(
        find.byType(TextFormField).at(0), 'jordan.rivera@example.com');
    await t.enterText(
        find.byType(TextFormField).at(1), 'Correct-Horse-Battery9!');
    await t.tap(find.widgetWithText(ElevatedButton, 'Sign in'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),

  // ---- 11-reset-password ----
  _Capture('11-reset-password', 'request', (t, a) async {
    await _pumpScreen(
        t, home: const ForgotPasswordScreen(), dark: false, auth: a);
  }),
  _Capture('11-reset-password', 'sent', (t, a) async {
    await _pumpScreen(
        t, home: const ForgotPasswordScreen(), dark: false, auth: a);
    await t.enterText(
        find.byType(TextFormField), 'jordan.rivera@example.com');
    await t.tap(find.text('Send reset link'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('11-reset-password', 'new', (t, a) async {
    await _pumpScreen(
      t,
      home: const ResetPasswordScreen(token: 'valid-token'),
      dark: false,
      auth: a,
    );
  }),
  _Capture('11-reset-password', 'saved', (t, a) async {
    await _pumpScreen(
      t,
      home: const ResetPasswordScreen(token: 'valid-token'),
      dark: false,
      auth: a,
    );
    await t.enterText(
        find.byType(TextFormField), 'Correct-Horse-Battery9!');
    await t.tap(find.text('Save new password'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('11-reset-password', 'expired', (t, a) async {
    await _pumpScreen(
      t,
      home: const ResetPasswordScreen(token: null),
      dark: false,
      auth: a,
    );
  }),

  // ---- 12-delete-account (settings entry is MISSING — see INDEX) ----
  _Capture('12-delete-account', 'reauth', (t, a) async {
    await _pumpScreen(
        t, home: const DeleteAccountScreen(), dark: false, auth: a);
  }),
  _Capture('12-delete-account', 'confirm', (t, a) async {
    await _pumpScreen(
        t, home: const DeleteAccountScreen(), dark: false, auth: a);
    await t.enterText(find.byType(TextFormField), 'Correct-Horse-Battery9!');
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
  }),
  _Capture('12-delete-account', 'deleting', (t, a) async {
    a.hangDelete = Completer<void>();
    await _pumpScreen(
        t, home: const DeleteAccountScreen(), dark: false, auth: a);
    await t.enterText(find.byType(TextFormField), 'Correct-Horse-Battery9!');
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
    await t.tap(find.text('Delete my account'));
    await _settleBrief(t);
  }),
  _Capture('12-delete-account', 'error', (t, a) async {
    a.deleteError = PatientAuthException('reauth_failed');
    await _pumpScreen(
        t, home: const DeleteAccountScreen(), dark: false, auth: a);
    await t.enterText(find.byType(TextFormField), 'Wrong-Password-99!');
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
    await t.tap(find.text('Delete my account'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('12-delete-account', 'deleted', (t, a) async {
    await _pumpScreen(
        t, home: const DeleteAccountScreen(), dark: false, auth: a);
    await t.enterText(find.byType(TextFormField), 'Correct-Horse-Battery9!');
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
    await t.tap(find.text('Delete my account'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),

  // ---- 13-link-record ----
  _Capture('13-link-record', 'intro', (t, a) async {
    await _pumpScreen(
        t, home: const LinkRecordScreen(), dark: false, auth: a);
  }),
  _Capture('13-link-record', 'choose', (t, a) async {
    await _pumpScreen(
        t, home: const LinkRecordScreen(), dark: false, auth: a);
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
  }),
  _Capture('13-link-record', 'code', (t, a) async {
    await _pumpScreen(
        t, home: const LinkRecordScreen(), dark: false, auth: a);
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
    await t.tap(find.text("Send a code to my clinic's patient messages"));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('13-link-record', 'wrong', (t, a) async {
    a.redeemTelehealthResult = const {'ok': false, 'error': 'wrong_code'};
    await _pumpScreen(
        t, home: const LinkRecordScreen(), dark: false, auth: a);
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
    await t.tap(find.text("Send a code to my clinic's patient messages"));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    await t.enterText(find.byType(TextField), '000000');
    await t.tap(find.text('Continue'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('13-link-record', 'locked', (t, a) async {
    a.requestLinkError = PatientAuthException('rate_limited');
    await _pumpScreen(
        t, home: const LinkRecordScreen(), dark: false, auth: a);
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
    await t.tap(find.text("Send a code to my clinic's patient messages"));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('13-link-record', 'clinic', (t, a) async {
    await _pumpScreen(
        t, home: const LinkRecordScreen(), dark: false, auth: a);
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
    await t.tap(find.text('I have a code from my clinic'));
    await _settleBrief(t);
  }),
  _Capture('13-link-record', 'review', (t, a) async {
    a.redeemClinicResult = const {'ok': false, 'error': 'conflict'};
    await _pumpScreen(
        t, home: const LinkRecordScreen(), dark: false, auth: a);
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
    await t.tap(find.text('I have a code from my clinic'));
    await _settleBrief(t);
    await t.enterText(find.byType(TextField), 'CLINICDEMO7K4');
    await t.tap(find.text('Continue'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
  _Capture('13-link-record', 'linked', (t, a) async {
    a.redeemClinicResult = const {'ok': true};
    await _pumpScreen(
        t, home: const LinkRecordScreen(), dark: false, auth: a);
    await t.tap(find.text('Continue'));
    await _settleBrief(t);
    await t.tap(find.text('I have a code from my clinic'));
    await _settleBrief(t);
    await t.enterText(find.byType(TextField), 'CLINICDEMO7K4');
    await t.tap(find.text('Continue'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadAppFonts();
  });

  for (final mode in ['light', 'dark']) {
    for (final cap in _captures) {
      final goldenRel = 'goldens/${cap.screen}/${cap.state}--$mode.png';
      testWidgets('${cap.screen}/${cap.state}--$mode', (tester) async {
        final auth = createCaptureAuth();
        // setup always pumps light first via _pumpScreen(dark:false) then we
        // re-pump for dark by calling setup after swapping — instead, pass mode:
        await _runCapture(tester, cap, auth, dark: mode == 'dark');
        await expectLater(
          find.byType(MaterialApp).first,
          matchesGoldenFile(goldenRel),
        );
      }, timeout: const Timeout(Duration(seconds: 60)));
    }
  }

  tearDownAll(() {
    if (!autoUpdateGoldenFiles) return;
    final repo = Directory.current.path.endsWith('flutter_app')
        ? Directory.current.parent.path
        : Directory.current.path;
    final goldenRoot = Directory('${Directory.current.path}/test/auth/goldens');
    final outs = [
      Directory('$repo/docs/screenshots/tc-012'),
      Directory(
          '/workspace/techteam/team3/projects/zyndio/work/screenshots/tc-012'),
    ];
    var copied = 0;
    for (final screenDir in goldenRoot.listSync().whereType<Directory>()) {
      final screen =
          screenDir.uri.pathSegments.where((s) => s.isNotEmpty).last;
      for (final f in screenDir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.png')) continue;
        final name = f.uri.pathSegments.last;
        for (final out in outs) {
          final destDir = Directory('${out.path}/$screen')
            ..createSync(recursive: true);
          f.copySync('${destDir.path}/$name');
        }
        copied++;
      }
    }
    // ignore: avoid_print
    print('COPIED_SCREENSHOTS=$copied');
  });
}

Future<void> _runCapture(
  WidgetTester tester,
  _Capture cap,
  CaptureAuthNotifier auth, {
  required bool dark,
}) async {
  _captureDark = dark;
  await cap.setup(tester, auth);
}
