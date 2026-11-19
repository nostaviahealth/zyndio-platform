import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../data/lab_submission.dart';
import '../../providers/lab_analysis_provider.dart';
import '../../providers/lab_reports_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';

/// APP-05: what happened to the report the patient just submitted. The
/// server has already filed it (or refused a duplicate), so there is nothing
/// to verify or edit here - only to read. A held report shows the hold
/// message and none of its values (it may not be this patient's).
class LabReportSubmittedScreen extends ConsumerWidget {
  const LabReportSubmittedScreen({super.key, required this.submission});

  final LabSubmission submission;

  IconData get _icon => switch (submission.outcome) {
        LabSubmissionOutcome.analyzed => LucideIcons.checkCircle2,
        LabSubmissionOutcome.needsReview => LucideIcons.checkCircle2,
        LabSubmissionOutcome.identityHold => LucideIcons.shieldAlert,
        LabSubmissionOutcome.duplicate => LucideIcons.copy,
        _ => LucideIcons.clock,
      };

  /// (icon colour, icon-disc fill) for the outcome.
  (Color, Color) _accent(BuildContext context, ZyndioColors c) =>
      switch (submission.outcome) {
        LabSubmissionOutcome.analyzed => (c.statusSuccess, c.statusSuccessSubtle),
        LabSubmissionOutcome.needsReview => (c.statusSuccess, c.statusSuccessSubtle),
        LabSubmissionOutcome.identityHold => (c.statusCritical, c.statusCriticalSubtle),
        _ => (c.textSecondary, context.z25.tileBg),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _build(context, ref);
  }

  Widget _build(BuildContext context, WidgetRef ref) {
    final c = context.zc;
    final (accent, accentBg) = _accent(context, c);
    final showValues = submission.outcome == LabSubmissionOutcome.analyzed ||
        submission.outcome == LabSubmissionOutcome.needsReview;
    return ZyndioDetailScaffold(
      title: 'Lab report',
      bottomBar: ZyndioGradientButton(
        key: const Key('lab-submission-done'),
        label: 'Done',
        trailingArrow: false,
        onTap: () {
          ref.invalidate(labReportsProvider);
          ref.read(labAnalysisProvider.notifier).consumeResult();
          Navigator.of(context).pop();
        },
      ),
      children: [
        ZyndioCard(
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accentBg, shape: BoxShape.circle),
                child: Icon(_icon, size: 32, color: accent),
              ),
              const SizedBox(height: 18),
              Text(
                submission.title,
                key: const Key('lab-submission-title'),
                style: ZyndioType.title2.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                submission.message,
                key: const Key('lab-submission-message'),
                style: ZyndioType.subhead.copyWith(height: 1.5, color: c.textSecondary),
              ),
            ],
          ),
        ),
        if (showValues && submission.markers.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (final m in submission.markers) _MarkerRow(marker: m),
        ],
      ],
    );
  }
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({required this.marker});

  final LabSubmissionMarker marker;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ZyndioCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(marker.name,
                      style: ZyndioType.callout.copyWith(
                          fontWeight: FontWeight.w600, color: c.textPrimary)),
                  if (marker.range.isNotEmpty && marker.range != '--')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('Range ${marker.range}',
                          style: ZyndioType.footnote.copyWith(color: c.textTertiary)),
                    ),
                  if (marker.needsReview)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ZyndioPill('Needs review', tone: ZyndioPillTone.warning),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('${marker.value} ${marker.unit}'.trim(),
                style: ZyndioType.headline.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: ZyndioType.tabular,
                    color: c.textPrimary)),
          ],
        ),
      ),
    );
  }
}
