import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import 'widgets/patient_auth_chrome.dart';

/// Patient log-in — Ava handoff 10-log-in (email + password only).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;
  bool _fieldError = false;
  String? _errorMessage;
  String? _bannerMessage;
  AuthBannerTone _bannerTone = AuthBannerTone.critical;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _fieldError = false;
      _bannerMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } catch (e) {
      final parsed = _parseError(e.toString());
      setState(() {
        if (parsed.isBanner) {
          _bannerMessage = parsed.message;
          _bannerTone = parsed.tone;
          _fieldError = false;
          _errorMessage = null;
        } else {
          _errorMessage = parsed.message;
          _fieldError = true;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ({String message, bool isBanner, AuthBannerTone tone}) _parseError(String error) {
    if (error.contains('SocketException') ||
        error.contains('host lookup') ||
        error.contains('No address associated') ||
        error.contains('offline')) {
      return (
        message: "You're offline. Connect to the internet to log in.",
        isBanner: true,
        tone: AuthBannerTone.warning,
      );
    }
    if (error.contains('locked') || error.contains('rate limit') || error.contains('too many')) {
      return (
        message:
            'Too many tries. For your security, log in is paused for 15 minutes. You can reset your password now.',
        isBanner: true,
        tone: AuthBannerTone.critical,
      );
    }
    if (error.contains('Invalid login credentials') ||
        error.contains('invalid_credentials') ||
        error.contains('Invalid email or password')) {
      return (
        message:
            "That email and password don't match. Try again, or reset your password.",
        isBanner: false,
        tone: AuthBannerTone.critical,
      );
    }
    return (
      message: error
          .replaceFirst('Exception: ', '')
          .replaceFirst('AuthException: ', ''),
      isBanner: false,
      tone: AuthBannerTone.critical,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    return PatientAuthShell(
      wordmark: true,
      title: 'Log in',
      subtitle: 'Welcome back to your care program.',
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
                    (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
              ),
            ),
            const SizedBox(height: 16),
            AuthLabeledField(
              label: 'Password',
              errorText: _errorMessage,
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                style: TextStyle(color: c.textPrimary),
                decoration: authFieldDecoration(
                  context,
                  error: _fieldError,
                  suffix: TextButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    child: Text(_obscure ? 'Show' : 'Hide',
                        style: TextStyle(color: c.brandPrimary, fontSize: 14)),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Enter your password' : null,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: Text('Forgot password?',
                    style: TextStyle(color: c.brandPrimary)),
              ),
            ),
            const SizedBox(height: 8),
            AuthPrimaryButton(
              label: _isLoading ? 'Logging in' : 'Log in',
              loading: _isLoading,
              onPressed: _handleSignIn,
            ),
            const SizedBox(height: 12),
            AuthSecondaryButton(
              label: 'Create an account',
              onPressed: () => context.go('/signup'),
            ),
          ],
        ),
      ),
    );
  }
}
