import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../data/lab_submission.dart';
import '../../providers/lab_analysis_provider.dart';
import '../../providers/lab_reports_provider.dart';

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

  Color get _accent => switch (submission.outcome) {
        LabSubmissionOutcome.analyzed => BrandColors.emerald500,
        LabSubmissionOutcome.needsReview => BrandColors.emerald500,
        LabSubmissionOutcome.identityHold => BrandColors.red400,
        _ => BrandColors.slate400,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showValues = submission.outcome == LabSubmissionOutcome.analyzed ||
        submission.outcome == LabSubmissionOutcome.needsReview;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Lab report'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Icon(_icon, size: 44, color: _accent),
            const SizedBox(height: 16),
            Text(
              submission.title,
              key: const Key('lab-submission-title'),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              submission.message,
              key: const Key('lab-submission-message'),
              style: TextStyle(fontSize: 15, height: 1.5, color: Colors.white.withValues(alpha: 0.75)),
            ),
            if (showValues && submission.markers.isNotEmpty) ...[
              const SizedBox(height: 24),
              for (final m in submission.markers) _MarkerRow(marker: m),
            ],
            const SizedBox(height: 32),
            FilledButton(
              key: const Key('lab-submission-done'),
              style: FilledButton.styleFrom(
                backgroundColor: BrandColors.emerald500,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              onPressed: () {
                ref.invalidate(labReportsProvider);
                ref.read(labAnalysisProvider.notifier).consumeResult();
                Navigator.of(context).pop();
              },
              child: const Text('Done', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({required this.marker});

  final LabSubmissionMarker marker;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(marker.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                if (marker.range.isNotEmpty && marker.range != '--')
                  Text('Range ${marker.range}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                if (marker.needsReview)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Needs review',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                  ),
              ],
            ),
          ),
          Text('${marker.value} ${marker.unit}'.trim(),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}
