import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../models/lab_report.dart';
import 'lab_shared_widgets.dart';

class BrandLabAnalysisDashboard extends StatefulWidget {
  final LabReport report;
  final VoidCallback? onBack;
  final Function(LabMarker marker)? onDeepDive;

  const BrandLabAnalysisDashboard({
    super.key,
    required this.report,
    this.onBack,
    this.onDeepDive,
  });

  @override
  State<BrandLabAnalysisDashboard> createState() => _BrandLabAnalysisDashboardState();
}

class _BrandLabAnalysisDashboardState extends State<BrandLabAnalysisDashboard> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

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
    final markers = widget.report.markers.where((m) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = m.name.toLowerCase().contains(query);
      if (_selectedCategory == 'All') return matchesSearch;
      return matchesSearch && m.category == _selectedCategory;
    }).toList();

    return Container(
      color: const Color(0xFFF9FAFB),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReportSummaryCard(),
                    const SizedBox(height: 24),
                    _buildSearchAndFilter(),
                    const SizedBox(height: 24),
                    if (markers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            "No matching biomarkers found.",
                            style: TextStyle(color: BrandColors.slate500),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: markers.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final marker = markers[index];
                          return BrandBiomarkerCard(
                            marker: marker,
                            onDeepDive: widget.onDeepDive != null 
                              ? () => widget.onDeepDive!(marker) 
                              : null,
                          );
                        },
                      ),
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'Powered by Zyndio Lab Intelligence',
                        style: TextStyle(
                          fontSize: 10,
                          color: BrandColors.slate400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (widget.onBack != null)
            GestureDetector(
              onTap: widget.onBack,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: BrandColors.slate200.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.arrowLeft, color: BrandColors.dark, size: 22),
              ),
            )
          else
            const SizedBox(width: 42),

          Text(
            widget.report.date,
            style: const TextStyle(
              color: BrandColors.dark,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildReportSummaryCard() {
    final optimalCount = widget.report.markers.where((m) => m.isOptimal).length;
    final normalCount = widget.report.markers.where((m) => m.isInRange).length;
    final outlierCount = widget.report.markers.where((m) => m.isOutlier).length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BrandColors.slate200.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.report.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: BrandColors.dark),
          ),
          if (widget.report.labName != null) ...[
            const SizedBox(height: 4),
            Text(
              "Source: ${widget.report.labName}",
              style: const TextStyle(fontSize: 13, color: BrandColors.slate500),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              BrandStatPill(
                label: "Optimal",
                count: optimalCount,
                color: const Color(0xFF10B981),
                bg: const Color(0xFFDCFCE7),
              ),
              const SizedBox(width: 12),
              BrandStatPill(
                label: "Normal",
                count: normalCount,
                color: const Color(0xFFF59E0B),
                bg: const Color(0xFFFEF3C7),
              ),
              const SizedBox(width: 12),
              BrandStatPill(
                label: "Outliers",
                count: outlierCount,
                color: const Color(0xFFEF4444),
                bg: const Color(0xFFFEE2E2),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        TextField(
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: "Search biomarkers...",
            prefixIcon: const Icon(LucideIcons.search, size: 20, color: BrandColors.slate400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: BrandColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: BrandColors.slate200),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                  backgroundColor: Colors.white,
                  selectedColor: BrandColors.dark,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : BrandColors.slate600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : BrandColors.slate200,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  showCheckmark: false,
                  elevation: 0,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
