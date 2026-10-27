import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/password_rules_checklist.dart';
import 'widgets/patient_auth_chrome.dart';

/// Ava 11-reset-password: new / saved / expired.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

enum _Step { form, saved, expired }

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  _Step _step = _Step.form;
  bool _isLoading = false;
  bool _submitted = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    if (widget.token == null || widget.token!.isEmpty) _step = _Step.expired;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final checks = checkPasswordRules(_passwordController.text);
    if (!checks.allClientRulesMet) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .completePasswordReset(widget.token!, _passwordController.text);
      if (!mounted) return;
      setState(() => _step = _Step.saved);
    } on PatientAuthException catch (e) {
      if (e.code == 'invalid_or_expired_link') {
        setState(() => _step = _Step.expired);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);

    if (_step == _Step.saved) {
      return PatientAuthShell(
        hero: const AuthHeroIcon(icon: LucideIcons.check),
        title: 'Password updated',
        subtitle:
            "You're logged in on this phone and signed out everywhere else.",
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPrimaryButton(
              label: 'Continue',
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      );
    }

    if (_step == _Step.expired) {
      return PatientAuthShell(
        backLabel: 'Log in',
        onBack: () => context.go('/login'),
        title: 'This reset link has expired',
        subtitle:
            'Reset links work once and expire after 1 hour. Request a new one to continue.',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPrimaryButton(
              label: 'Send a new link',
              onPressed: () => context.go('/forgot-password'),
            ),
            const SizedBox(height: 12),
            AuthSecondaryButton(
              label: 'Back to log in',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      );
    }

    return PatientAuthShell(
      backLabel: 'Log in',
      onBack: () => context.go('/login'),
      title: 'Set a new password',
      subtitle: "Choose a password you don't use anywhere else.",
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthLabeledField(
              label: 'New password',
              child: TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                style: TextStyle(color: c.textPrimary),
                decoration: authFieldDecoration(
                  context,
                  suffix: TextButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    child: Text(_obscure ? 'Show' : 'Hide',
                        style: TextStyle(color: c.brandPrimary)),
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
              label: 'Save password',
              loading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 12),
            Text(
              'Saving signs you out on your other devices.',
              style: TextStyle(color: c.textTertiary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
