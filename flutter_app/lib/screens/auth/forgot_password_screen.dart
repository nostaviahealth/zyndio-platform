import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../utils/mask_email.dart';
import 'widgets/patient_auth_chrome.dart';

/// Ava 11-reset-password: request / sent.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .requestPasswordReset(_emailController.text.trim());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _sent = true;
        });
      }
    }
  }

  Future<void> _openMail() async {
    final uri = Uri.parse('mailto:');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    if (_sent) {
      final masked = maskEmail(_emailController.text.trim());
      return PatientAuthShell(
        backLabel: 'Log in',
        onBack: () => context.go('/login'),
        hero: const AuthHeroIcon(
          icon: LucideIcons.mail,
          tone: AuthBannerTone.info,
        ),
        title: 'Check your email',
        subtitle:
            "If there's an account for $masked, we've sent a reset link. It works once and expires after 1 hour.",
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPrimaryButton(label: 'Open mail app', onPressed: _openMail),
            const SizedBox(height: 12),
            AuthSecondaryButton(
              label: 'Back to log in',
              onPressed: () => context.go('/login'),
            ),
            const SizedBox(height: 24),
            Text(
              'No email after a few minutes? Check spam, or try again.',
              style: TextStyle(color: c.textTertiary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return PatientAuthShell(
      backLabel: 'Log in',
      onBack: () => context.go('/login'),
      title: 'Reset your password',
      subtitle:
          "Enter the email you use for Zyndio. We'll send you a link to set a new password.",
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
                style: TextStyle(color: c.textPrimary),
                decoration: authFieldDecoration(context),
                validator: (v) =>
                    (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
              ),
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Send reset link',
              loading: _isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
