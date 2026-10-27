import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../utils/mask_email.dart';
import 'widgets/patient_auth_chrome.dart';

const _resendCooldownSeconds = 60;

/// Ava 09-verify-email: sent / resent / wait / expired / verified.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, this.email, this.token});

  final String? email;
  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

enum _VerifyState { sent, resent, verifying, verified, expired }

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  _VerifyState _state = _VerifyState.sent;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;
  bool _isBusy = false;

  String get _masked =>
      maskEmail(widget.email ?? 'jordan.rivera@example.com');

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      _state = _VerifyState.verifying;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _verify(widget.token!));
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownRemaining = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _cooldownRemaining -= 1;
        if (_cooldownRemaining <= 0) timer.cancel();
      });
    });
  }

  Future<void> _verify(String token) async {
    try {
      await ref.read(authNotifierProvider.notifier).verifyEmailToken(token);
      if (!mounted) return;
      setState(() => _state = _VerifyState.verified);
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _VerifyState.expired);
    }
  }

  Future<void> _resend() async {
    if (widget.email == null || _cooldownRemaining > 0 || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .resendVerification(widget.email!);
      if (!mounted) return;
      setState(() => _state = _VerifyState.resent);
      _startCooldown();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openMail() async {
    final uri = Uri.parse('mailto:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _VerifyState.verified) {
      return PatientAuthShell(
        title: 'Email confirmed',
        subtitle:
            'Thanks, Jordan. Next, link your clinic record so your care team\'s plan and results can show here.',
        body: Column(
          children: [
            const AuthHeroIcon(icon: LucideIcons.check),
            const SizedBox(height: 24),
            AuthPrimaryButton(
              label: 'Continue',
              onPressed: () => context.go('/link-record'),
            ),
          ],
        ),
      );
    }

    if (_state == _VerifyState.expired) {
      return PatientAuthShell(
        backLabel: 'Sign up',
        onBack: () => context.go('/signup'),
        title: 'This link has expired',
        subtitle:
            "Confirmation links work once and expire after 24 hours. We'll send you a fresh one.",
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthPrimaryButton(
              label: 'Send a new link',
              onPressed: widget.email == null ? null : _resend,
            ),
            const SizedBox(height: 12),
            AuthSecondaryButton(
              label: 'Log in',
              onPressed: () => context.go('/login'),
            ),
          ],
        ),
      );
    }

    final waiting = _cooldownRemaining > 0;
    final mins = (_cooldownRemaining ~/ 60).toString();
    final secs = (_cooldownRemaining % 60).toString().padLeft(2, '0');

    return PatientAuthShell(
      backLabel: 'Sign up',
      onBack: () => context.go('/signup'),
      hero: const AuthHeroIcon(
        icon: LucideIcons.mail,
        tone: AuthBannerTone.info,
      ),
      title: 'Check your email',
      subtitle:
          "If $_masked can be used for a new account, we've sent a link to confirm it. Open it on this phone to continue.",
      banner: _state == _VerifyState.resent
          ? const AuthStatusBanner(
              message: 'We sent another email. It can take a minute to arrive.',
              tone: AuthBannerTone.success,
            )
          : waiting
              ? AuthStatusBanner(
                  message:
                      'You can send another email in $_cooldownRemaining seconds.',
                  tone: AuthBannerTone.info,
                )
              : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthPrimaryButton(label: 'Open mail app', onPressed: _openMail),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            label: waiting ? 'Resend email in $mins:$secs' : 'Resend email',
            onPressed: waiting ? null : _resend,
          ),
          const SizedBox(height: 12),
          AuthSecondaryButton(
            label: 'Use a different email',
            outlined: false,
            onPressed: () => context.go('/signup'),
          ),
          const SizedBox(height: 24),
          const AuthInfoCard(
            message:
                "We won't show any health information until your email is confirmed.",
          ),
        ],
      ),
    );
  }
}
