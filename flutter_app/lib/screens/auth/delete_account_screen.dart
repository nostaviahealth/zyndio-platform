import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/mask_email.dart';
import 'widgets/patient_auth_chrome.dart';

/// Ava 12-delete-account: reauth / confirm / deleting / error / deleted.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

enum _Step { reauth, confirm, deleting, deleted }

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  _Step _step = _Step.reauth;
  bool _isLoading = false;
  bool _obscure = true;
  String? _fieldError;
  String? _bannerError;

  String get _masked =>
      maskEmail(widget.email ?? 'jordan.rivera@example.com');

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _onReauthSubmit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _step = _Step.confirm;
      _fieldError = null;
      _bannerError = null;
    });
  }

  Future<void> _onConfirmDelete() async {
    setState(() {
      _step = _Step.deleting;
      _isLoading = true;
      _bannerError = null;
    });
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .deleteAccount(_passwordController.text);
      if (!mounted) return;
      setState(() => _step = _Step.deleted);
    } on PatientAuthException catch (e) {
      setState(() {
        if (e.code == 'reauth_failed') {
          _step = _Step.reauth;
          _fieldError = 'That password is incorrect.';
        } else {
          _step = _Step.confirm;
          _bannerError =
              "We couldn't delete your account. Nothing was changed. Check your connection and try again.";
        }
      });
    } catch (_) {
      setState(() {
        _step = _Step.confirm;
        _bannerError =
            "We couldn't delete your account. Nothing was changed. Check your connection and try again.";
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);

    if (_step == _Step.deleted) {
      return PatientAuthShell(
        hero: const AuthHeroIcon(icon: LucideIcons.check),
        title: 'Your account is deleted',
        subtitle:
            "We've sent a confirmation to $_masked. You've been signed out on every device.",
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthInfoCard(
              message:
                  'Records your clinic holds stay with your clinic. To ask about them, contact your care team.',
            ),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Done',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      );
    }

    if (_step == _Step.reauth) {
      return PatientAuthShell(
        backLabel: 'Account',
        onBack: () => context.pop(),
        title: "Confirm it's you",
        subtitle: 'Enter your password to continue deleting your account.',
        body: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthLabeledField(
                label: 'Password',
                errorText: _fieldError,
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  style: TextStyle(color: c.textPrimary),
                  decoration: authFieldDecoration(
                    context,
                    error: _fieldError != null,
                    suffix: TextButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      child: Text(_obscure ? 'Show' : 'Hide',
                          style: TextStyle(color: c.brandPrimary)),
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
              AuthPrimaryButton(label: 'Continue', onPressed: _onReauthSubmit),
            ],
          ),
        ),
      );
    }

    // confirm + deleting share content; spinner lives in the button
    return PatientAuthShell(
      backLabel: 'Account',
      onBack: () => setState(() => _step = _Step.reauth),
      title: 'Delete your account?',
      subtitle: "This can't be undone. We'll delete:",
      banner: _bannerError == null
          ? null
          : AuthStatusBanner(message: _bannerError!),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _bullet(c, LucideIcons.fileText,
              'Your app account, plus the lab uploads, logs and messages you added in the app.'),
          _bullet(c, LucideIcons.lock,
              "Your sign-in on every device. You'll be signed out everywhere."),
          _bullet(c, LucideIcons.flaskConical, 'The link to your clinic record.'),
          const SizedBox(height: 16),
          const AuthInfoCard(
            icon: LucideIcons.info,
            message:
                "Records your clinic holds, like visit notes and prescriptions, stay with your clinic. Deleting the app doesn't cancel your care program.",
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: _step == _Step.deleting
                ? 'Deleting account'
                : 'Delete my account',
            loading: _step == _Step.deleting || _isLoading,
            destructive: true,
            onPressed: _onConfirmDelete,
          ),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            label: 'Keep my account',
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }

  Widget _bullet(ZyndioColors c, IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: c.textPrimary, fontSize: 15, height: 22 / 15)),
          ),
        ],
      ),
    );
  }
}
