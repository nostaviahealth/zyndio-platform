import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../config/theme.dart';
import '../../models/health_data_snapshot.dart';
import '../../services/health_data_aggregator.dart';
import '../../services/pdf_report_generator.dart';
import '../../widgets/app_card.dart';

class ExportHealthDataScreen extends ConsumerStatefulWidget {
  const ExportHealthDataScreen({super.key});

  @override
  ConsumerState<ExportHealthDataScreen> createState() => _ExportHealthDataScreenState();
}

class _ExportHealthDataScreenState extends ConsumerState<ExportHealthDataScreen> {
  int _selectedRangeIndex = 1; // Default: 30 days
  bool _isGenerating = false;
  double _progress = 0.0;
  ExportSections _sections = const ExportSections();

  final List<Map<String, dynamic>> _rangeOptions = [
    {'label': '7 Days', 'days': 7},
    {'label': '30 Days', 'days': 30},
    {'label': '90 Days', 'days': 90},
  ];

  final List<Map<String, dynamic>> _sectionOptions = [
    {'key': 'demographics', 'label': 'Patient Demographics', 'icon': LucideIcons.user, 'description': 'Name, age, bio age, health grade'},
    {'key': 'intelligence', 'label': 'Longevity Intelligence', 'icon': LucideIcons.brain, 'description': 'Longevity score, health domains, disease risks'},
    {'key': 'labReports', 'label': 'Lab Reports & Biomarkers', 'icon': LucideIcons.testTube, 'description': 'All biomarker values, ranges, and interpretations'},
    {'key': 'wearableVitals', 'label': 'Wearable Vitals & Trends', 'icon': LucideIcons.activity, 'description': 'Heart rate, HRV, SpO2, steps, VO2 max'},
    {'key': 'sleepAnalysis', 'label': 'Sleep Analysis', 'icon': LucideIcons.moon, 'description': 'Sleep score, efficiency, stage distribution'},
    {'key': 'nutrition', 'label': 'Nutrition & Diet', 'icon': LucideIcons.utensilsCrossed, 'description': 'Calorie intake, macros, meal logs'},
    {'key': 'protocols', 'label': 'Active Health Protocols', 'icon': LucideIcons.clipboardList, 'description': 'Protocol adherence and 4-pillar breakdown'},
    {'key': 'menstrualCycle', 'label': 'Menstrual Cycle', 'icon': LucideIcons.heart, 'description': 'Cycle phase, predictions, flow history'},
    {'key': 'questionnaireBaseline', 'label': 'Questionnaire Baseline', 'icon': LucideIcons.fileQuestion, 'description': 'Self-reported health assessment'},
    {'key': 'appointments', 'label': 'Appointments', 'icon': LucideIcons.calendar, 'description': 'Recent and upcoming doctor visits'},
  ];

  bool _getSectionValue(String key) {
    switch (key) {
      case 'demographics': return _sections.demographics;
      case 'intelligence': return _sections.intelligence;
      case 'labReports': return _sections.labReports;
      case 'wearableVitals': return _sections.wearableVitals;
      case 'sleepAnalysis': return _sections.sleepAnalysis;
      case 'nutrition': return _sections.nutrition;
      case 'protocols': return _sections.protocols;
      case 'menstrualCycle': return _sections.menstrualCycle;
      case 'questionnaireBaseline': return _sections.questionnaireBaseline;
      case 'appointments': return _sections.appointments;
      default: return false;
    }
  }

  void _toggleSection(String key, bool value) {
    setState(() {
      switch (key) {
        case 'demographics': _sections = _sections.copyWith(demographics: value); break;
        case 'intelligence': _sections = _sections.copyWith(intelligence: value); break;
        case 'labReports': _sections = _sections.copyWith(labReports: value); break;
        case 'wearableVitals': _sections = _sections.copyWith(wearableVitals: value); break;
        case 'sleepAnalysis': _sections = _sections.copyWith(sleepAnalysis: value); break;
        case 'nutrition': _sections = _sections.copyWith(nutrition: value); break;
        case 'protocols': _sections = _sections.copyWith(protocols: value); break;
        case 'menstrualCycle': _sections = _sections.copyWith(menstrualCycle: value); break;
        case 'questionnaireBaseline': _sections = _sections.copyWith(questionnaireBaseline: value); break;
        case 'appointments': _sections = _sections.copyWith(appointments: value); break;
      }
    });
  }

  Future<void> _generateAndSharePdf() async {
    setState(() {
      _isGenerating = true;
      _progress = 0.0;
    });

    try {
      // Step 1: Aggregate data
      setState(() => _progress = 0.15);
      final days = _rangeOptions[_selectedRangeIndex]['days'] as int;
      final range = ExportDateRange(
        start: DateTime.now().subtract(Duration(days: days)),
        end: DateTime.now(),
        label: _rangeOptions[_selectedRangeIndex]['label'] as String,
      );

      final snapshot = await aggregateHealthData(ref, range, _sections);
      setState(() => _progress = 0.45);

      // Step 2: Generate PDF
      await Future.delayed(const Duration(milliseconds: 300)); // Brief pause for UX
      setState(() => _progress = 0.65);

      final pdfBytes = await PdfReportGenerator.generateReport(snapshot);
      setState(() => _progress = 0.85);

      // Step 3: Save to temp and share
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fileName = 'Zyndio_Health_Report_$dateStr.pdf';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      setState(() => _progress = 1.0);

      final box = context.mounted ? (context.findRenderObject() as RenderBox?) : null;
      final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

      await Future.delayed(const Duration(milliseconds: 400)); // Let progress bar finish

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Zyndio Report — $dateStr',
        text: 'My comprehensive health snapshot generated by Zyndio Intelligence Engine.',
        sharePositionOrigin: origin,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: BrandColors.red500,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: nc.isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: nc.scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: nc.cardSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: nc.cardBorder),
                        ),
                        child: Icon(LucideIcons.arrowLeft, color: nc.textPrimary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'EXPORT',
                            style: TextStyle(
                              color: BrandColors.indigo400,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Health Data Snapshot',
                            style: TextStyle(
                              color: nc.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: BrandColors.indigo500.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: BrandColors.indigo400.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(LucideIcons.fileDown, color: BrandColors.indigo400, size: 20),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Description
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: BrandColors.indigo500.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(LucideIcons.stethoscope, color: BrandColors.indigo400, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clinician-Ready Health Passport',
                                    style: TextStyle(color: nc.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Generate a comprehensive PDF snapshot of your health data — labs, vitals, sleep, nutrition, and protocols — designed for any doctor to review in minutes.',
                                    style: TextStyle(color: nc.textSecondary, fontSize: 12, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Time Range Selector
                      Text(
                        'Time Range',
                        style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select the data window for vitals, sleep, and nutrition trends.',
                        style: TextStyle(color: nc.textTertiary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(_rangeOptions.length, (index) {
                          final isSelected = _selectedRangeIndex == index;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedRangeIndex = index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: EdgeInsets.only(right: index < _rangeOptions.length - 1 ? 8 : 0),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: isSelected ? BrandColors.indigo500 : nc.cardSurface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? BrandColors.indigo400 : nc.cardBorder,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _rangeOptions[index]['label'] as String,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : nc.textSecondary,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 28),

                      // Section Toggles
                      Text(
                        'Include Sections',
                        style: TextStyle(color: nc.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose which health data categories to include in the export.',
                        style: TextStyle(color: nc.textTertiary, fontSize: 12),
                      ),
                      const SizedBox(height: 12),

                      ...List.generate(_sectionOptions.length, (index) {
                        final option = _sectionOptions[index];
                        final key = option['key'] as String;
                        final isEnabled = _getSectionValue(key);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _toggleSection(key, !isEnabled),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: nc.cardSurface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isEnabled
                                      ? BrandColors.indigo400.withValues(alpha: 0.4)
                                      : nc.cardBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isEnabled
                                          ? BrandColors.indigo500.withValues(alpha: 0.15)
                                          : nc.inputFill,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      option['icon'] as IconData,
                                      size: 18,
                                      color: isEnabled ? BrandColors.indigo400 : nc.iconSubtle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option['label'] as String,
                                          style: TextStyle(
                                            color: nc.textPrimary,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          option['description'] as String,
                                          style: TextStyle(color: nc.textTertiary, fontSize: 11.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isEnabled ? BrandColors.indigo500 : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isEnabled ? BrandColors.indigo400 : nc.iconSubtle,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: isEnabled
                                        ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: nc.cardSurfaceElevated,
                  border: Border(top: BorderSide(color: nc.cardBorder)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isGenerating) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: nc.inputFill,
                          valueColor: const AlwaysStoppedAnimation<Color>(BrandColors.indigo500),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _progress < 0.4
                            ? 'Aggregating health data...'
                            : _progress < 0.8
                                ? 'Rendering clinical PDF...'
                                : 'Preparing for share...',
                        style: TextStyle(color: nc.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _isGenerating ? null : _generateAndSharePdf,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: _isGenerating
                                ? null
                                : const LinearGradient(
                                    colors: [BrandColors.indigo500, BrandColors.indigo600],
                                  ),
                            color: _isGenerating ? nc.inputFill : null,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: _isGenerating
                                ? []
                                : [
                                    BoxShadow(
                                      color: BrandColors.indigo500.withValues(alpha: 0.4),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: _isGenerating
                              ? Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: nc.textSecondary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.fileDown, size: 18, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Generate & Share PDF',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
