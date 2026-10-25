import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lab_analysis_provider.dart';
import '../../providers/lab_reports_provider.dart';
import '../../providers/patient_provider.dart';
import './lab_report_verification_screen.dart';
import '../../models/lab_report.dart';
import '../../providers/navbar_provider.dart';
import './widgets/health_widgets.dart'; // Shared Widgets
import '../../providers/theme_provider.dart';
import '../../utils/clinical_intelligence.dart';
import '../../utils/unit_converter.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/health_data_repository.dart';
import '../wearables/widgets/dashboard_card_style.dart';
import '../../data/mock_panels.dart';

class HealthDataScreen extends ConsumerStatefulWidget {
  final String reportType;
  const HealthDataScreen({super.key, this.reportType = 'Blood'});

  @override
  ConsumerState<HealthDataScreen> createState() => _HealthDataScreenState();
}



class _HealthDataScreenState extends ConsumerState<HealthDataScreen> {
  // Selection State
  String? _selectedReportId;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _showSampleData = false;
  List<LabReport>? _cachedSampleReports;
  
  Map<String, dynamic> _getMarkerDefaults(String name) {
    switch (name) {
      // Metabolic Panel
      case 'Glucose': return {'base': 90.0, 'unit': 'mg/dL', 'range': '70-99'};
      case 'BUN': return {'base': 14.0, 'unit': 'mg/dL', 'range': '7-20'};
      case 'Creatinine': return {'base': 1.0, 'unit': 'mg/dL', 'range': '0.7-1.3'};
      case 'eGFR': return {'base': 95.0, 'unit': 'mL/min/1.73m²', 'range': '>90'};
      case 'Sodium': return {'base': 140.0, 'unit': 'mEq/L', 'range': '136-145'};
      case 'Potassium': return {'base': 4.2, 'unit': 'mEq/L', 'range': '3.5-5.1'};
      case 'Chloride': return {'base': 102.0, 'unit': 'mEq/L', 'range': '98-107'};
      case 'Calcium': return {'base': 9.4, 'unit': 'mg/dL', 'range': '8.6-10.2'};
      case 'Protein Total': return {'base': 7.1, 'unit': 'g/dL', 'range': '6.0-8.3'};
      case 'Albumin': return {'base': 4.4, 'unit': 'g/dL', 'range': '3.5-5.0'};
      case 'Globulin': return {'base': 2.7, 'unit': 'g/dL', 'range': '2.0-3.5'};
      case 'Bilirubin Total': return {'base': 0.6, 'unit': 'mg/dL', 'range': '0.1-1.2'};
      case 'ALP': return {'base': 65.0, 'unit': 'U/L', 'range': '44-147'};
      case 'AST': return {'base': 22.0, 'unit': 'U/L', 'range': '10-40'};
      case 'ALT': return {'base': 25.0, 'unit': 'U/L', 'range': '7-55'};

      // Lipid Panel
      case 'Cholesterol Total': return {'base': 180.0, 'unit': 'mg/dL', 'range': '<200'};
      case 'Triglycerides': return {'base': 110.0, 'unit': 'mg/dL', 'range': '<150'};
      case 'HDL': return {'base': 55.0, 'unit': 'mg/dL', 'range': '>40'};
      case 'LDL': return {'base': 95.0, 'unit': 'mg/dL', 'range': '<100'};
      case 'VLDL': return {'base': 22.0, 'unit': 'mg/dL', 'range': '2-30'};

      // CBC
      case 'WBC': return {'base': 6.4, 'unit': 'x10E3/uL', 'range': '3.4-10.8'};
      case 'RBC': return {'base': 4.8, 'unit': 'x10E6/uL', 'range': '4.1-5.8'};
      case 'Hemoglobin': return {'base': 14.2, 'unit': 'g/dL', 'range': '13.0-17.0'};
      case 'Hematocrit': return {'base': 42.0, 'unit': '%', 'range': '37-49'};
      case 'MCV': return {'base': 88.0, 'unit': 'fL', 'range': '80-100'};
      case 'MCH': return {'base': 29.0, 'unit': 'pg', 'range': '27-33'};
      case 'MCHC': return {'base': 34.0, 'unit': 'g/dL', 'range': '32-36'};
      case 'RDW': return {'base': 12.5, 'unit': '%', 'range': '11.0-15.0'};
      case 'Platelets': return {'base': 240.0, 'unit': 'x10E3/uL', 'range': '150-450'};
      
      // Diff
      case 'Neutrophils': return {'base': 55.0, 'unit': '%', 'range': '40-70'};
      case 'Lymphocytes': return {'base': 32.0, 'unit': '%', 'range': '20-44'};
      case 'Monocytes': return {'base': 8.0, 'unit': '%', 'range': '2-10'};
      case 'Eosinophils': return {'base': 3.0, 'unit': '%', 'range': '0-5'};
      case 'Basophils': return {'base': 0.5, 'unit': '%', 'range': '0-2'};

      // Vitamins & Minerals
      case 'Vitamin D': return {'base': 45.0, 'unit': 'ng/mL', 'range': '30-100'};
      case 'Vitamin B12': return {'base': 600.0, 'unit': 'pg/mL', 'range': '200-1100'};
      case 'Folate': return {'base': 14.0, 'unit': 'ng/mL', 'range': '>5.4'};
      case 'Iron': return {'base': 95.0, 'unit': 'ug/dL', 'range': '40-190'};
      case 'TIBC': return {'base': 320.0, 'unit': 'ug/dL', 'range': '250-450'};
      case 'Ferritin': return {'base': 120.0, 'unit': 'ng/mL', 'range': '30-400'};
      case 'Transferrin': return {'base': 250.0, 'unit': 'mg/dL', 'range': '200-370'};

      // Thyroid
      case 'TSH': return {'base': 2.1, 'unit': 'mIU/L', 'range': '0.4-4.1'};
      case 'Free T3': return {'base': 3.2, 'unit': 'pg/mL', 'range': '2.3-4.2'};
      case 'Free T4': return {'base': 1.2, 'unit': 'ng/dL', 'range': '0.8-1.8'};

      // Hormones & Metabolic
      case 'Testosterone': return {'base': 650.0, 'unit': 'ng/dL', 'range': '250-1100'};
      case 'Estradiol': return {'base': 25.0, 'unit': 'pg/mL', 'range': '10-40'};
      case 'Cortisol': return {'base': 12.0, 'unit': 'ug/dL', 'range': '5-23'};
      case 'Insulin': return {'base': 8.0, 'unit': 'uIU/mL', 'range': '2-20'};
      case 'HbA1c': return {'base': 5.2, 'unit': '%', 'range': '<5.7'};

      // Inflammatory/Advanced Cardio
      case 'hs-CRP': return {'base': 0.8, 'unit': 'mg/L', 'range': '<1.0'};
      case 'Homocysteine': return {'base': 8.5, 'unit': 'umol/L', 'range': '<15'};
      case 'Lp(a)': return {'base': 15.0, 'unit': 'mg/dL', 'range': '<30'};
      case 'ApoB': return {'base': 85.0, 'unit': 'mg/dL', 'range': '<90'};
      case 'ApoA1': return {'base': 140.0, 'unit': 'mg/dL', 'range': '>120'};

      // Specialty Cardio
      case 'Omega-3 Index': return {'base': 6.5, 'unit': '%', 'range': '>8.0'};
      case 'EPA': return {'base': 2.5, 'unit': 'ug/mL', 'range': '1-10'};
      case 'DHA': return {'base': 4.5, 'unit': 'ug/mL', 'range': '2-15'};
      case 'DHEA-S': return {'base': 250.0, 'unit': 'ug/dL', 'range': '100-500'};
      case 'SHBG': return {'base': 35.0, 'unit': 'nmol/L', 'range': '15-70'};

      // Specialty Hormones
      case 'IGF-1': return {'base': 180.0, 'unit': 'ng/mL', 'range': '100-300'};
      case 'Prolactin': return {'base': 8.0, 'unit': 'ng/mL', 'range': '4-15'};
      case 'Progesterone': return {'base': 0.5, 'unit': 'ng/mL', 'range': '<1.0'};
      case 'Fibrinogen': return {'base': 300.0, 'unit': 'mg/dL', 'range': '200-400'};
      case 'D-Dimer': return {'base': 250.0, 'unit': 'ng/mL', 'range': '<500'};

      // Minerals & More
      case 'Uric Acid': return {'base': 5.5, 'unit': 'mg/dL', 'range': '3.5-7.2'};
      case 'Magnesium': return {'base': 2.1, 'unit': 'mg/dL', 'range': '1.7-2.3'};
      case 'Zinc': return {'base': 95.0, 'unit': 'ug/dL', 'range': '60-120'};
      case 'Copper': return {'base': 105.0, 'unit': 'ug/dL', 'range': '70-140'};
      case 'Selenium': return {'base': 120.0, 'unit': 'ug/L', 'range': '70-150'};

      // Nutritional Vitamins
      case 'Vitamin A': return {'base': 55.0, 'unit': 'ug/dL', 'range': '30-80'};
      case 'Vitamin E': return {'base': 12.0, 'unit': 'mg/L', 'range': '5-18'};
      case 'Vitamin K1': return {'base': 0.5, 'unit': 'ng/mL', 'range': '0.1-2.2'};
      case 'CoQ10': return {'base': 1.2, 'unit': 'ug/mL', 'range': '0.5-2.0'};
      case 'Cystatin C': return {'base': 0.85, 'unit': 'mg/L', 'range': '0.6-1.0'};

      // Renal & Liver Advanced
      case 'Microalbumin': return {'base': 12.0, 'unit': 'mg/L', 'range': '<30'};
      case 'GGT': return {'base': 22.0, 'unit': 'U/L', 'range': '<60'};
      case 'LDH': return {'base': 160.0, 'unit': 'U/L', 'range': '140-280'};
      case 'Haptoglobin': return {'base': 110.0, 'unit': 'mg/dL', 'range': '30-200'};
      case 'Transferrin': return {'base': 250.0, 'unit': 'mg/dL', 'range': '200-370'};

      // Iron/Blood/Novel
      case 'UIBC': return {'base': 240.0, 'unit': 'ug/dL', 'range': '150-375'};
      case 'Reticulocytes': return {'base': 1.2, 'unit': '%', 'range': '0.5-2.5'};
      case 'ESR': return {'base': 8.0, 'unit': 'mm/hr', 'range': '<15'};
      case 'GlycA': return {'base': 320.0, 'unit': 'µmol/L', 'range': '280-400'};
      case 'TMAO': return {'base': 4.2, 'unit': 'µmol/L', 'range': '<6.0'};

      // Advanced Cardiovascular
      case 'ADMA': return {'base': 0.55, 'unit': 'µmol/L', 'range': '0.40-0.75'};
      case 'SDMA': return {'base': 12.0, 'unit': 'ug/dL', 'range': '<14'};
      case 'Myoglobin': return {'base': 45.0, 'unit': 'ng/mL', 'range': '<85'};
      case 'Troponin I': return {'base': 0.01, 'unit': 'ng/mL', 'range': '<0.04'};
      case 'BNP': return {'base': 35.0, 'unit': 'pg/mL', 'range': '<100'};

      // Cardiac/Metabolic Specialty
      case 'NT-proBNP': return {'base': 75.0, 'unit': 'pg/mL', 'range': '<125'};
      case 'Lactate': return {'base': 1.1, 'unit': 'mmol/L', 'range': '0.5-2.2'};
      case 'Pyruvate': return {'base': 0.08, 'unit': 'mmol/L', 'range': '0.03-0.12'};
      case 'Acetoacetate': return {'base': 1.5, 'unit': 'mg/dL', 'range': '<3.0'};
      case 'Beta-Hydroxybutyrate': return {'base': 0.3, 'unit': 'mmol/L', 'range': '<0.4'};

      // Antioxidant Status
      case 'Glutathione': return {'base': 5.5, 'unit': 'µmol/L', 'range': '4-8'};
      case 'GSH-Px': return {'base': 35.0, 'unit': 'U/g Hb', 'range': '22-47'};
      case 'SOD': return {'base': 1100.0, 'unit': 'U/g Hb', 'range': '1000-1500'};
      case 'Catalase': return {'base': 25.0, 'unit': 'U/mg Hb', 'range': '15-35'};
      case '8-OHdG': return {'base': 12.0, 'unit': 'ng/mg Creat', 'range': '<15'};

      // Cytokines/Inflammation
      case 'Malondialdehyde': return {'base': 1.2, 'unit': 'µmol/L', 'range': '0.8-2.0'};
      case 'IL-6': return {'base': 1.5, 'unit': 'pg/mL', 'range': '<5.0'};
      case 'TNF-Alpha': return {'base': 1.2, 'unit': 'pg/mL', 'range': '<8.0'};
      case 'IL-10': return {'base': 2.5, 'unit': 'pg/mL', 'range': '<5.0'};
      case 'TGF-Beta': return {'base': 35.0, 'unit': 'ng/mL', 'range': '25-50'};

      // Advanced Metabolic
      case 'Oxidized LDL': return {'base': 45.0, 'unit': 'U/L', 'range': '<60'};
      case 'Adiponectin': return {'base': 12.0, 'unit': 'ug/mL', 'range': '5-25'};
      case 'Leptin': return {'base': 8.0, 'unit': 'ng/mL', 'range': '2-15'};
      case 'Ghrelin': return {'base': 650.0, 'unit': 'pg/mL', 'range': '400-1000'};
      case 'Visfatin': return {'base': 12.0, 'unit': 'ng/mL', 'range': '5-20'};
      case 'Resistin': return {'base': 10.0, 'unit': 'ng/mL', 'range': '5-20'};

      // Bone & Growth Markers
      case 'Osteocalcin': return {'base': 15.0, 'unit': 'ng/mL', 'range': '5-25'};
      case 'P1NP': return {'base': 45.0, 'unit': 'ng/mL', 'range': '20-75'};
      case 'Beta-CrossLaps': return {'base': 350.0, 'unit': 'pg/mL', 'range': '100-600'};

      // More Vitamins
      case 'Vitamin B1': return {'base': 45.0, 'unit': 'nmol/L', 'range': '25-75'};
      case 'Vitamin B2': return {'base': 12.0, 'unit': 'nmol/L', 'range': '5-25'};
      case 'Vitamin B3': return {'base': 45.0, 'unit': 'ng/mL', 'range': '20-80'};
      case 'Vitamin B5': return {'base': 450.0, 'unit': 'ng/mL', 'range': '200-800'};
      case 'Vitamin B6': return {'base': 15.0, 'unit': 'ng/mL', 'range': '5-30'};
      case 'Biotin': return {'base': 450.0, 'unit': 'pg/mL', 'range': '200-800'};

      // Trace Minerals
      case 'Manganese': return {'base': 1.2, 'unit': 'ug/L', 'range': '0.4-1.5'};
      case 'Chromium': return {'base': 0.25, 'unit': 'ug/L', 'range': '0.1-0.5'};
      case 'Molybdenum': return {'base': 1.2, 'unit': 'ug/L', 'range': '0.5-2.5'};
      
      default: return {'base': 10.0 + (name.length * 5.0) % 150, 'unit': 'mg/dL', 'range': '0-200'};
    }
  }

  List<LabMarker> _generateSampleMarkers(double variance) {
    final List<String> markerNames = [
      'Glucose', 'BUN', 'Creatinine', 'eGFR', 'Sodium', 'Potassium', 'Chloride', 'Calcium', 
      'Protein Total', 'Albumin', 'Globulin', 'Bilirubin Total', 'ALP', 'AST', 'ALT',
      'Cholesterol Total', 'Triglycerides', 'HDL', 'LDL', 'VLDL', 'WBC', 'RBC', 'Hemoglobin',
      'Hematocrit', 'MCV', 'MCH', 'MCHC', 'RDW', 'Platelets', 'Neutrophils', 'Lymphocytes',
      'Monocytes', 'Eosinophils', 'Basophils', 'Vitamin D', 'Vitamin B12', 'Folate', 'Iron',
      'TIBC', 'Ferritin', 'TSH', 'Free T3', 'Free T4', 'Testosterone', 'Estradiol', 'Cortisol',
      'Insulin', 'HbA1c', 'hs-CRP', 'Homocysteine', 'Lp(a)', 'ApoB', 'ApoA1', 'Omega-3 Index',
      'EPA', 'DHA', 'DHEA-S', 'SHBG', 'IGF-1', 'Prolactin', 'Progesterone', 'Fibrinogen',
      'D-Dimer', 'Uric Acid', 'Magnesium', 'Zinc', 'Copper', 'Selenium', 'Vitamin A',
      'Vitamin E', 'Vitamin K1', 'CoQ10', 'Cystatin C', 'Microalbumin', 'GGT', 'LDH',
      'Haptoglobin', 'Transferrin', 'UIBC', 'Reticulocytes', 'ESR', 'GlycA', 'TMAO',
      'ADMA', 'SDMA', 'Myoglobin', 'Troponin I', 'BNP', 'NT-proBNP', 'Lactate', 'Pyruvate',
      'Acetoacetate', 'Beta-Hydroxybutyrate', 'Glutathione', 'GSH-Px', 'SOD', 'Catalase',
      '8-OHdG', 'Malondialdehyde', 'IL-6', 'TNF-Alpha', 'IL-10', 'TGF-Beta', 'Oxidized LDL',
      'Adiponectin', 'Leptin', 'Ghrelin', 'Visfatin', 'Resistin', 'Osteocalcin', 'P1NP',
      'Beta-CrossLaps', 'Vitamin B1', 'Vitamin B2', 'Vitamin B3', 'Vitamin B5', 'Vitamin B6',
      'Biotin', 'Manganese', 'Chromium', 'Molybdenum'
    ];

    return List.generate(120, (index) {
      final name = index < markerNames.length ? markerNames[index] : "Marker ${index + 1}";
      
      // Determine status based on index and variance
      // We want exactly 80 Optimal, 27 Normal, and 13 Outliers (High/Low).
      String status;
      if (index < 80) {
        status = 'Optimal';
      } else if (index < 107) {
        status = 'Normal';
      } else {
        // Exactly 13 markers (107 to 119) are outliers
        status = (index % 2 == 0) ? 'High' : 'Low';
      }
         // Get clinical defaults for this marker
      final defaults = _getMarkerDefaults(name);
      final double baseValue = defaults['base'];
      final String unit = defaults['unit'];
      String range = defaults['range'];

      // Apply variance to the value to create trend data
      // Variance ranges from 0.0 to 2.5 across reports
      double value = baseValue + (variance * (index % 3 == 0 ? 1 : -1) * (baseValue * 0.03));
      
      // Override values for outliers to ensure they look correct
      if (status == 'High') {
        value = baseValue * 1.35 + (variance * 0.5);
      } else if (status == 'Low') {
        value = baseValue * 0.65 - (variance * 0.5);
      }
      // Determine category for sample data
      String category;
      if (index < 15) category = 'Metabolic';
      else if (index < 20) category = 'Cardiovascular';
      else if (index < 34) category = 'Blood Count';
      else if (index < 42) category = 'Vitamins';
      else if (index < 45) category = 'Thyroid';
      else if (index < 52) category = 'Hormones';
      else if (index < 60) category = 'Minerals';
      else if (index < 70) category = 'Liver';
      else if (index < 78) category = 'Kidney';
      else category = 'Advanced';

      final marker = LabMarker(
        name: name,
        value: value.toStringAsFixed(value < 10 ? 2 : 1),
        range: range,
        status: status,
        category: category,
        unit: unit,
      );

      return ClinicalIntelligence.calibrate(marker);
    });
  }

  List<LabReport> _getSampleReports() {
    switch (widget.reportType) {
      case 'Gut Microbiome':
        return [gutMicrobiomeReport];
      case 'Genetic':
        return [geneticPanelReport];
      case 'Biological Age':
        return [biologicalAgeReport];
      case 'Heavy Metals':
        return [heavyMetalsReport];
      case 'Toxicity':
        return [toxicityReport];
      default:
        return [
      LabReport(
        id: 'sample1',
        date: '2024-03-15',
        title: 'Quarterly Blood Panel',
        summary: 'Markers look great, slight improvement in Vitamin D.',
        markers: _generateSampleMarkers(0),
      ),
      LabReport(
        id: 'sample2',
        date: '2023-12-10',
        title: 'Baseline Blood Work',
        summary: 'Good baseline, Vitamin D needs focus.',
        markers: _generateSampleMarkers(1.5),
      ),
      LabReport(
        id: 'sample3',
        date: '2023-09-05',
        title: 'Routine Checkup',
        summary: 'All markers within standard range.',
        markers: _generateSampleMarkers(0.5),
      ),
      LabReport(
        id: 'sample4',
        date: '2023-06-20',
        title: 'Initial Screening',
        summary: 'Starting baseline numbers.',
        markers: _generateSampleMarkers(2.5),
      ),
    ];
    }
  }
  
  /// Dynamic categories derived from marker data — no hardcoded list.
  List<String> get _categories {
    // For real reports, derive from marker.category
    final reportsAsync = ref.read(labReportsProvider);
    final reports = reportsAsync.value;
    if (reports != null && reports.isNotEmpty) {
      final cats = reports
          .expand((r) => r.markers)
          .map((m) => m.category)
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();
      cats.sort();
      return ['All', ...cats];
    }
    // Fallback for sample data
    return [
      'All', 'Metabolic', 'Cardiovascular', 'Liver', 'Kidney', 
      'Hormones', 'Vitamins', 'Blood Count', 'Minerals'
    ];
  }

  

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider); // keep provider alive
    final reportsAsync = ref.watch(labReportsProvider);
    final analysisState = ref.watch(labAnalysisProvider);

    final reportsList = reportsAsync.value;
    final filteredReports = reportsList?.where((r) => 
      (r.reportType ?? 'Blood') == widget.reportType
    ).toList();
    
    // Only allow sample data if real reports for THIS type are empty
    final bool canShowSample = filteredReports != null && filteredReports.isEmpty;
    final bool showSampleDashboard = _showSampleData && canShowSample;
    final bool showSampleToggle = canShowSample;

    return Scaffold(
      backgroundColor: context.nc.isDark ? Colors.transparent : context.nc.scaffoldBg,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
        child: Container(
          color: context.nc.isDark ? Colors.transparent : context.nc.scaffoldBg,
        child: SafeArea(
          bottom: false,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                final double dy = notification.scrollDelta ?? 0.0;
                if (dy > 3.0) {
                  ref.read(navbarVisibleProvider.notifier).hide();
                } else if (dy < -3.0) {
                  ref.read(navbarVisibleProvider.notifier).show();
                }
              }
              return false;
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Page Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showPanelPickerBottomSheet(context),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      widget.reportType == 'Blood' ? 'Health Data' : widget.reportType,
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: context.nc.textPrimary,
                                        letterSpacing: -0.8,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: BrandColors.emerald500.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.chevronDown,
                                    size: 16,
                                    color: BrandColors.emerald500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.reportType == 'Blood' ? 'Tap to switch panel • Biomarkers' : 'Tap to switch panel • ${widget.reportType}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: BrandColors.emerald500,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/health_data/upload'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                              color: context.nc.isDark ? BrandColors.emerald500 : context.nc.textPrimary,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: (context.nc.isDark ? BrandColors.emerald500 : context.nc.textPrimary).withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.plusCircle, size: 15, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Upload',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Background Analysis Banner ──
              if (analysisState.status != LabAnalysisStatus.idle && analysisState.status != LabAnalysisStatus.error)
                _buildAnalysisBanner(analysisState),
              // ── Body ──
              Expanded(
                child: showSampleDashboard 
                  ? _buildDashboard(_cachedSampleReports ?? (_cachedSampleReports = _getSampleReports()))
                  : reportsAsync.when(
                      data: (reports) {
                        final filteredReports = reports.where((r) => 
                          (r.reportType ?? 'Blood') == widget.reportType
                        ).toList();
                        
                        if (filteredReports.isEmpty) {
                          return _buildEmptyState();
                        }
                        return _buildDashboard(filteredReports);
                      },
                      loading: () => Center(
                        child: Text(
                          'Analyzing Health Data...',
                          style: TextStyle(
                            color: context.nc.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      error: (e, s) => Center(child: Text('Error: $e')),
                    ),
              ),
              if (showSampleToggle)
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 14, top: 12, bottom: 30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.nc.cardSurfaceElevated,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: context.nc.cardBorder.withValues(alpha: 0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'VISUALIZE SAMPLE REPORT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Transform.scale(
                            scale: 0.75,
                            child: CupertinoSwitch(
                              value: _showSampleData,
                              activeColor: BrandColors.emerald500,
                              thumbColor: Colors.white,
                              trackColor: context.nc.isDark ? Colors.white10 : BrandColors.slate200,
                              onChanged: (val) {
                                setState(() {
                                  _showSampleData = val;
                                  // Pre-generate data if turning on to ensure zero lag
                                  if (val && _cachedSampleReports == null) {
                                    _cachedSampleReports = _getSampleReports();
                                  }
                                  if (!val) {
                                    _selectedReportId = null; // Reset selection
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    ),
    );
  }

  Widget _buildAnalysisBanner(LabAnalysisState state) {
    final isDone = state.status == LabAnalysisStatus.completed;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isDone ? Color(0xFF10B981) : (context.nc.isDark ? context.nc.cardSurfaceElevated : BrandColors.dark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isDone ? Color(0xFF10B981) : BrandColors.dark)
                .withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isDone && state.result != null) {
              final profile = ref.read(patientProfileProvider).value;
              if (profile == null) return;

              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => LabReportVerificationScreen(
                    filePath: state.pendingFilePath ?? state.result!['title'] ?? '',
                    fileName: state.pendingFileName ?? state.result!['title'] ?? '',
                    profileId: profile.id,
                    extractedData: state.result!,
                  ),
                ),
              );
            } else {
              context.push('/health_data/upload');
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (!isDone)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      strokeCap: StrokeCap.round,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(LucideIcons.checkCircle2,
                      size: 20, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDone ? 'Analysis Complete' : 'AI Analysis in Progress',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        isDone
                            ? 'Your report is ready to verify'
                            : state.statusMessage,
                        style: TextStyle(
                          color: isDone
                              ? Colors.white.withValues(alpha: 0.8)
                              : Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!isDone)
                  Text(
                    '${(state.progress * 100).round()}%',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  )
                else
                  Text(
                    'VIEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                const SizedBox(width: 8),
                if (isDone)
                  GestureDetector(
                    onTap: () {
                       HapticFeedback.lightImpact();
                       ref.read(labAnalysisProvider.notifier).dismiss();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.x, size: 14, color: Colors.white),
                    ),
                  )
                else
                  Icon(LucideIcons.chevronRight,
                      size: 16, color: Colors.white60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No Health Data Yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.nc.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Upload your latest ${widget.reportType == 'Blood' ? 'blood work' : '${widget.reportType.toLowerCase()} results'} to unlock comprehensive biomarker analysis and personalized longevity insights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: context.nc.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.5,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                setState(() {
                  _showSampleData = true;
                  if (_cachedSampleReports == null) {
                    _cachedSampleReports = _getSampleReports();
                  }
                  _selectedReportId = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: context.nc.isDark ? BrandColors.emerald500.withValues(alpha: 0.15) : BrandColors.emerald500.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: BrandColors.emerald500.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.flaskConical, size: 16, color: BrandColors.emerald500),
                    const SizedBox(width: 8),
                    Text(
                      'Show sample values',
                      style: TextStyle(
                        color: BrandColors.emerald500,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(List<LabReport> originalReports) {
    // 0. Ensure reports are sorted by date descending (newest first)
    final reports = List<LabReport>.from(originalReports);
    reports.sort((a, b) => b.date.compareTo(a.date));

    // 1. Resolve Active Report (used for the header date context)
    final activeReport = reports.firstWhere(
        (r) => r.id == _selectedReportId,
        orElse: () => reports.first
    );
    
    // Update ID if it was null
    if (_selectedReportId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedReportId = activeReport.id);
      });
    }

    // 2. Aggregate Markers Across All Reports Context
    // We iterate through all reports (newest to oldest) and keep the most recent value for each unique biomarker. 
    // This prevents older markers from vanishing if a new report only contains a few markers.
    final Map<String, LabMarker> aggregatedMarkersMap = {};
    for (final report in reports) {
      for (final marker in report.markers) {
        // Use Canonical Name to group markers with slight naming variations
        final canonicalName = ClinicalIntelligence.getCanonicalName(marker.name);
        final key = canonicalName.toLowerCase();
        
        // Add only if we haven't seen a more recent value for this canonical group
        if (!aggregatedMarkersMap.containsKey(key)) {
          aggregatedMarkersMap[key] = marker;
        }
      }
    }
    final List<LabMarker> allAggregatedMarkers = aggregatedMarkersMap.values.toList();

    // 3. Filter Logic
    final markers = allAggregatedMarkers.where((m) {
      final query = _searchQuery.toLowerCase();
      final matchesSearch = m.name.toLowerCase().contains(query);
      if (_selectedCategory == 'All') return matchesSearch;
      final matchesCat = _matchCategory(m, _selectedCategory);
      return matchesSearch && matchesCat;
    }).toList();

    // Pre-calculate canonical names and report counts for optimization to prevent UI hangs
    final Map<String, int> canonicalReportCounts = {};
    for (final report in reports) {
      final uniqueCanonicalNamesInReport = report.markers
          .map((m) => ClinicalIntelligence.getCanonicalName(m.name))
          .toSet();
      for (final canonicalName in uniqueCanonicalNamesInReport) {
        canonicalReportCounts[canonicalName] = (canonicalReportCounts[canonicalName] ?? 0) + 1;
      }
    }

    // 4. Sort — Prioritize markers with more historical data points, then group by category
    markers.sort((a, b) {
      final aCanonical = ClinicalIntelligence.getCanonicalName(a.name);
      final bCanonical = ClinicalIntelligence.getCanonicalName(b.name);
      
      final aCount = canonicalReportCounts[aCanonical] ?? 0;
      final bCount = canonicalReportCounts[bCanonical] ?? 0;

      // Primary sort: Report count descending
      if (aCount != bCount) return bCount.compareTo(aCount);

      // Secondary sort: Category
      final catCompare = a.category.compareTo(b.category);
      if (catCompare != 0) return catCompare;

      // Tertiary sort: Alphabetical name
      return a.name.compareTo(b.name);
    });

    // 5. Pre-calculate History Maps to avoid O(N^2) work inside the itemBuilder
    final Map<String, List<Map<String, String>>> markersHistoryMap = {};
    for (final m in markers) {
      final canonicalName = ClinicalIntelligence.getCanonicalName(m.name);
      final history = <Map<String, String>>[];
      for (final r in reports) {
        final matchingMarker = r.markers.firstWhere(
          (rm) => ClinicalIntelligence.getCanonicalName(rm.name) == canonicalName,
          orElse: () => LabMarker(name: '', value: '', range: '', status: '', category: '', unit: ''),
        );
        if (matchingMarker.name.isNotEmpty) {
          history.add({
            'date': r.date, 
            'value': matchingMarker.value,
            'originalValue': matchingMarker.value,
            'range': matchingMarker.range,
            'unit': matchingMarker.unit,
            'labName': matchingMarker.labName ?? r.labName ?? '',
          });
        }
      }
      history.sort((a, b) => (a['date']!).compareTo(b['date']!));
      markersHistoryMap[canonicalName] = history;
    }

    // Counts based on aggregated data
    final optimal = allAggregatedMarkers.where((m) => m.isOptimal).length;
    final normal = allAggregatedMarkers.where((m) => m.isInRange).length;
    final outliers = allAggregatedMarkers.where((m) => m.isOutlier).length;
    final total = allAggregatedMarkers.length;
    final isHealthy = optimal > total / 2;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeaderSummaryCard(),
          if (widget.reportType != 'Blood') const SizedBox(height: 16),
          // ── Hero: Biomarker Health Card ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: DashboardCardStyle.decorationOf(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isHealthy ? 'Optimal' : 'Needs Focus',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: context.nc.textPrimary,
                        letterSpacing: -1.0,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showReportSelector(context, reports),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.nc.textPrimary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'All Reports',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.nc.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 14,
                              color: context.nc.textPrimary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  "Your biomarker profile is ${isHealthy ? 'optimal' : 'improving'}. $optimal out of $total markers are in the ideal range.",
                  style: TextStyle(
                    fontSize: 15,
                    color: context.nc.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Stat Pills
                Row(
                  children: [
                    StatPill(
                      label: 'OPTIMAL',
                      count: optimal,
                      color: const Color(0xFF10B981),
                      bg: const Color(0xFF10B981).withValues(alpha: 0.1),
                    ),
                    const SizedBox(width: 12),
                    StatPill(
                      label: 'NORMAL',
                      count: normal,
                      color: const Color(0xFFF59E0B),
                      bg: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    ),
                    const SizedBox(width: 12),
                    StatPill(
                      label: 'OUTLIERS',
                      count: outliers,
                      color: const Color(0xFFEF4444),
                      bg: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Segmented Health Bar (Battery-like)
                _buildSegmentedHealthBar(optimal, normal, outliers, total),
                
                const SizedBox(height: 24),
                Container(height: 1, color: context.nc.divider),
                const SizedBox(height: 16),

                // Summary text
                Text(
                  "Latest report analyzed on ${activeReport.date}. Your aggregated biomarker profile looks ${isHealthy ? 'strong' : 'fair'}. Keep fasts during the window for better metabolic flexibility.",
                  style: TextStyle(
                    fontSize: 14,
                    color: context.nc.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Search Bar ──
          Container(
            decoration: DashboardCardStyle.decorationOf(context).copyWith(
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: context.nc.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: "Search biomarkers...",
                hintStyle: TextStyle(color: context.nc.textTertiary, fontSize: 15),
                prefixIcon: Icon(LucideIcons.search, size: 20, color: context.nc.textTertiary),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Category Pills ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (context.nc.isDark ? Colors.white : const Color(0xFF0F172A)) 
                            : (context.nc.isDark ? context.nc.cardSurface : Colors.white),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : context.nc.cardBorder.withValues(alpha: 0.3),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (context.nc.isDark ? Colors.white : context.nc.textPrimary).withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected 
                              ? (context.nc.isDark ? const Color(0xFF0F172A) : Colors.white) 
                              : context.nc.textSecondary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // ── Biomarker List ──
          if (markers.isEmpty)
             _buildEmptySearchState()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: markers.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final marker = markers[index];
                final canonicalMarkerName = ClinicalIntelligence.getCanonicalName(marker.name);
                final rawHistory = markersHistoryMap[canonicalMarkerName] ?? [];

                // ── Unit Normalization ──────────────────────────────────
                // Detect if all data points share the same unit. If not,
                // attempt to normalize to the canonical unit for cleaner
                // trend charts.
                final units = rawHistory.map((p) => (p['unit'] ?? '').toLowerCase().trim()).toSet();
                final needsNormalization = units.length > 1;

                final history = needsNormalization
                    ? rawHistory.map((point) {
                        final rawValue = double.tryParse(
                          (point['value'] ?? '').toString().replaceAll(RegExp(r'[^0-9.]'), '')
                        ) ?? 0.0;
                        final fromUnit = point['unit'] ?? '';
                        final result = UnitConverter.normalize(
                          value: rawValue,
                          fromUnit: fromUnit,
                          biomarkerCanonicalName: canonicalMarkerName,
                        );
                        return {
                          'date': point['date']!,
                          'value': result.wasConverted
                              ? result.normalizedValue.toStringAsFixed(2)
                              : point['value']!,
                          'originalValue': point['value']!,
                          'range': point['range'] ?? '',
                          'unit': result.canonicalUnit,
                          'labName': point['labName'] ?? '',
                          'wasConverted': result.wasConverted ? 'true' : 'false',
                        };
                      }).toList()
                    : rawHistory;
                // ───────────────────────────────────────────────────────

                return BiomarkerCard(
                  marker: marker,
                  isImmersive: false,
                  history: history,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow({required Color color, required String label, required int count, required int total}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.nc.textPrimary,
          ),
        ),
        Text(
          "$count/$total",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.nc.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentedHealthBar(int optimal, int normal, int outliers, int total) {
    if (total == 0) return const SizedBox.shrink();
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMiniLegend('Optimal', Color(0xFF10B981), (optimal/total * 100).round()),
            _buildMiniLegend('In-Range', Color(0xFFF59E0B), (normal/total * 100).round()),
            _buildMiniLegend('Outliers', Color(0xFFEF4444), (outliers/total * 100).round()),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.nc.isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                if (optimal > 0)
                  Expanded(
                    flex: optimal,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        border: Border(right: BorderSide(color: context.nc.isDark ? Colors.black : Colors.white, width: 2)),
                      ),
                    ),
                  ),
                if (normal > 0)
                  Expanded(
                    flex: normal,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B),
                        border: Border(right: BorderSide(color: context.nc.isDark ? Colors.black : Colors.white, width: 2)),
                      ),
                    ),
                  ),
                if (outliers > 0)
                  Expanded(
                    flex: outliers,
                    child: Container(
                      color: Color(0xFFEF4444),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniLegend(String label, Color color, int percentage) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          "$percentage%",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: context.nc.textTertiary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  bool _matchCategory(LabMarker m, String category) {
    return m.category == category;
  }
  void _showReportSelector(BuildContext context, List<LabReport> reports) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true, 
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // Solid premium dark background
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text(
                    'Lab Reports',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.x, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                itemCount: reports.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final isSelected = _selectedReportId == report.id;
                  
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedReportId = report.id);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              LucideIcons.microscope, 
                              size: 18, 
                              color: Colors.white
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${report.labName ?? 'General Lab'} • ${report.date}",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: const Text('Delete Report?', style: TextStyle(color: Colors.white)),
                                  content: const Text('This will permanently remove this lab report and its biomarker data.', style: TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('CANCEL', style: TextStyle(color: Colors.white60)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                if (report.id.startsWith('sample')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Sample data cannot be deleted.')),
                                  );
                                  return;
                                }

                                final profile = ref.read(patientProfileProvider).value;
                                if (profile == null) return;
                                
                                final success = await HealthDataRepository.deleteLabReport(
                                  report.id, 
                                  profile.id, 
                                  report.pdfUrl 
                                );
                                
                                if (success) {
                                  ref.invalidate(labReportsProvider);
                                  if (mounted) Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Report deleted successfully.')),
                                  );
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(LucideIcons.trash2, size: 18, color: Colors.white.withValues(alpha: 0.3)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPanelPickerBottomSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    final panels = [
      {'type': 'Blood', 'name': 'Standard Blood Panel', 'desc': 'Comprehensive metabolic, lipid & hormone markers', 'icon': LucideIcons.testTube2, 'route': '/health_data'},
      {'type': 'Gut Microbiome', 'name': 'Gut Microbiome', 'desc': 'Phylum ratios, diversity indices & pathogens', 'icon': LucideIcons.dna, 'route': '/health_data/gut-microbiome'},
      {'type': 'Genetic', 'name': 'Genetic & Methylation', 'desc': 'One-time SNP variant analysis', 'icon': LucideIcons.fileCode, 'route': '/health_data/genetic'},
      {'type': 'Biological Age', 'name': 'Biological Age', 'desc': 'Epigenetic clocks & pace of aging', 'icon': LucideIcons.clock, 'route': '/health_data/biological-age'},
      {'type': 'Heavy Metals', 'name': 'Heavy Metals', 'desc': 'Provoked urine toxicity thresholds', 'icon': LucideIcons.flaskConical, 'route': '/health_data/heavy-metals'},
      {'type': 'Toxicity', 'name': 'Environmental Toxins', 'desc': 'Mycotoxins, pesticides & plasticizers', 'icon': LucideIcons.shieldAlert, 'route': '/health_data/toxicity'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.nc.isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.nc.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Switch Diagnostic Panel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: context.nc.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Select a diagnostic report category to view',
              style: TextStyle(
                fontSize: 13,
                color: context.nc.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ...panels.map((p) {
              final isSelected = widget.reportType == p['type'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    if (!isSelected) {
                      context.go(p['route'] as String);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? BrandColors.emerald500.withValues(alpha: 0.12)
                          : (context.nc.isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected 
                            ? BrandColors.emerald500.withValues(alpha: 0.4)
                            : (context.nc.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected ? BrandColors.emerald500.withValues(alpha: 0.2) : (context.nc.isDark ? Colors.white10 : Colors.black54),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            p['icon'] as IconData,
                            size: 18,
                            color: isSelected ? BrandColors.emerald500 : context.nc.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name'] as String,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? BrandColors.emerald500 : context.nc.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p['desc'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.nc.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(LucideIcons.checkCircle2, size: 20, color: BrandColors.emerald500),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelHeaderSummaryCard() {
    switch (widget.reportType) {
      case 'Gut Microbiome':
        return _buildGutMicrobiomeHeaderCard();
      case 'Biological Age':
        return _buildBiologicalAgeHeaderCard();
      case 'Genetic':
        return _buildGeneticHeaderCard();
      case 'Heavy Metals':
        return _buildHeavyMetalsHeaderCard();
      case 'Toxicity':
        return _buildToxicityHeaderCard();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGutMicrobiomeHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(LucideIcons.dna, size: 20, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Microbiome Diversity',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.nc.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Shannon: 3.8 / 5.0',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Phylum Composition Breakdown',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.nc.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(flex: 58, child: Container(color: const Color(0xFF10B981))),
                  Expanded(flex: 32, child: Container(color: const Color(0xFF06B6D4))),
                  Expanded(flex: 6, child: Container(color: const Color(0xFFF59E0B))),
                  Expanded(flex: 4, child: Container(color: const Color(0xFFEF4444))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _buildPhylumDot('Bacteroidetes 58%', const Color(0xFF10B981)),
              _buildPhylumDot('Firmicutes 32%', const Color(0xFF06B6D4)),
              _buildPhylumDot('Actinobacteria 6%', const Color(0xFFF59E0B)),
              _buildPhylumDot('Proteobacteria 4%', const Color(0xFFEF4444)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhylumDot(String label, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.nc.textSecondary),
        ),
      ],
    );
  }

  Widget _buildBiologicalAgeHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BIOLOGICAL AGE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: context.nc.textTertiary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '31.2',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF06B6D4),
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'years',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.nc.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Column(
                  children: [
                    Text(
                      '-2.8 Years',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    Text(
                      'Younger than Chrono (34)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'DunedinPACE (Pace of Aging)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.nc.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '0.85x (Top 20% Cohort)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF06B6D4)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 8,
              width: double.infinity,
              color: context.nc.isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.35,
                child: Container(color: const Color(0xFF06B6D4)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneticHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: DashboardCardStyle.decorationOf(context).copyWith(
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.dna, size: 18, color: Color(0xFF6366F1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One-Time Genomic Upload',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.nc.textPrimary,
                      ),
                    ),
                    Text(
                      'DNA sequence never changes over time',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.nc.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildGeneticStatBox('Optimal', '14', const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildGeneticStatBox('Normal', '6', const Color(0xFF3B82F6))),
              const SizedBox(width: 8),
              Expanded(child: _buildGeneticStatBox('Risk Variants', '3', const Color(0xFFEF4444))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneticStatBox(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildHeavyMetalsHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: DashboardCardStyle.decorationOf(context).copyWith(
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.flaskConical, size: 20, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provoked Urine Specimen',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.nc.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Provocation Agent: DMSA 500mg • 1 Metal Elevated (Lead)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.nc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToxicityHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: DashboardCardStyle.decorationOf(context).copyWith(
        border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(LucideIcons.shieldAlert, size: 20, color: Color(0xFFF43F5E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Toxin Load Index',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.nc.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '62 / 100',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFF43F5E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Moderate Exposure • 2 Mycotoxins & 1 Plasticizer Detected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.nc.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Center(
        child: Column(
          children: [
            const Icon(LucideIcons.searchX, size: 32, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              "No matching biomarkers",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.nc.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
