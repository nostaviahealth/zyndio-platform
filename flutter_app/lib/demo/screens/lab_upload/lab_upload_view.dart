import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../widgets/demo_card.dart';
import '../../widgets/demo_tab_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fictional_data_tag.dart';
import '../../widgets/rotating_arc_spinner.dart';
import '../../widgets/upload_row.dart';
import '../../widgets/zyndio_banner.dart';
import 'lab_upload_state.dart';

/// Pure view for screen 03 (Lab upload). Renders from [state] only — no
/// fetching, no backend calls. The screenshot harness builds it directly
/// from a fixture state; the interactive demo wires it to
/// [LabUploadController].
class LabUploadView extends StatelessWidget {
  const LabUploadView({
    super.key,
    required this.state,
    this.onUploadAnyway,
    this.onCancelDuplicate,
    this.onRetry,
    this.onPickPdf,
  });

  final LabUploadState state;
  final VoidCallback? onUploadAnyway;
  final VoidCallback? onCancelDuplicate;
  final VoidCallback? onRetry;

  /// Simulates picking "Choose a PDF" (the demo has no real file picker).
  final VoidCallback? onPickPdf;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Scaffold(
      backgroundColor: colors.bgCanvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(ZyndioSpace.s16, ZyndioSpace.s16, ZyndioSpace.s16, ZyndioSpace.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(alignment: Alignment.topRight, child: FictionalDataTag()),
                    const SizedBox(height: ZyndioSpace.s16),
                    Text('Labs', style: ZyndioType.display.copyWith(color: colors.textPrimary)),
                    const SizedBox(height: ZyndioSpace.s4),
                    Text(
                      "Add a lab report and we'll pull out the values for you and your care team.",
                      style: ZyndioType.callout.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(height: ZyndioSpace.s24),
                    _optionsCard(context),
                    const SizedBox(height: ZyndioSpace.s12),
                    _hintLine(context),
                    ..._bannerSection(context),
                    const SizedBox(height: ZyndioSpace.s32),
                    Text('Recent uploads', style: ZyndioType.title3.copyWith(color: colors.textPrimary)),
                    const SizedBox(height: ZyndioSpace.s12),
                    if (state.isEmpty)
                      const EmptyState(
                        icon: Icons.insert_drive_file_outlined,
                        title: 'No reports yet',
                        message: 'Reports you add will appear here, and your care team will see them too.',
                      )
                    else
                      _uploadsCard(context),
                  ],
                ),
              ),
            ),
            const DemoTabBar(selected: DemoTab.labs),
          ],
        ),
      ),
    );
  }

  Widget _optionsCard(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final rows = [
      const _ActionRow(
        icon: Icons.camera_alt_outlined,
        title: 'Scan with camera',
        subtitle: 'Multi-page, one photo per page',
      ),
      const _ActionRow(
        icon: Icons.photo_outlined,
        title: 'Choose from Photos',
        subtitle: 'Screenshots from a patient portal work too',
      ),
      _ActionRow(
        icon: Icons.insert_drive_file_outlined,
        title: 'Choose a PDF',
        subtitle: 'The file from your lab or patient portal',
        onTap: onPickPdf,
      ),
    ];
    return DemoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(height: 1, color: colors.borderSubtle, indent: ZyndioSpace.s16, endIndent: ZyndioSpace.s16),
          ],
        ],
      ),
    );
  }

  Widget _hintLine(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: ZyndioSize.iconSmall, color: colors.textTertiary),
        const SizedBox(width: ZyndioSpace.s8),
        Expanded(
          child: Text(
            'Make sure your name, date of birth and collection date are visible.',
            style: ZyndioType.footnote.copyWith(color: colors.textSecondary),
          ),
        ),
      ],
    );
  }

  List<Widget> _bannerSection(BuildContext context) {
    if (state.banner == LabUploadBannerKind.none) return const [];
    final Widget banner;
    switch (state.banner) {
      case LabUploadBannerKind.duplicate:
        banner = ZyndioBanner(
          variant: BannerVariant.warning,
          message:
              'This looks like the report you uploaded on ${state.duplicateDateLabel}. Upload it anyway?',
        );
      case LabUploadBannerKind.offline:
        banner = const ZyndioBanner(
          variant: BannerVariant.warning,
          message: "You're offline. Your report is saved on this phone and will upload when you're back online.",
        );
      case LabUploadBannerKind.error:
        banner = const ZyndioBanner(
          variant: BannerVariant.error,
          message: "Your upload didn't finish. Your photos are still on this phone, so you can try again.",
        );
      case LabUploadBannerKind.none:
        banner = const SizedBox.shrink();
    }
    return [
      const SizedBox(height: ZyndioSpace.s24),
      banner,
      if (state.banner == LabUploadBannerKind.duplicate) ...[
        const SizedBox(height: ZyndioSpace.s12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s8)),
                onPressed: () => onUploadAnyway?.call(),
                child: const FittedBox(child: Text('Upload anyway')),
              ),
            ),
            const SizedBox(width: ZyndioSpace.s12),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s8)),
                onPressed: () => onCancelDuplicate?.call(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    ];
  }

  Widget _uploadsCard(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return DemoCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < state.rows.length; i++) ...[
            _rowFor(context, state.rows[i]),
            if (i != state.rows.length - 1)
              Divider(height: 1, color: colors.borderSubtle, indent: ZyndioSpace.s16, endIndent: ZyndioSpace.s16),
          ],
        ],
      ),
    );
  }

  Widget _rowFor(BuildContext context, UploadRowState row) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final Widget leading = switch (row.icon) {
      UploadRowIcon.reading => RotatingArcSpinner(size: ZyndioSize.icon, color: colors.brandPrimary),
      UploadRowIcon.uploading => RotatingArcSpinner(size: ZyndioSize.icon, color: colors.brandPrimary),
      UploadRowIcon.onHold => Icon(Icons.warning_amber_rounded, color: colors.statusWarning),
      UploadRowIcon.queued => Icon(Icons.photo_outlined, color: colors.textTertiary),
      UploadRowIcon.failed => Icon(Icons.warning_amber_rounded, color: colors.statusCritical),
      UploadRowIcon.saved => Icon(Icons.insert_drive_file_outlined, color: colors.textTertiary),
    };
    return UploadRow(
      title: row.title,
      status: row.subline,
      leading: leading,
      badgeLabel: row.badgeLabel,
      badgeVariant: row.badgeVariant,
      progress: row.progress,
      onRetry: row.showRetry ? () => onRetry?.call() : null,
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.title, required this.subtitle, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      button: true,
      label: title,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ZyndioSize.rowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s16, vertical: ZyndioSpace.s8),
            child: Row(
              children: [
                Icon(icon, size: ZyndioSize.icon, color: colors.brandPrimary),
                const SizedBox(width: ZyndioSpace.s12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ZyndioType.headline.copyWith(color: colors.textPrimary)),
                      Text(subtitle, style: ZyndioType.footnote.copyWith(color: colors.textTertiary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
