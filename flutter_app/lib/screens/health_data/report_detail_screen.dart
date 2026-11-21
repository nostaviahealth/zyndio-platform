import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/lab_report.dart';
import '../../providers/theme_provider.dart';
import '../../services/lab_report_file_opener.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import './widgets/health_widgets.dart';

/// TC-039: fixed error text when the report file can't be opened.
const reportFileOpenFailedMessage =
    "Couldn't open the report file. Please try again.";

class ReportDetailScreen extends ConsumerStatefulWidget {
  final LabReport report;

  const ReportDetailScreen({super.key, required this.report});

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _openingFile = false;

  /// Opens the report's file with a fresh short-lived signed link (see
  /// [LabReportFileOpener]); the link itself is never kept or shown.
  Future<void> _openReportFile(String pdfPath) async {
    if (_openingFile) return;
    setState(() => _openingFile = true);
    final opened = await LabReportFileOpener.open(pdfPath);
    if (!mounted) return;
    setState(() => _openingFile = false);
    if (!opened) {
      final c = Theme.of(context).extension<ZyndioColors>()!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text(reportFileOpenFailedMessage),
            backgroundColor: c.statusCritical),
      );
    }
  }

  /// Dynamic categories derived from the report's own data — no hardcoded list.
  List<String> get _categories {
    final cats = widget.report.markers
        .map((m) => m.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return ['All', ...cats];
  }

  @override
  Widget build(BuildContext context) {
    final isImmersive = ref.watch(themeProvider);
    final c = Theme.of(context).extension<ZyndioColors>()!;

    // Filter Logic — uses marker.category directly
    final markers = widget.report.markers.where((m) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = m.name.toLowerCase().contains(query);
      if (_selectedCategory == 'All') return matchesSearch;

      return matchesSearch && m.category == _selectedCategory;
    }).toList();

    final categories = _categories;

    return ZyndioDetailScaffold(
      title: widget.report.date,
      children: [
        // Report Header Card
        ZyndioCard(
          radius: 24,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Baseline',
                style: ZyndioType.headline.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                "Latest Report: ${widget.report.date}",
                style: ZyndioType.subhead.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 18),
              // Stats Row (equal height even when a label wraps)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    StatPill(
                      label: "Optimal",
                      count: widget.report.markers
                          .where((m) => m.isOptimal)
                          .length,
                      color: c.statusSuccess,
                      bg: c.statusSuccessSubtle,
                    ),
                    const SizedBox(width: 10),
                    StatPill(
                      label: "Normal",
                      count: widget.report.markers
                          .where((m) => m.isInRange)
                          .length,
                      color: c.statusWarning,
                      bg: c.statusWarningSubtle,
                    ),
                    const SizedBox(width: 10),
                    StatPill(
                      label: "Outliers",
                      count: widget.report.markers
                          .where((m) => m.isOutlier)
                          .length,
                      color: c.statusCritical,
                      bg: c.statusCriticalSubtle,
                    ),
                  ],
                ),
              ),
              if (widget.report.pdfPath != null) ...[
                const SizedBox(height: 16),
                ZyndioOutlineButton(
                  key: const Key('open-report-file'),
                  onTap: _openingFile
                      ? null
                      : () => _openReportFile(widget.report.pdfPath!),
                  icon: LucideIcons.fileText,
                  label: 'Open report file',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Search & Filter
        Container(
          decoration: zyndioCard(context, radius: 18),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: ZyndioType.subhead.copyWith(
              color: c.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: "Search biomarkers...",
              hintStyle: ZyndioType.subhead.copyWith(color: c.textTertiary),
              prefixIcon:
                  Icon(LucideIcons.search, size: 20, color: c.textTertiary),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ZyndioSegmentedTabs(
          labels: categories,
          selected: categories.indexOf(_selectedCategory),
          onSelected: (i) => setState(() => _selectedCategory = categories[i]),
        ),
        const SizedBox(height: 20),

        // Biomarker List
        if (markers.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                "No matching biomarkers found.",
                style: ZyndioType.subhead.copyWith(color: c.textSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: markers.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final marker = markers[index];
              return BiomarkerCard(
                marker: marker,
                isImmersive: isImmersive,
                history: [
                  {'date': widget.report.date, 'value': marker.value}
                ],
              );
            },
          ),
      ],
    );
  }
}
