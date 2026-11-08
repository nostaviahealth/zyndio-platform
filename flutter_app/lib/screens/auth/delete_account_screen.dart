import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../demo/widgets/code_input.dart';
import '../../utils/mask_email.dart';
import 'code_sign_in_screen.dart' show loginCodeErrorCopy;
import 'widgets/patient_auth_chrome.dart';

/// Ava 12-delete-account: reauth / confirm / deleting / error / deleted.
///
/// APP-01: invited patients sign in with an emailed code and have no
/// password, so with [reauthWithCode] the "confirm it's you" step emails a
/// fresh 6-digit code to [email] instead of asking for a password.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key, this.email, this.reauthWithCode = false});

  final String? email;
  final bool reauthWithCode;

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
  bool _codeSent = false;
  bool _sendingCode = false;
  String _code = '';

  String get _masked =>
      maskEmail(widget.email ?? 'jordan.rivera@example.com');

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = widget.email;
    if (email == null || _sendingCode) return;
    setState(() {
      _sendingCode = true;
      _fieldError = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).requestLoginCode(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _code = '';
      });
    } catch (e) {
      if (mounted) setState(() => _fieldError = loginCodeErrorCopy(e));
    } finally {
      if (mounted) setState(() => _sendingCode = false);
    }
  }

  void _onCodeReauthSubmit() {
    if (!RegExp(r'^\d{6}$').hasMatch(_code)) {
      setState(() => _fieldError = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _step = _Step.confirm;
      _fieldError = null;
      _bannerError = null;
    });
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
      final auth = ref.read(authNotifierProvider.notifier);
      if (widget.reauthWithCode) {
        await auth.deleteAccountWithCode(_code);
      } else {
        await auth.deleteAccount(_passwordController.text);
      }
      if (!mounted) return;
      setState(() => _step = _Step.deleted);
    } on PatientAuthException catch (e) {
      setState(() {
        if (widget.reauthWithCode && (e.code == 'reauth_failed' || e.code == 'locked')) {
          _step = _Step.reauth;
          _code = '';
          _fieldError = loginCodeErrorCopy(e);
        } else if (e.code == 'reauth_failed') {
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

    if (_step == _Step.reauth && widget.reauthWithCode) {
      return _codeReauth(c);
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

  Widget _codeReauth(ZyndioColors c) {
    return PatientAuthShell(
      backLabel: 'Account',
      onBack: () => context.pop(),
      title: "Confirm it's you",
      subtitle: _codeSent
          ? 'Enter the 6-digit code we sent to $_masked.'
          : "We'll email a 6-digit code to $_masked to continue deleting your account.",
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_codeSent) ...[
            CodeInput(
              key: const Key('delete-account-code'),
              value: _code,
              autofocus: true,
              hasError: _fieldError != null,
              onChanged: (v) => setState(() {
                _code = v;
                _fieldError = null;
              }),
            ),
            const SizedBox(height: 8),
          ],
          if (_fieldError != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(_fieldError!,
                  style: TextStyle(color: c.statusCritical, fontSize: 13)),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          if (_codeSent) ...[
            AuthPrimaryButton(label: 'Continue', onPressed: _onCodeReauthSubmit),
            const SizedBox(height: 12),
            AuthSecondaryButton(
              label: 'Send a new code',
              onPressed: _sendingCode ? null : _sendCode,
            ),
          ] else
            AuthPrimaryButton(
              label: _sendingCode ? 'Sending code' : 'Send code',
              loading: _sendingCode,
              onPressed: _sendCode,
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
