import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../widgets/consent_row.dart';
import '../../widgets/demo_card.dart';
import '../../widgets/optional_card.dart';
import '../../widgets/step_progress.dart';
import 'consent_state.dart';

/// Pure view for screen 02 (Consent). Renders from [state] only — no
/// fetching, no backend calls. The screenshot harness builds it directly
/// from a fixture state; the interactive demo wires it to
/// [ConsentController].
class ConsentView extends StatelessWidget {
  const ConsentView({
    super.key,
    required this.state,
    this.onBack,
    this.onToggleDoc,
    this.onDocLink,
    this.onTogglePartner,
    this.onSubmit,
  });

  final ConsentState state;
  final VoidCallback? onBack;
  final ValueChanged<String>? onToggleDoc;
  final ValueChanged<String>? onDocLink;
  final VoidCallback? onTogglePartner;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Scaffold(
      backgroundColor: colors.bgCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            ZyndioSpace.s16,
            ZyndioSpace.s16,
            ZyndioSpace.s16,
            ZyndioSpace.s32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => onBack?.call(),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Back'),
                  ),
                  Text(
                    'Step 2 of 4',
                    style: ZyndioType.footnote.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: ZyndioSpace.s16),
              const StepProgress(value: 0.5),
              const SizedBox(height: ZyndioSpace.s24),
              Text('Before we begin', style: ZyndioType.title1.copyWith(color: colors.textPrimary)),
              const SizedBox(height: ZyndioSpace.s8),
              Text(
                'Please review and agree to how Zyndio cares for you and handles your health information.',
                style: ZyndioType.callout.copyWith(color: colors.textSecondary),
              ),
              if (state.isLoading) ..._loadingContent(context) else ..._loadedContent(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _loadingContent(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return [
      const SizedBox(height: ZyndioSpace.s24),
      Semantics(
        label: 'Loading',
        child: DemoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) _SkeletonRow(isLast: i == 2, colors: colors),
            ],
          ),
        ),
      ),
      const SizedBox(height: ZyndioSpace.s12),
      Text(
        'Loading the latest versions…',
        style: ZyndioType.footnote.copyWith(color: colors.textTertiary),
      ),
    ];
  }

  List<Widget> _loadedContent(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return [
      const SizedBox(height: ZyndioSpace.s24),
      DemoCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < state.docs.length; i++) ...[
              ConsentRow(
                title: state.docs[i].doc.title,
                subline: state.docs[i].doc.subline,
                checked: state.docs[i].checked,
                hasError: state.docs[i].hasError,
                showRequiredError: state.docs[i].showRequiredError,
                onToggle: () => onToggleDoc?.call(state.docs[i].doc.id),
                onLinkTap: () => onDocLink?.call(state.docs[i].doc.id),
              ),
              if (i != state.docs.length - 1)
                Divider(
                  height: 1,
                  color: colors.borderSubtle,
                  indent: ZyndioSpace.s16,
                  endIndent: ZyndioSpace.s16,
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: ZyndioSpace.s24),
      Text(
        'OPTIONAL',
        style: ZyndioType.footnote.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
      const SizedBox(height: ZyndioSpace.s8),
      OptionalCard(
        title: 'Share progress with my body composition partner',
        subtitle:
            'Only results your Zyndio clinician has reviewed. Turn this off any time in Settings, and future sharing stops.',
        value: state.partnerSharingOn,
        onChanged: (_) => onTogglePartner?.call(),
      ),
      const SizedBox(height: ZyndioSpace.s24),
      FilledButton(
        // Never disabled (C05: no disabled primary in this demo) — tapping
        // with something unticked shows inline validation instead.
        onPressed: () => onSubmit?.call(),
        child: const Text('Agree and continue'),
      ),
      const SizedBox(height: ZyndioSpace.s12),
      Text(
        'We keep a record of each version you agree to and when.',
        textAlign: TextAlign.center,
        style: ZyndioType.caption.copyWith(color: colors.textTertiary),
      ),
    ];
  }
}

/// A single loading-state skeleton row matching [ConsentRow]'s layout, so
/// nothing jumps when the real rows arrive. Kept private to this screen —
/// a shared `Skeleton` widget is introduced in Step 3 when a second screen
/// needs it.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.isLast, required this.colors});

  final bool isLast;
  final ZyndioColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: ZyndioSize.rowMin),
      padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s16, vertical: ZyndioSpace.s8),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          _bar(width: 24, height: 24, radius: 8),
          const SizedBox(width: ZyndioSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(width: 180, height: 16, radius: 8),
                const SizedBox(height: ZyndioSpace.s8),
                _bar(width: 110, height: 12, radius: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar({required double width, required double height, required double radius}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: colors.bgSunken, borderRadius: BorderRadius.circular(radius)),
    );
  }
}
