import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../models/lab_report.dart';
import '../../providers/theme_provider.dart';
import '../../services/lab_report_file_opener.dart';
import './widgets/health_widgets.dart';

/// TC-039: fixed error text when the report file can't be opened.
const reportFileOpenFailedMessage = "Couldn't open the report file. Please try again.";

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(reportFileOpenFailedMessage), backgroundColor: Colors.red),
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

    // Filter Logic — uses marker.category directly
    final markers = widget.report.markers.where((m) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = m.name.toLowerCase().contains(query);
          if (_selectedCategory == 'All') return matchesSearch;
          
          return matchesSearch && m.category == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: isImmersive ? Colors.transparent : const Color(0xFFF9FAFB),
      extendBodyBehindAppBar: isImmersive,
      appBar: AppBar(
        title: Text(widget.report.date, style: TextStyle(color: BrandColors.dark, fontWeight: FontWeight.bold)),
        backgroundColor: isImmersive ? Colors.transparent : Colors.white,
        elevation: 0,
        foregroundColor: BrandColors.dark,
        centerTitle: true,
      ),
      body: Stack(
         fit: StackFit.expand,
         children: [
            if (isImmersive)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFF0F9FF), Colors.white],
                    ),
                  ),
                ),
              ),

             SafeArea(
               child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          // Report Header Card
                          ImmersiveWrapper(
                              isImmersive: isImmersive,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                      color: isImmersive ? Colors.white.withOpacity(0.90) : Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: isImmersive ? Border.all(color: BrandColors.slate200.withOpacity(0.6)) : Border.all(color: Colors.white),
                                      boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))
                                      ]
                                  ),
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                          Text('Your Baseline', style: const TextStyle(
                                              fontSize: 18, 
                                              fontWeight: FontWeight.bold, 
                                              color: BrandColors.dark
                                          )),
                                          const SizedBox(height: 4),
                                          Text("Latest Report: ${widget.report.date}", style: const TextStyle(fontSize: 13, color: BrandColors.slate500)),
                                          const SizedBox(height: 20),
                                          // Stats Row
                                          Row(
                                              children: [
                                                  StatPill(
                                                      label: "Optimal", 
                                                      count: widget.report.markers.where((m) => m.isOptimal).length, 
                                                      color: const Color(0xFF10B981), 
                                                      bg: const Color(0xFFDCFCE7)
                                                  ),
                                                  const SizedBox(width: 12),
                                                  StatPill(
                                                      label: "Normal", 
                                                      count: widget.report.markers.where((m) => m.isInRange).length, 
                                                      color: const Color(0xFFF59E0B), 
                                                      bg: const Color(0xFFFEF3C7)
                                                  ),
                                                  const SizedBox(width: 12),
                                                  StatPill(
                                                      label: "Outliers", 
                                                      count: widget.report.markers.where((m) => m.isOutlier).length, 
                                                      color: const Color(0xFFEF4444), 
                                                      bg: const Color(0xFFFEE2E2)
                                                  ),
                                              ],
                                          ),
                                          if (widget.report.pdfPath != null) ...[
                                              const SizedBox(height: 16),
                                              OutlinedButton.icon(
                                                  key: const Key('open-report-file'),
                                                  onPressed: _openingFile ? null : () => _openReportFile(widget.report.pdfPath!),
                                                  icon: const Icon(LucideIcons.fileText, size: 18),
                                                  label: const Text('Open report file'),
                                                  style: OutlinedButton.styleFrom(
                                                      foregroundColor: BrandColors.dark,
                                                      side: const BorderSide(color: BrandColors.slate200),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                              ),
                                          ],
                                      ],
                                  ),
                              ),
                          ),
                          const SizedBox(height: 24),

                          // Search & Filter
                          TextField(
                              onChanged: (v) => setState(() => _searchQuery = v),
                              decoration: InputDecoration(
                                  hintText: "Search biomarkers...",
                                  prefixIcon: const Icon(LucideIcons.search, size: 20, color: BrandColors.slate400),
                                  filled: true,
                                  fillColor: isImmersive ? Colors.white.withOpacity(0.90) : Colors.white,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 16)
                              ),
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                  children: _categories.map((cat) {
                                      final isSelected = _selectedCategory == cat;
                                      return Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: FilterChip(
                                              label: Text(cat),
                                              selected: isSelected,
                                              onSelected: (v) => setState(() => _selectedCategory = cat),
                                              backgroundColor: isImmersive ? Colors.white.withOpacity(0.90) : Colors.white,
                                              selectedColor: BrandColors.dark,
                                              labelStyle: TextStyle(
                                                  color: isSelected ? Colors.white : BrandColors.slate600,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600
                                              ),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : BrandColors.slate200)),
                                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                              showCheckmark: false,
                                              elevation: 0,
                                          ),
                                      );
                                  }).toList(),
                              ),
                          ),
                          const SizedBox(height: 24),

                          // Biomarker List
                          if (markers.isEmpty)
                              const Padding(padding: EdgeInsets.all(32), child: Center(child: Text("No matching biomarkers found.")))
                          else
                              ListView.separated(
                                  shrinkWrap: true,
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
                          const SizedBox(height: 40),
                      ]
                  )
               ),
             ),
         ]
      )
    );
  }
}
