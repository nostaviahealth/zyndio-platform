import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../demo/widgets/code_input.dart';
import '../../providers/auth_provider.dart';
import '../../utils/mask_email.dart';
import '../../demo_login/demo_login.dart';
import 'widgets/patient_auth_chrome.dart';

final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _sixDigits = RegExp(r'^\d{6}$');

/// Copy for a failed code check (APP-01), shared with account deletion.
/// Matches the demo build's sign-in copy (screens 01/07).
String loginCodeErrorCopy(Object error) {
  if (error is PatientAuthException) {
    switch (error.code) {
      case 'invalid_code':
        return "That code isn't right. Check it and try again.";
      case 'code_expired':
      case 'reauth_failed':
        return 'That code has expired or was already used. Tap “Send a new code” to get a fresh one.';
      case 'locked':
        return loginCodeLockedCopy(error.retryAfterSeconds);
      case 'rate_limited':
        return 'Too many requests. Wait a few minutes, then try again.';
      case 'invalid_request':
        return 'Enter the 6-digit code.';
    }
  }
  final text = error.toString();
  if (text.contains('SocketException') ||
      text.contains('host lookup') ||
      text.contains('offline')) {
    return "You're offline. Connect to the internet and try again.";
  }
  return 'Something went wrong. Try again.';
}

/// "Try again in {n} min", rounded up so a part-minute never reads 0.
String loginCodeLockedCopy(int? retryAfterSeconds) {
  final minutes = ((retryAfterSeconds ?? 15 * 60) / 60).ceil().clamp(1, 60);
  return 'Too many attempts. Try again in $minutes min, or contact your care team.';
}

/// APP-01 patient sign-in (replaces password log-in as the default): the
/// patient enters the email their Zyndio care team enrolled them with, then
/// the 6-digit code we email. No password, no self-sign-up unless the org
/// has turned it on. The email step always moves on to code entry, whether
/// or not the email is enrolled (the server answers the same either way).
class CodeSignInScreen extends ConsumerStatefulWidget {
  const CodeSignInScreen({super.key, this.initialEmail});

  /// Prefill, e.g. from an invite link `/login?email=...`.
  final String? initialEmail;

  @override
  ConsumerState<CodeSignInScreen> createState() => _CodeSignInScreenState();
}

class _CodeSignInScreenState extends ConsumerState<CodeSignInScreen> {
  late final TextEditingController _emailController =
      TextEditingController(text: widget.initialEmail ?? '');
  bool _codeStep = false;
  String _email = '';
  String _code = '';
  bool _busy = false;
  bool _locked = false;
  String? _emailError;
  String? _codeError;
  String? _banner;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy) return;
    final email = _emailController.text.trim().toLowerCase();
    if (!_emailShape.hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _emailError = null;
      _banner = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).requestLoginCode(email);
      if (!mounted) return;
      setState(() {
        _codeStep = true;
        _email = email;
        _code = '';
        _codeError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_codeStep) {
          _codeError = loginCodeErrorCopy(e);
        } else {
          _banner = loginCodeErrorCopy(e);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _locked) return;
    // A short entry is caught here and never sent, so it can't spend one of
    // the 5 tries.
    if (!_sixDigits.hasMatch(_code)) {
      setState(() => _codeError = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).verifyLoginCode(_email, _code);
      // Success: the auth state change sends the router to the app (or the
      // onboarding gate).
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (e is PatientAuthException && e.code == 'locked') {
          _locked = true;
          _banner = loginCodeErrorCopy(e);
        } else {
          _codeError = loginCodeErrorCopy(e);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToEmail() {
    setState(() {
      _codeStep = false;
      _code = '';
      _codeError = null;
      _banner = null;
      _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _codeStep ? _buildCodeStep(context) : _buildEmailStep(context);
  }

  Widget _buildEmailStep(BuildContext context) {
    final c = zcOf(context);
    final selfSignup = ref.watch(selfSignupEnabledProvider).value ?? false;
    return PatientAuthShell(
      wordmark: true,
      title: 'Sign in to your care program',
      subtitle:
          "Use the email your Zyndio care team enrolled you with. We'll send a 6-digit code. No password needed.",
      banner: _banner == null ? null : AuthStatusBanner(message: _banner!),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthLabeledField(
            label: 'Email',
            errorText: _emailError,
            child: TextField(
              key: const Key('code-signin-email'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.email],
              style: TextStyle(color: c.textPrimary),
              decoration: authFieldDecoration(context, error: _emailError != null),
              onSubmitted: (_) => _sendCode(),
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: _busy ? 'Sending code' : 'Send code',
            loading: _busy,
            onPressed: _sendCode,
          ),
          const SizedBox(height: 24),
          const AuthInfoCard(
            message:
                'New to Zyndio? Accounts are created by your care team when you enroll. Ask them to send you an invite.',
          ),
          if (kDemoLoginEnabled) ...[
            const SizedBox(height: 16),
            AuthSecondaryButton(
              key: const Key('demo-login'),
              label: 'Explore the demo (sample data)',
              onPressed: () => ref.read(demoSessionProvider.notifier).start(),
            ),
          ],
          if (selfSignup) ...[
            const SizedBox(height: 16),
            AuthSecondaryButton(
              label: 'Create an account',
              onPressed: () => context.go('/signup'),
            ),
            AuthSecondaryButton(
              label: 'Log in with a password',
              outlined: false,
              onPressed: () => context.go('/login/password'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCodeStep(BuildContext context) {
    final c = zcOf(context);
    return PatientAuthShell(
      backLabel: 'Email',
      onBack: _backToEmail,
      title: 'Enter your code',
      subtitle: 'We sent a 6-digit code to ${maskEmail(_email)}.',
      banner: _banner == null ? null : AuthStatusBanner(message: _banner!),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CodeInput(
            key: const Key('code-signin-code'),
            value: _code,
            autofocus: true,
            hasError: _codeError != null,
            onChanged: (v) => setState(() {
              _code = v;
              _codeError = null;
            }),
          ),
          if (_codeError != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                _codeError!,
                key: const Key('code-signin-error'),
                style: TextStyle(color: c.statusCritical, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Code expires after 10 minutes. Paste works, and your keyboard can fill the code from email.',
            style: TextStyle(color: c.textSecondary, fontSize: 13, height: 18 / 13),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Continue',
            loading: _busy,
            onPressed: _locked ? null : _verify,
          ),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            label: 'Send a new code',
            onPressed: _locked || _busy ? null : _sendCode,
          ),
        ],
      ),
    );
  }
}
