import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../widgets/code_input.dart';
import '../../widgets/footer_links.dart';
import '../../widgets/info_card.dart';
import '../../widgets/rotating_arc_spinner.dart';
import '../../widgets/wordmark.dart';
import '../../widgets/zyndio_banner.dart';
import 'signin_state.dart';

/// Pure view for screen 01/07 (Sign-in). Renders from [state] only — no
/// fetching, no backend calls. The screenshot harness builds it directly
/// from a fixture state; the interactive demo wires it to
/// [SignInController].
class SignInView extends StatelessWidget {
  const SignInView({
    super.key,
    required this.state,
    this.onEmailChanged,
    this.onSendCode,
    this.onInviteLink,
    this.onCodeChanged,
    this.onContinue,
    this.onSendNewCode,
    this.onBack,
  });

  final SignInState state;
  final ValueChanged<String>? onEmailChanged;
  final VoidCallback? onSendCode;
  final VoidCallback? onInviteLink;
  final ValueChanged<String>? onCodeChanged;
  final VoidCallback? onContinue;
  final VoidCallback? onSendNewCode;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final content = state.stage == SignInStage.codeEntry
        ? _codeEntryContent(context)
        : _emailEntryContent(context);
    return Scaffold(
      backgroundColor: colors.bgCanvas,
      // The footer lives outside the scroll region, in its own fixed row at
      // the bottom of the Column, so it's always pinned there; the content
      // above it scrolls independently in the Expanded region instead of
      // ever overflowing the screen (e.g. the extra offline banner).
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(ZyndioSpace.s16, ZyndioSpace.s48, ZyndioSpace.s16, ZyndioSpace.s24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(ZyndioSpace.s16, 0, ZyndioSpace.s16, 28),
              child: FooterLinks(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _emailEntryContent(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return [
      const Wordmark(),
      if (state.isOffline) ...[
        const SizedBox(height: ZyndioSpace.s24),
        const ZyndioBanner(
          variant: BannerVariant.warning,
          message: "You're offline. Connect to the internet to get your code.",
        ),
      ],
      if (state.isLocked) ...[
        const SizedBox(height: ZyndioSpace.s24),
        ZyndioBanner(
          variant: BannerVariant.error,
          message: _lockoutMessage(state.lockedMinutesRemaining),
        ),
      ],
      const SizedBox(height: ZyndioSpace.s40),
      Text('Sign in to your care program', style: ZyndioType.title1.copyWith(color: colors.textPrimary)),
      const SizedBox(height: ZyndioSpace.s8),
      Text(
        "Use the email your Zyndio care team enrolled you with. We'll send a 6-digit code. No password needed.",
        style: ZyndioType.callout.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: ZyndioSpace.s32),
      Text(
        'Email',
        style: ZyndioType.subhead.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: ZyndioSpace.s8),
      _EmailField(
        key: const Key('signin-email-field'),
        value: state.email,
        autofocus: state.emailFieldFocused,
        errorText: state.errorText,
        onChanged: onEmailChanged,
      ),
      const SizedBox(height: ZyndioSpace.s24),
      FilledButton(
        // Never truly disabled (C05/C06: no disabled primary in this demo)
        // so the fill stays brand.primary; "sending" just ignores the tap.
        onPressed: () {
          if (!state.isSending) onSendCode?.call();
        },
        child: state.isSending
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RotatingArcSpinner(size: ZyndioSize.spinner, color: colors.brandOnPrimary),
                  const SizedBox(width: ZyndioSpace.s8 + 2),
                  const Text('Sending code'),
                ],
              )
            : const Text('Send code'),
      ),
      const SizedBox(height: ZyndioSpace.s12),
      OutlinedButton(
        onPressed: () => onInviteLink?.call(),
        child: const Text('I have an invite link'),
      ),
      if (state.showsInfoCard) ...[
        const SizedBox(height: ZyndioSpace.s32),
        const InfoCard(
          message: 'New to Zyndio? Accounts are created by your care team when you enroll. '
              'Ask them to send you an invite.',
        ),
      ],
    ];
  }

  List<Widget> _codeEntryContent(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => onBack?.call(),
          icon: const Icon(Icons.chevron_left),
          label: const Text('Email'),
        ),
      ),
      // TC-029 review (Clara H2): from the 5th wrong try the account is
      // locked; say so here, on the screen the patient is actually on, not
      // only on the email step.
      if (state.isLocked) ...[
        const SizedBox(height: ZyndioSpace.s16),
        ZyndioBanner(
          key: const Key('signin-code-locked'),
          variant: BannerVariant.error,
          message: _lockoutMessage(state.lockedMinutesRemaining),
        ),
      ],
      const SizedBox(height: ZyndioSpace.s16),
      Text('Enter your code', style: ZyndioType.title1.copyWith(color: colors.textPrimary)),
      const SizedBox(height: ZyndioSpace.s8),
      Text(
        'We sent a 6-digit code to ${maskEmail(state.email)}.',
        style: ZyndioType.callout.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: ZyndioSpace.s32),
      CodeInput(
        value: state.code,
        onChanged: onCodeChanged,
        autofocus: true,
        hasError: state.hasError,
      ),
      if (state.hasError) ...[
        const SizedBox(height: ZyndioSpace.s8),
        // TC-030 item 13 (Ava a76acc5 L1): announce the inline error. Without
        // a live region the message isn't read out when it appears, since the
        // CodeInput's own semantics label doesn't include the error text.
        Semantics(
          liveRegion: true,
          child: Text(
            key: const Key('signin-code-error'),
            state.errorText!,
            style: ZyndioType.footnote.copyWith(color: colors.statusCritical),
          ),
        ),
      ],
      const SizedBox(height: ZyndioSpace.s12),
      Text(
        'Code expires after 10 minutes. Paste works, and your keyboard can fill the code from email.',
        style: ZyndioType.footnote.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: ZyndioSpace.s24),
      // TC-030 item 14 (Ava a76acc5 L2): while locked there's nothing to do
      // here until the lock ends, so Continue and "Send a new code" are
      // disabled - a null onPressed greys them out and blocks taps.
      FilledButton(
        onPressed: state.isLocked ? null : () => onContinue?.call(),
        child: const Text('Continue'),
      ),
      const SizedBox(height: ZyndioSpace.s12),
      OutlinedButton(
        onPressed: state.isLocked ? null : () => onSendNewCode?.call(),
        child: const Text('Send a new code'),
      ),
    ];
  }
}

/// Lockout banner copy (TC-030 item 14): states the real remaining minutes
/// from `lockout.remaining(now)` and points to a next step, rather than a
/// fixed "15 minutes" with no alternative.
String _lockoutMessage(int minutesRemaining) =>
    'Too many attempts. Try again in $minutesRemaining min, or contact your care team.';

/// C09 text field, kept stateful so typing doesn't lose focus/cursor on the
/// rebuild each keystroke triggers upstream (a fresh [TextEditingController]
/// per build would reset the caret to the end every time).
class _EmailField extends StatefulWidget {
  const _EmailField({
    super.key,
    required this.value,
    required this.autofocus,
    required this.errorText,
    this.onChanged,
  });

  final String value;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  State<_EmailField> createState() => _EmailFieldState();
}

class _EmailFieldState extends State<_EmailField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _EmailField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: const [AutofillHints.email],
      decoration: InputDecoration(
        errorText: widget.errorText,
        errorMaxLines: 3,
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ZyndioRadius.sm),
          borderSide: BorderSide(color: colors.statusCritical, width: ZyndioBorder.control),
        ),
      ),
    );
  }
}
