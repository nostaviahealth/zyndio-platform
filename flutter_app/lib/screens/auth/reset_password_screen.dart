import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/password_rules_checklist.dart';
import 'widgets/auth_background.dart';

/// Ava 11-reset-password: new / saved / expired. Reached from the emailed
/// 1h-TTL reset link (`/reset-password?token=...`).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

enum _Step { form, saved, expired }

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  _Step _step = _Step.form;
  bool _isLoading = false;
  bool _submitted = false;
  String? _errorMessage;

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
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .completePasswordReset(widget.token!, _passwordController.text);
      if (!mounted) return;
      setState(() => _step = _Step.saved);
    } on PatientAuthException catch (e) {
      setState(() {
        _errorMessage = switch (e.code) {
          'invalid_or_expired_link' => 'This reset link has expired. Request a new one.',
          'password_too_common' => 'That password is too common. Choose another.',
          'password_too_short' || 'password_too_weak' =>
            'Your password needs to meet every rule below.',
          _ => 'Something went wrong. Please try again.',
        };
        if (e.code == 'invalid_or_expired_link') _step = _Step.expired;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;

    return AuthBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Choose a new password',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(color: nc.textPrimary)),
                  const SizedBox(height: 16),
                  if (_step == _Step.saved) ...[
                    Text(
                      'Your password has been changed. You have been signed out of every '
                      'other device.',
                      style: TextStyle(color: nc.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Sign in'),
                      ),
                    ),
                  ] else if (_step == _Step.expired) ...[
                    Text(
                      'This reset link has expired or was already used.',
                      style: TextStyle(color: nc.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/forgot-password'),
                        child: const Text('Request a new link'),
                      ),
                    ),
                  ] else ...[
                    if (_errorMessage != null) ...[
                      Text(_errorMessage!, style: const TextStyle(color: BrandColors.red500)),
                      const SizedBox(height: 12),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(hintText: 'New password'),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              final checks = checkPasswordRules(value ?? '');
                              return checks.allClientRulesMet
                                  ? null
                                  : 'Your password needs to meet every rule below';
                            },
                          ),
                          const SizedBox(height: 12),
                          PasswordRulesChecklist(
                            password: _passwordController.text,
                            showInvalid: _submitted,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Text('Save new password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
