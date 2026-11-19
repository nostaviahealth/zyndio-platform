import 'package:flutter/material.dart';
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
import '../../widgets/tc025/tc025_widgets.dart';

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

      final box = mounted ? (context.findRenderObject() as RenderBox?) : null;
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
          backgroundColor: Theme.of(context).extension<ZyndioColors>()!.statusCritical,
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
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final z = context.z25;
    final helperStyle = TextStyle(
      fontFamily: ZyndioType.family,
      fontSize: 14,
      height: 20 / 14,
      color: c.textSecondary,
    );

    return ZyndioDetailScaffold(
      title: 'Health Data Snapshot',
      onBack: () => context.pop(),
      trailing: const ZyndioPill('EXPORT', tone: ZyndioPillTone.brand, icon: LucideIcons.fileDown),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isGenerating) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: c.bgSunken,
                valueColor: AlwaysStoppedAnimation<Color>(c.brandPrimary),
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
              style: TextStyle(fontFamily: ZyndioType.family, color: c.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
          ],
          ZyndioGradientButton(
            label: 'Generate & Share PDF',
            icon: LucideIcons.fileDown,
            trailingArrow: false,
            loading: _isGenerating,
            onTap: _isGenerating ? null : _generateAndSharePdf,
          ),
        ],
      ),
      children: [
        // Description
        ZyndioCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: z.tileBg, shape: BoxShape.circle),
                child: Icon(LucideIcons.stethoscope, color: c.brandPrimary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clinician-Ready Health Passport',
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        color: c.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generate a comprehensive PDF snapshot of your health data — labs, vitals, sleep, nutrition, and protocols — designed for any doctor to review in minutes.',
                      style: helperStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Time Range Selector
        const ZyndioSectionLabel('Time Range'),
        Text(
          'Select the data window for vitals, sleep, and nutrition trends.',
          style: helperStyle,
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
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isSelected ? ZyndioGradients.segmentActive : null,
                    color: isSelected ? null : z.segmentBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _rangeOptions[index]['label'] as String,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      color: isSelected ? Colors.white : z.segmentText,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 28),

        // Section Toggles
        const ZyndioSectionLabel('Include Sections'),
        Text(
          'Choose which health data categories to include in the export.',
          style: helperStyle,
        ),
        const SizedBox(height: 12),

        Container(
          decoration: zyndioCard(context, radius: 22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(_sectionOptions.length, (index) {
              final option = _sectionOptions[index];
              final key = option['key'] as String;
              final isEnabled = _getSectionValue(key);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0)
                    Divider(height: 1, thickness: 1, indent: 70, color: c.borderSubtle),
                  GestureDetector(
                    onTap: () => _toggleSection(key, !isEnabled),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isEnabled ? z.tileBg : c.bgSunken,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              option['icon'] as IconData,
                              size: 20,
                              color: isEnabled ? c.brandPrimary : c.textTertiary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option['label'] as String,
                                  style: TextStyle(
                                    fontFamily: ZyndioType.family,
                                    color: c.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  option['description'] as String,
                                  style: helperStyle,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isEnabled ? c.brandPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: isEnabled ? c.brandPrimary : c.borderStrong,
                                width: 1.5,
                              ),
                            ),
                            child: isEnabled
                                ? Icon(LucideIcons.check, size: 15, color: c.brandOnPrimary)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
