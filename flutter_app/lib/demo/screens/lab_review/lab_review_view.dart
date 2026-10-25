import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../widgets/demo_card.dart';
import '../../widgets/doc_summary_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fictional_data_tag.dart';
import '../../widgets/identity_line.dart';
import '../../widgets/lab_value_row.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/zyndio_banner.dart';
import 'lab_review_state.dart';

/// Pure view for screen 04 (Lab review). Renders from [state] only — no
/// fetching, no backend calls. The screenshot harness builds it directly
/// from a fixture state; the interactive demo wires it to
/// [LabReviewController].
class LabReviewView extends StatelessWidget {
  const LabReviewView({
    super.key,
    required this.state,
    this.onBack,
    this.onSave,
    this.onSomethingWrong,
    this.onConfirmIdentity,
    this.onRemoveReport,
    this.onTryAnotherFile,
    this.onKeepAsIs,
    this.onDone,
  });

  final LabReviewState state;
  final VoidCallback? onBack;
  final VoidCallback? onSave;
  final VoidCallback? onSomethingWrong;
  final VoidCallback? onConfirmIdentity;
  final VoidCallback? onRemoveReport;
  final VoidCallback? onTryAnotherFile;
  final VoidCallback? onKeepAsIs;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Scaffold(
      backgroundColor: colors.bgCanvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(ZyndioSpace.s16, ZyndioSpace.s16, ZyndioSpace.s16, ZyndioSpace.s32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => onBack?.call(),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Labs'),
                  ),
                  const FictionalDataTag(),
                ],
              ),
              const SizedBox(height: ZyndioSpace.s8),
              Text('Check your results', style: ZyndioType.display.copyWith(color: colors.textPrimary)),
              const SizedBox(height: ZyndioSpace.s16),
              DocSummaryCard(
                title: state.docTitle,
                subtitle: state.docSubtitle,
                collectedLabel: state.docCollected,
              ),
              ..._body(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (state.isLoading) return _loadingBody(context);
    if (state.isMismatch) return _mismatchBody(context);
    if (state.isEmpty) return _emptyBody(context);
    return _valuesBody(context);
  }

  List<Widget> _loadingBody(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return [
      const SizedBox(height: ZyndioSpace.s12),
      const ZyndioBanner(
        variant: BannerVariant.info,
        message: "Reading your report. You can leave this screen. We'll let you know when your values are ready.",
      ),
      const SizedBox(height: ZyndioSpace.s16),
      Semantics(
        label: 'Loading',
        child: DemoCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  constraints: const BoxConstraints(minHeight: ZyndioSize.rowMin),
                  padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s16, vertical: ZyndioSpace.s16),
                  decoration: BoxDecoration(
                    border: i == 4 ? null : Border(bottom: BorderSide(color: colors.borderSubtle)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Skeleton(width: 140),
                      Skeleton(width: 48),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _mismatchBody(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return [
      const SizedBox(height: ZyndioSpace.s12),
      const ZyndioBanner(
        variant: BannerVariant.warning,
        message: "The name or date of birth on this report doesn't match your account. "
            "We've put it on hold, and your care team can see the hold.",
      ),
      const SizedBox(height: ZyndioSpace.s16),
      Text(
        'Is this your report? Names sometimes differ, for example a maiden name or a nickname.',
        style: ZyndioType.callout.copyWith(color: colors.textSecondary),
      ),
      const SizedBox(height: ZyndioSpace.s24),
      FilledButton(
        onPressed: () => onConfirmIdentity?.call(),
        child: const Text('Yes, this is my report'),
      ),
      const SizedBox(height: ZyndioSpace.s12),
      OutlinedButton(
        onPressed: () => onRemoveReport?.call(),
        child: const Text('No, remove this report'),
      ),
    ];
  }

  List<Widget> _emptyBody(BuildContext context) {
    return [
      const SizedBox(height: ZyndioSpace.s16),
      const EmptyState(
        icon: Icons.insert_drive_file_outlined,
        title: "We couldn't find lab values",
        message: 'The report is saved and your care team can still read it. '
            'You can also try a clearer photo or the PDF from your lab.',
      ),
      const SizedBox(height: ZyndioSpace.s24),
      FilledButton(
        onPressed: () => onTryAnotherFile?.call(),
        child: const Text('Try another photo or PDF'),
      ),
      const SizedBox(height: ZyndioSpace.s12),
      OutlinedButton(
        onPressed: () => onKeepAsIs?.call(),
        child: const Text('Keep report as is'),
      ),
    ];
  }

  List<Widget> _valuesBody(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final isSaved = state.banner == LabReviewBannerKind.saved;
    final isError = state.banner == LabReviewBannerKind.error;
    return [
      const SizedBox(height: ZyndioSpace.s12),
      if (isError)
        const ZyndioBanner(
          variant: BannerVariant.error,
          message: "Couldn't save. Check your connection and try again. Your edits are kept.",
        )
      else
        const IdentityLine(message: 'Name and date of birth match your account'),
      if (isSaved) ...[
        const SizedBox(height: ZyndioSpace.s12),
        const ZyndioBanner(
          variant: BannerVariant.success,
          message: 'Results saved. Your care team can see them now.',
        ),
      ],
      const SizedBox(height: ZyndioSpace.s16),
      DemoCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < state.values.length; i++) ...[
              LabValueRow(
                name: state.values[i].name,
                value: state.values[i].value,
                unit: state.values[i].unit,
                needsReviewReason: state.values[i].needsReviewReason,
              ),
              if (i != state.values.length - 1)
                Divider(height: 1, color: colors.borderSubtle, indent: ZyndioSpace.s16, endIndent: ZyndioSpace.s16),
            ],
          ],
        ),
      ),
      if (!isSaved && !isError) ...[
        const SizedBox(height: ZyndioSpace.s12),
        Text(
          'Your care team sees the original report next to every value.',
          style: ZyndioType.footnote.copyWith(color: colors.textTertiary),
        ),
      ],
      const SizedBox(height: ZyndioSpace.s24),
      if (isSaved)
        FilledButton(onPressed: () => onDone?.call(), child: const Text('Done'))
      else ...[
        FilledButton(onPressed: () => onSave?.call(), child: const Text('Save results')),
        const SizedBox(height: ZyndioSpace.s12),
        OutlinedButton(
          onPressed: () => onSomethingWrong?.call(),
          child: const Text('Something looks wrong'),
        ),
      ],
    ];
  }
}
