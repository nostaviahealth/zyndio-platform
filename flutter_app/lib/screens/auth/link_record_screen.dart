import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import 'widgets/patient_auth_chrome.dart';

/// Ava 13-link-record — fictional-data UI wired to matching RPCs / Edge.
/// Choose / review / linked-notice copy left as Ava already approved.
class LinkRecordScreen extends ConsumerStatefulWidget {
  const LinkRecordScreen({super.key});

  @override
  ConsumerState<LinkRecordScreen> createState() => _LinkRecordScreenState();
}

class _LinkRecordScreenState extends ConsumerState<LinkRecordScreen> {
  String _step = 'intro'; // intro|choose|code|clinic|review|linked|locked|wrong
  final _codeCtrl = TextEditingController();
  final List<TextEditingController> _digits =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _digitFocus = List.generate(6, (_) => FocusNode());
  bool _busy = false;
  bool _codeWrong = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    for (final d in _digits) {
      d.dispose();
    }
    for (final f in _digitFocus) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpValue => _digits.map((d) => d.text).join();

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _codeWrong = false;
    });
    try {
      await ref.read(authNotifierProvider.notifier).requestTelehealthLinkCode();
      if (!mounted) return;
      setState(() => _step = 'code');
    } on PatientAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'rate_limited') _step = 'locked';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeemOtp() async {
    setState(() {
      _busy = true;
      _codeWrong = false;
    });
    try {
      final res = await ref
          .read(authNotifierProvider.notifier)
          .redeemTelehealthLinkCode(_otpValue);
      if (!mounted) return;
      if (res['ok'] == true) {
        setState(() => _step = 'linked');
      } else if (res['error'] == 'locked') {
        setState(() => _step = 'locked');
      } else {
        setState(() {
          _step = 'wrong';
          _codeWrong = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _step = 'wrong';
          _codeWrong = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeemClinic() async {
    setState(() {
      _busy = true;
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
      case 'wrong':
      case 'locked':
        return _otpEntry(c);
      case 'clinic':
        return _clinicEntry(c);
      case 'review':
        return _message(
          c,
          hero: const AuthHeroIcon(
            icon: LucideIcons.info,
            tone: AuthBannerTone.info,
          ),
          title: 'No code yet?',
          body:
              'Codes usually arrive within a few minutes. If nothing comes, your clinic can confirm it\'s you and give you a clinic code instead.',
          primary: 'I have a clinic code',
          onPrimary: () => setState(() {
            _step = 'clinic';
            _codeCtrl.clear();
          }),
          secondary: 'Send a new code',
          onSecondary: _sendCode,
          info:
              'Until your record is linked, no clinic data is shown in the app.',
        );
      case 'linked':
        return _linked(c);
      case 'intro':
      default:
        return _intro(c);
    }
  }

  Widget _intro(ZyndioColors c) {
    // Ava R2: intro sits inside the Today shell with a large title.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Today',
            style: TextStyle(
                fontSize: 28,
                height: 34 / 28,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.025 * 28,
                color: c.textPrimary)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: AuthHeroIcon(
                  icon: LucideIcons.flaskConical,
                  tone: AuthBannerTone.info,
                ),
              ),
              const SizedBox(height: 16),
              Text('Link your clinic record',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Your care plan and results appear here once we know your clinic record is yours. It takes about a minute.',
                style: TextStyle(
                    fontSize: 15, height: 1.4, color: c.textSecondary),
              ),
              const SizedBox(height: 16),
              AuthPrimaryButton(
                label: 'Link my record',
                onPressed: _busy ? null : () => setState(() => _step = 'choose'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AuthInfoCard(
          message:
              'We never link a record just because a name, email or birth date matches. You confirm it with a code only you can get.',
        ),
      ],
    );
  }

  Widget _choose(ZyndioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: () => setState(() => _step = 'intro'),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: c.brandPrimary,
            padding: EdgeInsets.zero,
          ),
          child: const Text('Back'),
        ),
        const SizedBox(height: 8),
        Text('How do you want to confirm?',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
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
                subtitle:
                    "We'll send a 6-digit code to your clinic's patient messages.",
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

  Widget _otpEntry(ZyndioColors c) {
    final locked = _step == 'locked';
    final wrong = _step == 'wrong' || _codeWrong;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: () => setState(() => _step = 'choose'),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: c.brandPrimary,
            padding: EdgeInsets.zero,
          ),
          child: const Text('Back'),
        ),
        const SizedBox(height: 8),
        if (locked) ...[
          const AuthStatusBanner(
            message:
                'Too many tries. You can try again in 15 minutes, or ask your clinic for a code.',
          ),
          const SizedBox(height: 16),
        ],
        Text('Enter your code',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(
          "If your details match a clinic record, we've sent a 6-digit code to your clinic's patient messages.",
          style: TextStyle(fontSize: 15, height: 1.4, color: c.textSecondary),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            final border = wrong ? c.statusCritical : c.borderStrong;
            return SizedBox(
              width: 48,
              height: 56,
              child: TextField(
                controller: _digits[i],
                focusNode: _digitFocus[i],
                enabled: !locked && !_busy,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
                maxLength: 1,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: c.bgSurface,
                  contentPadding: EdgeInsets.zero,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: wrong ? c.statusCritical : c.brandPrimary,
                        width: 2),
                  ),
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) {
                    _digitFocus[i + 1].requestFocus();
                  } else if (v.isEmpty && i > 0) {
                    _digitFocus[i - 1].requestFocus();
                  }
                  setState(() => _codeWrong = false);
                },
              ),
            );
          }),
        ),
        if (wrong) ...[
          const SizedBox(height: 12),
          Text("That code didn't work. Check it, or send a new one.",
              style: TextStyle(color: c.statusCritical, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        Text(
          'The code expires after 10 minutes and works once.',
          style: TextStyle(color: c.textTertiary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Link record',
          loading: _busy,
          onPressed: locked ? null : _redeemOtp,
        ),
        const SizedBox(height: 12),
        AuthSecondaryButton(
          // Ava R4: the server lockout only guards redeem, not new code
          // requests (patient-request-link-code never checks
          // patient_link_attempts), so "Send a new code" stays enabled here.
          label: 'Send a new code',
          onPressed: _busy ? null : _sendCode,
        ),
      ],
    );
  }

  Widget _clinicEntry(ZyndioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: () => setState(() => _step = 'choose'),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: c.brandPrimary,
            padding: EdgeInsets.zero,
          ),
          child: const Text('Back'),
        ),
        const SizedBox(height: 8),
        Text('Enter your clinic code',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(
          "Use the code your clinic gave you. It's only for you, so don't share it.",
          style: TextStyle(fontSize: 15, height: 1.4, color: c.textSecondary),
        ),
        const SizedBox(height: 24),
        AuthLabeledField(
          label: 'Clinic code',
          child: TextField(
            controller: _codeCtrl,
            textCapitalization: TextCapitalization.characters,
            enabled: !_busy,
            style: TextStyle(color: c.textPrimary),
            decoration: authFieldDecoration(context, hint: 'XXXX-XXXX'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '8 letters and numbers, like K7Q4-2MRX. It works once, within 72 hours of when your clinic gave it to you.',
          style: TextStyle(color: c.textTertiary, fontSize: 13, height: 18 / 13),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Link record',
          loading: _busy,
          onPressed: _redeemClinic,
        ),
      ],
    );
  }

  Widget _linked(ZyndioColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.statusWarningSubtle,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('FICTIONAL DATA',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.statusWarning)),
          ),
        ),
        const SizedBox(height: 16),
        const AuthHeroIcon(icon: LucideIcons.check),
        const SizedBox(height: 16),
        Text('Your record is linked',
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Your care plan and results from Brightway Weight Care will show here.',
          style: TextStyle(fontSize: 15, height: 1.4, color: c.textSecondary),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.borderSubtle),
          ),
          child: Column(
            children: [
              _summaryRow(c, 'Patient', 'Jordan Rivera'),
              _summaryRow(c, 'Clinic', 'Brightway Weight Care'),
              _summaryRow(c, 'In care since', 'Apr 2, 2026', last: true),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: 'Go to Today',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: 12),
        Text(
          "We've also sent a notice to your email and your clinic's patient messages.",
          style: TextStyle(color: c.textSecondary, fontSize: 13),
        ),
        TextButton(
          onPressed: _busy ? null : _unlink,
          child: Text('Not you? Unlink',
              style: TextStyle(color: c.brandPrimary)),
        ),
      ],
    );
  }

  Widget _summaryRow(ZyndioColors c, String k, String v, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 10),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(k,
                  style: TextStyle(color: c.textTertiary, fontSize: 13))),
          Expanded(
              child: Text(v,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600))),
        ],
      ),
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
    String? info,
    Widget? hero,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton(
          onPressed: () => setState(() => _step = 'choose'),
          style: TextButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: c.brandPrimary,
            padding: EdgeInsets.zero,
          ),
          child: const Text('Back'),
        ),
        const SizedBox(height: 8),
        if (hero != null) ...[
          hero,
          const SizedBox(height: 16),
        ],
        Text(title,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 12),
        Text(body,
            style: TextStyle(fontSize: 15, height: 1.4, color: c.textSecondary)),
        if (info != null) ...[
          const SizedBox(height: 16),
          AuthInfoCard(message: info),
        ],
        const SizedBox(height: 24),
        AuthPrimaryButton(label: primary, onPressed: _busy ? null : onPrimary),
        if (secondary != null && onSecondary != null) ...[
          const SizedBox(height: 12),
          AuthSecondaryButton(
              label: secondary, onPressed: _busy ? null : onSecondary),
        ],
      ],
    );
  }
}
