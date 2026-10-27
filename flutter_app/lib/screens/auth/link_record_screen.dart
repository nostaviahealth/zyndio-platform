import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// Ava 13-link-record — fictional-data UI wired to matching RPCs / Edge.
class LinkRecordScreen extends ConsumerStatefulWidget {
  const LinkRecordScreen({super.key});

  @override
  ConsumerState<LinkRecordScreen> createState() => _LinkRecordScreenState();
}

class _LinkRecordScreenState extends ConsumerState<LinkRecordScreen> {
  String _step = 'intro'; // intro|choose|code|clinic|review|linked|locked|wrong
  final _codeCtrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authNotifierProvider.notifier).requestTelehealthLinkCode();
      if (!mounted) return;
      setState(() => _step = 'code');
    } on PatientAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code;
        if (e.code == 'rate_limited') _step = 'locked';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeemOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(authNotifierProvider.notifier)
          .redeemTelehealthLinkCode(_codeCtrl.text.trim());
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() => _step = 'linked');
      } else if (res['error'] == 'locked') {
        setState(() => _step = 'locked');
      } else {
        setState(() => _step = 'wrong');
      }
    } catch (_) {
      if (mounted) setState(() => _step = 'wrong');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeemClinic() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(authNotifierProvider.notifier)
          .redeemClinicLinkCode(_codeCtrl.text.trim());
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() => _step = 'linked');
      } else if (res['error'] == 'locked' || res['error'] == 'unavailable') {
        setState(() => _step = 'locked');
      } else if (res['error'] == 'conflict') {
        setState(() => _step = 'review');
      } else {
        setState(() => _step = 'wrong');
      }
    } catch (_) {
      if (mounted) setState(() => _step = 'wrong');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink() async {
    setState(() => _busy = true);
    try {
      await ref.read(authNotifierProvider.notifier).unlinkPatientRecord();
      if (!mounted) return;
      setState(() => _step = 'intro');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Scaffold(
      backgroundColor: c.bgCanvas,
      appBar: AppBar(
        title: const Text('Link your record'),
        backgroundColor: c.bgCanvas,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _body(c),
        ),
      ),
    );
  }

  Widget _body(ZyndioColors c) {
    switch (_step) {
      case 'choose':
        return _choose(c);
      case 'code':
        return _codeEntry(
          c,
          title: 'Enter the 6-digit code',
          subtitle:
              "If your details match a clinic record, we've sent a 6-digit code to your clinic's patient messages.",
          onSubmit: _redeemOtp,
        );
      case 'clinic':
        return _codeEntry(
          c,
          title: 'Enter your clinic code',
          subtitle: 'Use the code your clinic gave you. Dashes are optional.',
          onSubmit: _redeemClinic,
        );
      case 'wrong':
        return _message(
          c,
          title: 'That code didn\'t work',
          body: 'Check the digits and try again. After several wrong tries the code stops working.',
          primary: 'Try again',
          onPrimary: () => setState(() {
            _step = 'code';
            _codeCtrl.clear();
          }),
        );
      case 'locked':
        return _message(
          c,
          title: 'Try again later',
          body: 'Too many attempts. Wait a bit, then request a new code from your clinic messages.',
          primary: 'Back',
          onPrimary: () => setState(() => _step = 'intro'),
        );
      case 'review':
        return _message(
          c,
          title: 'No code yet?',
          body:
              'Codes usually arrive in a few minutes. If nothing comes, your clinic can confirm your identity and give you a clinic code instead.\n\nUntil your record is linked, no clinic data is shown in the app.',
          primary: 'I have a clinic code',
          onPrimary: () => setState(() {
            _step = 'clinic';
            _codeCtrl.clear();
          }),
          secondary: 'Send a new code',
          onSecondary: _sendCode,
        );
      case 'linked':
        return _message(
          c,
          title: 'You\'re linked',
          body:
              "We've also sent a notice to your email and your clinic's patient messages.",
          primary: 'Go to Today',
          onPrimary: () => Navigator.of(context).maybePop(),
          secondary: 'Not you? Unlink',
          onSecondary: _unlink,
        );
      case 'intro':
      default:
        return _intro(c);
    }
  }

  Widget _intro(ZyndioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Link your clinic record',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 12),
        Text(
          'To show your care plan and labs, we need to connect this app account to your clinic record. We\'ll never link on email or name alone.',
          style: TextStyle(fontSize: 15, height: 1.4, color: c.textSecondary),
        ),
        const Spacer(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: TextStyle(color: c.statusCritical)),
          ),
        FilledButton(
          onPressed: _busy ? null : () => setState(() => _step = 'choose'),
          child: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _choose(ZyndioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('How do you want to confirm?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Pick one. Either way, the code works once and only for your record.',
          style: TextStyle(fontSize: 15, height: 1.4, color: c.textSecondary),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borderSubtle),
          ),
          child: Column(
            children: [
              _chooseRow(
                c,
                icon: LucideIcons.messageSquare,
                title: "Send a code to my clinic's patient messages",
                subtitle: "We'll send a 6-digit code to your clinic's patient messages.",
                onTap: _busy ? null : _sendCode,
                showDivider: true,
              ),
              _chooseRow(
                c,
                icon: LucideIcons.fileText,
                title: 'I have a code from my clinic',
                subtitle: "Your clinic can give you a code that's only for you.",
                onTap: _busy
                    ? null
                    : () => setState(() {
                          _step = 'clinic';
                          _codeCtrl.clear();
                        }),
                showDivider: false,
              ),
            ],
          ),
        ),
        if (_busy) ...[
          const SizedBox(height: 16),
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ],
    );
  }

  Widget _chooseRow(
    ZyndioColors c, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool showDivider,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: c.borderSubtle))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: c.brandPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13, height: 1.35, color: c.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _codeEntry(
    ZyndioColors c, {
    required String title,
    required String subtitle,
    required Future<void> Function() onSubmit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 12),
        Text(subtitle, style: TextStyle(fontSize: 14, height: 1.4, color: c.textSecondary)),
        const SizedBox(height: 24),
        TextField(
          controller: _codeCtrl,
          decoration: const InputDecoration(labelText: 'Code'),
          textCapitalization: TextCapitalization.characters,
          enabled: !_busy,
        ),
        const Spacer(),
        FilledButton(
          onPressed: _busy ? null : onSubmit,
          child: _busy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _message(
    ZyndioColors c, {
    required String title,
    required String body,
    required String primary,
    required VoidCallback onPrimary,
    String? secondary,
    VoidCallback? onSecondary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 12),
        Text(body, style: TextStyle(fontSize: 15, height: 1.4, color: c.textSecondary)),
        const Spacer(),
        FilledButton(onPressed: _busy ? null : onPrimary, child: Text(primary)),
        if (secondary != null && onSecondary != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: _busy ? null : onSecondary, child: Text(secondary)),
        ],
      ],
    );
  }
}
