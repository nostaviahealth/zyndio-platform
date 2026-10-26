import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/lab_report.dart';
import '../../providers/lab_reports_provider.dart';
import '../../providers/patient_provider.dart';
import '../../data/health_data_repository.dart';
import './report_detail_screen.dart';

class MyLabRecordsScreen extends ConsumerWidget {
  const MyLabRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(labReportsProvider);

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: Text('My Lab Records', style: TextStyle(fontWeight: FontWeight.bold, color: context.nc.textPrimary)),
        backgroundColor: context.nc.scaffoldBg,
        elevation: 0,
        foregroundColor: context.nc.textPrimary,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: context.nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.fileText, size: 48, color: context.nc.textTertiary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text("No Records Found", style: TextStyle(fontSize: 18, color: context.nc.textSecondary)),
                ],
              ),
            );
          }
          
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final report = reports[index];
              return _LabRecordCard(report: report);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _LabRecordCard extends ConsumerWidget {
  final LabReport report;

  const _LabRecordCard({required this.report});

  Future<void> _deleteReport(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.nc.cardSurfaceElevated,
        title: Text("Delete Report?", style: TextStyle(color: context.nc.textPrimary)),
        content: Text("This action cannot be undone.", style: TextStyle(color: context.nc.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text("Cancel", style: TextStyle(color: context.nc.textSecondary))
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete. Please checking your connection or permissions.'), backgroundColor: Colors.red));
             }
          }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Format Date
    final date = DateTime.tryParse(report.date) ?? DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    return Container(
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.nc.cardBorder),
        boxShadow: [
          BoxShadow(color: context.nc.shadowColor, blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
             Navigator.push(context, MaterialPageRoute(builder: (c) => ReportDetailScreen(report: report)));
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: context.nc.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.nc.cardBorder),
                  ),
                  child: Center(
                    child: Icon(LucideIcons.calendar, color: context.nc.textTertiary, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: context.nc.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${report.markers.length} markers',
                        style: TextStyle(color: context.nc.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(LucideIcons.trash2, size: 20, color: context.nc.textTertiary.withOpacity(0.5)),
                  onPressed: () => _deleteReport(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
