import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/password_rules_checklist.dart';
import 'widgets/patient_auth_chrome.dart';

/// Patient sign-up — Ava handoff 08-sign-up (email + password only, no name).
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  bool _submitted = false;
  String? _inlinePasswordError;
  String? _bannerMessage;
  AuthBannerTone _bannerTone = AuthBannerTone.critical;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    setState(() {
      _submitted = true;
      _inlinePasswordError = null;
      _bannerMessage = null;
    });
    final checks = checkPasswordRules(_passwordController.text);
    if (!checks.allClientRulesMet) {
      setState(() {
        if (!checks.symbol) {
          _inlinePasswordError =
              'Add a symbol, like ! or #, to finish your password.';
        } else {
          _inlinePasswordError =
              'Your password needs to meet every rule below';
        }
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authNotifierProvider.notifier).patientSignUp(
            _emailController.text.trim(),
            _passwordController.text,
          );
      if (!mounted) return;
      context.go('/verify-email',
          extra: {'email': _emailController.text.trim()});
    } catch (e) {
      final msg = e.toString();
      setState(() {
        if (msg.contains('offline') || msg.contains('SocketException')) {
          _bannerMessage =
              "You're offline. Connect to the internet to create your account.";
          _bannerTone = AuthBannerTone.warning;
        } else if (msg.contains('rate') || msg.contains('limited') || msg.contains('too many')) {
          _bannerMessage =
              'Too many attempts from this device. Please wait 15 minutes, then try again.';
          _bannerTone = AuthBannerTone.critical;
        } else {
          _bannerMessage = msg.replaceFirst('Exception: ', '');
          _bannerTone = AuthBannerTone.critical;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    return PatientAuthShell(
      backLabel: 'Welcome',
      onBack: () => context.go('/login'),
      title: 'Create your account',
      subtitle: "Use your own email. We'll send a link to confirm it's you.",
      banner: _bannerMessage == null
          ? null
          : AuthStatusBanner(message: _bannerMessage!, tone: _bannerTone),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthLabeledField(
              label: 'Email',
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                style: TextStyle(color: c.textPrimary),
                decoration: authFieldDecoration(context),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
            ),
            const SizedBox(height: 16),
            AuthLabeledField(
              label: 'Create a password',
              errorText: _inlinePasswordError,
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.newPassword],
                style: TextStyle(color: c.textPrimary),
                decoration: authFieldDecoration(
                  context,
                  error: _inlinePasswordError != null,
                  suffix: TextButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    child: Text(_obscure ? 'Show' : 'Hide',
                        style: TextStyle(color: c.brandPrimary, fontSize: 14)),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            PasswordRulesChecklist(
              password: _passwordController.text,
              showInvalid: _submitted,
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: _isLoading ? 'Creating account' : 'Create account',
              loading: _isLoading,
              onPressed: _handleSignUp,
            ),
            const SizedBox(height: 24),
            Text(
              'By creating an account, you agree to our',
              style: TextStyle(color: c.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.push('/legal/terms'),
                  child: Text('Terms',
                      style: TextStyle(color: c.brandPrimary, fontSize: 13)),
                ),
                Text(' and ',
                    style: TextStyle(color: c.textTertiary, fontSize: 13)),
                TextButton(
                  onPressed: () => context.push('/legal/privacy'),
                  child: Text('Privacy Notice',
                      style: TextStyle(color: c.brandPrimary, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text.rich(
                TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                  children: [
                    TextSpan(
                      text: 'Log in',
                      style: TextStyle(
                          color: c.brandPrimary, fontWeight: FontWeight.w600),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => context.go('/login'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
