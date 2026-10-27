import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import 'widgets/auth_background.dart';

const _resendCooldownSeconds = 60;

/// Ava 09-verify-email: sent / resent / wait (cooldown) / expired / verified.
/// Reached either right after sign-up (email known, no token - 'sent') or
/// via the verification deep link ('token' present - attempts verification
/// immediately, landing on 'verified' or 'expired').
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

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      _state = _VerifyState.verifying;
      WidgetsBinding.instance.addPostFrameCallback((_) => _verify(widget.token!));
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
      await ref.read(authNotifierProvider.notifier).resendVerification(widget.email!);
      if (!mounted) return;
      setState(() => _state = _VerifyState.resent);
      _startCooldown();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String get _cooldownLabel {
    final m = _cooldownRemaining ~/ 60;
    final s = _cooldownRemaining % 60;
    return 'Resend email in $m:${s.toString().padLeft(2, '0')}';
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
                  Text('Check your email',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(color: nc.textPrimary)),
                  const SizedBox(height: 16),
                  Text(_bodyCopy(), style: TextStyle(color: nc.textSecondary)),
                  const SizedBox(height: 24),
                  if (_state == _VerifyState.verifying)
                    const Center(child: CircularProgressIndicator()),
                  if (_state == _VerifyState.verified) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Continue to sign in'),
                      ),
                    ),
                  ],
                  if (_state == _VerifyState.expired) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.email == null || _isBusy ? null : _resend,
                        child: const Text('Send a new link'),
                      ),
                    ),
                  ],
                  if (_state == _VerifyState.sent || _state == _VerifyState.resent) ...[
                    TextButton(
                      onPressed: _cooldownRemaining > 0 || _isBusy ? null : _resend,
                      child: Text(
                        _cooldownRemaining > 0 ? _cooldownLabel : 'Resend email',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _bodyCopy() {
    switch (_state) {
      case _VerifyState.verifying:
        return 'Confirming your email...';
      case _VerifyState.verified:
        return 'Your email is confirmed. You can sign in now.';
      case _VerifyState.expired:
        return 'That link has expired or was already used. Request a new one below.';
      case _VerifyState.resent:
        return 'We sent another link to ${widget.email ?? 'your email'}. '
            'It can be used for a new account if this address isn\'t registered yet.';
      case _VerifyState.sent:
        return 'We sent a confirmation link to ${widget.email ?? 'your email'}. '
            'It can be used for a new account if this address isn\'t registered yet.';
    }
  }
}
