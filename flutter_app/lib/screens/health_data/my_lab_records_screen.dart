import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/lab_report.dart';
import '../../providers/lab_reports_provider.dart';
import '../../providers/patient_provider.dart';
import '../../data/health_data_repository.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import './report_detail_screen.dart';

class MyLabRecordsScreen extends ConsumerWidget {
  const MyLabRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final reportsAsync = ref.watch(labReportsProvider);

    return ZyndioDetailScaffold(
      title: 'My Lab Records',
      onBack: () => Navigator.pop(context),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
              children: const [
                _StateNote(icon: LucideIcons.fileText, text: "No Records Found"),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            itemCount: reports.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final report = reports[index];
              return _LabRecordCard(report: report);
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: c.brandPrimary)),
        error: (_, __) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: const [
            _StateNote(
                icon: LucideIcons.triangleAlert, text: labReportsLoadFailedMessage),
          ],
        ),
      ),
    );
  }
}

/// Empty / error note: the design-system state card layout (icon disc +
/// one line of copy) for states that only have a single message.
class _StateNote extends StatelessWidget {
  const _StateNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: zyndioCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.z25.tileBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: c.textPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: ZyndioType.headline.copyWith(
              letterSpacing: -0.2,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LabRecordCard extends ConsumerWidget {
  final LabReport report;

  const _LabRecordCard({required this.report});

  Future<void> _deleteReport(BuildContext context, WidgetRef ref) async {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.bgSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Delete Report?", style: ZyndioType.headline.copyWith(color: c.textPrimary)),
        content: Text("This action cannot be undone.", style: ZyndioType.subhead.copyWith(color: c.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("Cancel",
                style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: c.statusCritical,
              textStyle: const TextStyle(
                  fontFamily: ZyndioType.family, fontWeight: FontWeight.w600),
            ),
            child: const Text("Delete")
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final profile = ref.read(patientProfileProvider).value;
      if (profile != null) {
          final success = await HealthDataRepository.deleteLabReport(report.id, profile.id, null);
          if (success) {
            ref.invalidate(labReportsProvider);
            if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report deleted')));
            }
          } else {
             if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text(labReportDeleteFailedMessage), backgroundColor: c.statusCritical));
             }
          }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    // Format Date
    final date = DateTime.tryParse(report.date) ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    return ZyndioCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
      onTap: () {
         Navigator.push(context, MaterialPageRoute(builder: (c) => ReportDetailScreen(report: report)));
      },
      child: Row(
        children: [
          const ZyndioIconTile(
            icon: LucideIcons.calendar,
            tint: ZyndioTint.violet,
            size: 48,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: ZyndioType.callout.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: ZyndioType.tabular,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report.markers.length} markers',
                  style: ZyndioType.footnote.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(LucideIcons.trash2, size: 20, color: c.textTertiary),
            onPressed: () => _deleteReport(context, ref),
          ),
        ],
      ),
    );
  }
}
