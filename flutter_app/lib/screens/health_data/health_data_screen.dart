import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/lab_range_wording.dart';
import '../../config/theme.dart';
import '../../providers/lab_analysis_provider.dart';
import '../../providers/lab_reports_provider.dart';
import '../../providers/patient_provider.dart';
import './lab_report_submitted_screen.dart';
import './report_detail_screen.dart';
import '../../models/lab_report.dart';
import '../../providers/navbar_provider.dart';
import './widgets/health_widgets.dart'; // Shared Widgets
import '../../providers/theme_provider.dart';
import '../../utils/clinical_intelligence.dart';
import '../../utils/unit_converter.dart';
import '../../data/health_data_repository.dart';
import '../../widgets/tc025/tc025_widgets.dart';

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
      case 'Glucose':
        return {'base': 90.0, 'unit': 'mg/dL', 'range': '70-99'};
      case 'BUN':
        return {'base': 14.0, 'unit': 'mg/dL', 'range': '7-20'};
      case 'Creatinine':
        return {'base': 1.0, 'unit': 'mg/dL', 'range': '0.7-1.3'};
      case 'eGFR':
        return {'base': 95.0, 'unit': 'mL/min/1.73m²', 'range': '>90'};
      case 'Sodium':
        return {'base': 140.0, 'unit': 'mEq/L', 'range': '136-145'};
      case 'Potassium':
        return {'base': 4.2, 'unit': 'mEq/L', 'range': '3.5-5.1'};
      case 'Chloride':
        return {'base': 102.0, 'unit': 'mEq/L', 'range': '98-107'};
      case 'Calcium':
        return {'base': 9.4, 'unit': 'mg/dL', 'range': '8.6-10.2'};
      case 'Protein Total':
        return {'base': 7.1, 'unit': 'g/dL', 'range': '6.0-8.3'};
      case 'Albumin':
        return {'base': 4.4, 'unit': 'g/dL', 'range': '3.5-5.0'};
      case 'Globulin':
        return {'base': 2.7, 'unit': 'g/dL', 'range': '2.0-3.5'};
      case 'Bilirubin Total':
        return {'base': 0.6, 'unit': 'mg/dL', 'range': '0.1-1.2'};
      case 'ALP':
        return {'base': 65.0, 'unit': 'U/L', 'range': '44-147'};
      case 'AST':
        return {'base': 22.0, 'unit': 'U/L', 'range': '10-40'};
      case 'ALT':
        return {'base': 25.0, 'unit': 'U/L', 'range': '7-55'};

      // Lipid Panel
      case 'Cholesterol Total':
        return {'base': 180.0, 'unit': 'mg/dL', 'range': '<200'};
      case 'Triglycerides':
        return {'base': 110.0, 'unit': 'mg/dL', 'range': '<150'};
      case 'HDL':
        return {'base': 55.0, 'unit': 'mg/dL', 'range': '>40'};
      case 'LDL':
        return {'base': 95.0, 'unit': 'mg/dL', 'range': '<100'};
      case 'VLDL':
        return {'base': 22.0, 'unit': 'mg/dL', 'range': '2-30'};

      // CBC
      case 'WBC':
        return {'base': 6.4, 'unit': 'x10E3/uL', 'range': '3.4-10.8'};
      case 'RBC':
        return {'base': 4.8, 'unit': 'x10E6/uL', 'range': '4.1-5.8'};
      case 'Hemoglobin':
        return {'base': 14.2, 'unit': 'g/dL', 'range': '13.0-17.0'};
      case 'Hematocrit':
        return {'base': 42.0, 'unit': '%', 'range': '37-49'};
      case 'MCV':
        return {'base': 88.0, 'unit': 'fL', 'range': '80-100'};
      case 'MCH':
        return {'base': 29.0, 'unit': 'pg', 'range': '27-33'};
      case 'MCHC':
        return {'base': 34.0, 'unit': 'g/dL', 'range': '32-36'};
      case 'RDW':
        return {'base': 12.5, 'unit': '%', 'range': '11.0-15.0'};
      case 'Platelets':
        return {'base': 240.0, 'unit': 'x10E3/uL', 'range': '150-450'};

      // Diff
      case 'Neutrophils':
        return {'base': 55.0, 'unit': '%', 'range': '40-70'};
      case 'Lymphocytes':
        return {'base': 32.0, 'unit': '%', 'range': '20-44'};
      case 'Monocytes':
        return {'base': 8.0, 'unit': '%', 'range': '2-10'};
      case 'Eosinophils':
        return {'base': 3.0, 'unit': '%', 'range': '0-5'};
      case 'Basophils':
        return {'base': 0.5, 'unit': '%', 'range': '0-2'};

      // Vitamins & Minerals
      case 'Vitamin D':
        return {'base': 45.0, 'unit': 'ng/mL', 'range': '30-100'};
      case 'Vitamin B12':
        return {'base': 600.0, 'unit': 'pg/mL', 'range': '200-1100'};
      case 'Folate':
        return {'base': 14.0, 'unit': 'ng/mL', 'range': '>5.4'};
      case 'Iron':
        return {'base': 95.0, 'unit': 'ug/dL', 'range': '40-190'};
      case 'TIBC':
        return {'base': 320.0, 'unit': 'ug/dL', 'range': '250-450'};
      case 'Ferritin':
        return {'base': 120.0, 'unit': 'ng/mL', 'range': '30-400'};
      case 'Transferrin':
        return {'base': 250.0, 'unit': 'mg/dL', 'range': '200-370'};

      // Thyroid
      case 'TSH':
        return {'base': 2.1, 'unit': 'mIU/L', 'range': '0.4-4.1'};
      case 'Free T3':
        return {'base': 3.2, 'unit': 'pg/mL', 'range': '2.3-4.2'};
      case 'Free T4':
        return {'base': 1.2, 'unit': 'ng/dL', 'range': '0.8-1.8'};

      // Hormones & Metabolic
      case 'Testosterone':
        return {'base': 650.0, 'unit': 'ng/dL', 'range': '250-1100'};
      case 'Estradiol':
        return {'base': 25.0, 'unit': 'pg/mL', 'range': '10-40'};
      case 'Cortisol':
        return {'base': 12.0, 'unit': 'ug/dL', 'range': '5-23'};
      case 'Insulin':
        return {'base': 8.0, 'unit': 'uIU/mL', 'range': '2-20'};
      case 'HbA1c':
        return {'base': 5.2, 'unit': '%', 'range': '<5.7'};

      // Inflammatory/Advanced Cardio
      case 'hs-CRP':
        return {'base': 0.8, 'unit': 'mg/L', 'range': '<1.0'};
      case 'Homocysteine':
        return {'base': 8.5, 'unit': 'umol/L', 'range': '<15'};
      case 'Lp(a)':
        return {'base': 15.0, 'unit': 'mg/dL', 'range': '<30'};
      case 'ApoB':
        return {'base': 85.0, 'unit': 'mg/dL', 'range': '<90'};
      case 'ApoA1':
        return {'base': 140.0, 'unit': 'mg/dL', 'range': '>120'};

      // Specialty Cardio
      case 'Omega-3 Index':
        return {'base': 6.5, 'unit': '%', 'range': '>8.0'};
      case 'EPA':
        return {'base': 2.5, 'unit': 'ug/mL', 'range': '1-10'};
      case 'DHA':
        return {'base': 4.5, 'unit': 'ug/mL', 'range': '2-15'};
      case 'DHEA-S':
        return {'base': 250.0, 'unit': 'ug/dL', 'range': '100-500'};
      case 'SHBG':
        return {'base': 35.0, 'unit': 'nmol/L', 'range': '15-70'};

      // Specialty Hormones
      case 'IGF-1':
        return {'base': 180.0, 'unit': 'ng/mL', 'range': '100-300'};
      case 'Prolactin':
        return {'base': 8.0, 'unit': 'ng/mL', 'range': '4-15'};
      case 'Progesterone':
        return {'base': 0.5, 'unit': 'ng/mL', 'range': '<1.0'};
      case 'Fibrinogen':
        return {'base': 300.0, 'unit': 'mg/dL', 'range': '200-400'};
      case 'D-Dimer':
        return {'base': 250.0, 'unit': 'ng/mL', 'range': '<500'};

      // Minerals & More
      case 'Uric Acid':
        return {'base': 5.5, 'unit': 'mg/dL', 'range': '3.5-7.2'};
      case 'Magnesium':
        return {'base': 2.1, 'unit': 'mg/dL', 'range': '1.7-2.3'};
      case 'Zinc':
        return {'base': 95.0, 'unit': 'ug/dL', 'range': '60-120'};
      case 'Copper':
        return {'base': 105.0, 'unit': 'ug/dL', 'range': '70-140'};
      case 'Selenium':
        return {'base': 120.0, 'unit': 'ug/L', 'range': '70-150'};

      // Nutritional Vitamins
      case 'Vitamin A':
        return {'base': 55.0, 'unit': 'ug/dL', 'range': '30-80'};
      case 'Vitamin E':
        return {'base': 12.0, 'unit': 'mg/L', 'range': '5-18'};
      case 'Vitamin K1':
        return {'base': 0.5, 'unit': 'ng/mL', 'range': '0.1-2.2'};
      case 'CoQ10':
        return {'base': 1.2, 'unit': 'ug/mL', 'range': '0.5-2.0'};
      case 'Cystatin C':
        return {'base': 0.85, 'unit': 'mg/L', 'range': '0.6-1.0'};

      // Renal & Liver Advanced
      case 'Microalbumin':
        return {'base': 12.0, 'unit': 'mg/L', 'range': '<30'};
      case 'GGT':
        return {'base': 22.0, 'unit': 'U/L', 'range': '<60'};
      case 'LDH':
        return {'base': 160.0, 'unit': 'U/L', 'range': '140-280'};
      case 'Haptoglobin':
        return {'base': 110.0, 'unit': 'mg/dL', 'range': '30-200'};

      // Iron/Blood/Novel
      case 'UIBC':
        return {'base': 240.0, 'unit': 'ug/dL', 'range': '150-375'};
      case 'Reticulocytes':
        return {'base': 1.2, 'unit': '%', 'range': '0.5-2.5'};
      case 'ESR':
        return {'base': 8.0, 'unit': 'mm/hr', 'range': '<15'};
      case 'GlycA':
        return {'base': 320.0, 'unit': 'µmol/L', 'range': '280-400'};
      case 'TMAO':
        return {'base': 4.2, 'unit': 'µmol/L', 'range': '<6.0'};

      // Advanced Cardiovascular
      case 'ADMA':
        return {'base': 0.55, 'unit': 'µmol/L', 'range': '0.40-0.75'};
      case 'SDMA':
        return {'base': 12.0, 'unit': 'ug/dL', 'range': '<14'};
      case 'Myoglobin':
        return {'base': 45.0, 'unit': 'ng/mL', 'range': '<85'};
      case 'Troponin I':
        return {'base': 0.01, 'unit': 'ng/mL', 'range': '<0.04'};
      case 'BNP':
        return {'base': 35.0, 'unit': 'pg/mL', 'range': '<100'};

      // Cardiac/Metabolic Specialty
      case 'NT-proBNP':
        return {'base': 75.0, 'unit': 'pg/mL', 'range': '<125'};
      case 'Lactate':
        return {'base': 1.1, 'unit': 'mmol/L', 'range': '0.5-2.2'};
      case 'Pyruvate':
        return {'base': 0.08, 'unit': 'mmol/L', 'range': '0.03-0.12'};
      case 'Acetoacetate':
        return {'base': 1.5, 'unit': 'mg/dL', 'range': '<3.0'};
      case 'Beta-Hydroxybutyrate':
        return {'base': 0.3, 'unit': 'mmol/L', 'range': '<0.4'};

      // Antioxidant Status
      case 'Glutathione':
        return {'base': 5.5, 'unit': 'µmol/L', 'range': '4-8'};
      case 'GSH-Px':
        return {'base': 35.0, 'unit': 'U/g Hb', 'range': '22-47'};
      case 'SOD':
        return {'base': 1100.0, 'unit': 'U/g Hb', 'range': '1000-1500'};
      case 'Catalase':
        return {'base': 25.0, 'unit': 'U/mg Hb', 'range': '15-35'};
      case '8-OHdG':
        return {'base': 12.0, 'unit': 'ng/mg Creat', 'range': '<15'};

      // Cytokines/Inflammation
      case 'Malondialdehyde':
        return {'base': 1.2, 'unit': 'µmol/L', 'range': '0.8-2.0'};
      case 'IL-6':
        return {'base': 1.5, 'unit': 'pg/mL', 'range': '<5.0'};
      case 'TNF-Alpha':
        return {'base': 1.2, 'unit': 'pg/mL', 'range': '<8.0'};
      case 'IL-10':
        return {'base': 2.5, 'unit': 'pg/mL', 'range': '<5.0'};
      case 'TGF-Beta':
        return {'base': 35.0, 'unit': 'ng/mL', 'range': '25-50'};

      // Advanced Metabolic
      case 'Oxidized LDL':
        return {'base': 45.0, 'unit': 'U/L', 'range': '<60'};
      case 'Adiponectin':
        return {'base': 12.0, 'unit': 'ug/mL', 'range': '5-25'};
      case 'Leptin':
        return {'base': 8.0, 'unit': 'ng/mL', 'range': '2-15'};
      case 'Ghrelin':
        return {'base': 650.0, 'unit': 'pg/mL', 'range': '400-1000'};
      case 'Visfatin':
        return {'base': 12.0, 'unit': 'ng/mL', 'range': '5-20'};
      case 'Resistin':
        return {'base': 10.0, 'unit': 'ng/mL', 'range': '5-20'};

      // Bone & Growth Markers
      case 'Osteocalcin':
        return {'base': 15.0, 'unit': 'ng/mL', 'range': '5-25'};
      case 'P1NP':
        return {'base': 45.0, 'unit': 'ng/mL', 'range': '20-75'};
      case 'Beta-CrossLaps':
        return {'base': 350.0, 'unit': 'pg/mL', 'range': '100-600'};

      // More Vitamins
      case 'Vitamin B1':
        return {'base': 45.0, 'unit': 'nmol/L', 'range': '25-75'};
      case 'Vitamin B2':
        return {'base': 12.0, 'unit': 'nmol/L', 'range': '5-25'};
      case 'Vitamin B3':
        return {'base': 45.0, 'unit': 'ng/mL', 'range': '20-80'};
      case 'Vitamin B5':
        return {'base': 450.0, 'unit': 'ng/mL', 'range': '200-800'};
      case 'Vitamin B6':
        return {'base': 15.0, 'unit': 'ng/mL', 'range': '5-30'};
      case 'Biotin':
        return {'base': 450.0, 'unit': 'pg/mL', 'range': '200-800'};

      // Trace Minerals
      case 'Manganese':
        return {'base': 1.2, 'unit': 'ug/L', 'range': '0.4-1.5'};
      case 'Chromium':
        return {'base': 0.25, 'unit': 'ug/L', 'range': '0.1-0.5'};
      case 'Molybdenum':
        return {'base': 1.2, 'unit': 'ug/L', 'range': '0.5-2.5'};

      default:
        return {
          'base': 10.0 + (name.length * 5.0) % 150,
          'unit': 'mg/dL',
          'range': '0-200'
        };
    }
  }

  List<LabMarker> _generateSampleMarkers(double variance) {
    final List<String> markerNames = [
      'Glucose',
      'BUN',
      'Creatinine',
      'eGFR',
      'Sodium',
      'Potassium',
      'Chloride',
      'Calcium',
      'Protein Total',
      'Albumin',
      'Globulin',
      'Bilirubin Total',
      'ALP',
      'AST',
      'ALT',
      'Cholesterol Total',
      'Triglycerides',
      'HDL',
      'LDL',
      'VLDL',
      'WBC',
      'RBC',
      'Hemoglobin',
      'Hematocrit',
      'MCV',
      'MCH',
      'MCHC',
      'RDW',
      'Platelets',
      'Neutrophils',
      'Lymphocytes',
      'Monocytes',
      'Eosinophils',
      'Basophils',
      'Vitamin D',
      'Vitamin B12',
      'Folate',
      'Iron',
      'TIBC',
      'Ferritin',
      'TSH',
      'Free T3',
      'Free T4',
      'Testosterone',
      'Estradiol',
      'Cortisol',
      'Insulin',
      'HbA1c',
      'hs-CRP',
      'Homocysteine',
      'Lp(a)',
      'ApoB',
      'ApoA1',
      'Omega-3 Index',
      'EPA',
      'DHA',
      'DHEA-S',
      'SHBG',
      'IGF-1',
      'Prolactin',
      'Progesterone',
      'Fibrinogen',
      'D-Dimer',
      'Uric Acid',
      'Magnesium',
      'Zinc',
      'Copper',
      'Selenium',
      'Vitamin A',
      'Vitamin E',
      'Vitamin K1',
      'CoQ10',
      'Cystatin C',
      'Microalbumin',
      'GGT',
      'LDH',
      'Haptoglobin',
      'Transferrin',
      'UIBC',
      'Reticulocytes',
      'ESR',
      'GlycA',
      'TMAO',
      'ADMA',
      'SDMA',
      'Myoglobin',
      'Troponin I',
      'BNP',
      'NT-proBNP',
      'Lactate',
      'Pyruvate',
      'Acetoacetate',
      'Beta-Hydroxybutyrate',
      'Glutathione',
      'GSH-Px',
      'SOD',
      'Catalase',
      '8-OHdG',
      'Malondialdehyde',
      'IL-6',
      'TNF-Alpha',
      'IL-10',
      'TGF-Beta',
      'Oxidized LDL',
      'Adiponectin',
      'Leptin',
      'Ghrelin',
      'Visfatin',
      'Resistin',
      'Osteocalcin',
      'P1NP',
      'Beta-CrossLaps',
      'Vitamin B1',
      'Vitamin B2',
      'Vitamin B3',
      'Vitamin B5',
      'Vitamin B6',
      'Biotin',
      'Manganese',
      'Chromium',
      'Molybdenum'
    ];

    return List.generate(120, (index) {
      final name = index < markerNames.length
          ? markerNames[index]
          : "Marker ${index + 1}";

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
      double value = baseValue +
          (variance * (index % 3 == 0 ? 1 : -1) * (baseValue * 0.03));

      // Override values for outliers to ensure they look correct
      if (status == 'High') {
        value = baseValue * 1.35 + (variance * 0.5);
      } else if (status == 'Low') {
        value = baseValue * 0.65 - (variance * 0.5);
      }
      // Determine category for sample data
      String category;
      if (index < 15) {
        category = 'Metabolic';
      } else if (index < 20) {
        category = 'Cardiovascular';
      } else if (index < 34) {
        category = 'Blood Count';
      } else if (index < 42) {
        category = 'Vitamins';
      } else if (index < 45) {
        category = 'Thyroid';
      } else if (index < 52) {
        category = 'Hormones';
      } else if (index < 60) {
        category = 'Minerals';
      } else if (index < 70) {
        category = 'Liver';
      } else if (index < 78) {
        category = 'Kidney';
      } else {
        category = 'Advanced';
      }

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
      'All',
      'Metabolic',
      'Cardiovascular',
      'Liver',
      'Kidney',
      'Hormones',
      'Vitamins',
      'Blood Count',
      'Minerals'
    ];
  }

  ZyndioColors get _c => Theme.of(context).extension<ZyndioColors>()!;

  String? _headerSubtitle(List<LabReport>? reports) {
    if (reports == null || reports.isEmpty) return null;
    final n = reports.length;
    return '$n ${n == 1 ? 'report' : 'reports'} on file';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider); // keep provider alive
    final reportsAsync = ref.watch(labReportsProvider);
    final analysisState = ref.watch(labAnalysisProvider);
    final c = _c;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final reportsList = reportsAsync.value;
    final filteredReports = reportsList
        ?.where((r) => (r.reportType ?? 'Blood') == widget.reportType)
        .toList();

    // Only allow sample data if real reports for THIS type are empty
    final bool canShowSample =
        filteredReports != null && filteredReports.isEmpty;
    final bool showSampleDashboard = _showSampleData && canShowSample;
    final bool showSampleToggle = canShowSample;

    return Scaffold(
      backgroundColor: context.z25.screenBg,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              dark ? Brightness.light : Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _buildHeader(_headerSubtitle(showSampleDashboard
                      ? (_cachedSampleReports ?? _getSampleReports())
                      : filteredReports)),
                ),
                const SizedBox(height: 16),
                // ── Background Analysis Banner ──
                if (analysisState.status != LabAnalysisStatus.idle &&
                    analysisState.status != LabAnalysisStatus.error)
                  _buildAnalysisBanner(analysisState),
                // ── Body ──
                Expanded(
                  child: showSampleDashboard
                      ? _buildDashboard(_cachedSampleReports ??
                          (_cachedSampleReports = _getSampleReports()))
                      : reportsAsync.when(
                          data: (reports) {
                            final filteredReports = reports
                                .where((r) =>
                                    (r.reportType ?? 'Blood') ==
                                    widget.reportType)
                                .toList();

                            if (filteredReports.isEmpty) {
                              return _buildEmptyState();
                            }
                            return _buildDashboard(filteredReports);
                          },
                          loading: () => Center(
                            child: Text(
                              'Analyzing Health Data...',
                              style: ZyndioType.subhead.copyWith(
                                color: c.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          error: (_, __) => Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                labReportsLoadFailedMessage,
                                textAlign: TextAlign.center,
                                style: ZyndioType.subhead
                                    .copyWith(color: c.textSecondary),
                              ),
                            ),
                          ),
                        ),
                ),
                if (showSampleToggle) _buildSampleToggle(c),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String? subtitle) {
    return ZyndioBackHeader(
      title: 'Lab results',
      subtitle: subtitle,
      trailing: ZyndioCircleButton(
        icon: LucideIcons.plus,
        label: 'Upload a lab report',
        onTap: () => context.push('/health_data/upload'),
      ),
    );
  }

  Widget _buildSampleToggle(ZyndioColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 8, top: 6, bottom: 6),
        decoration: zyndioCard(context, radius: 999),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'VISUALIZE SAMPLE REPORT',
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(
              width: 50,
              child: Transform.scale(
                scale: 0.75,
                child: CupertinoSwitch(
                  value: _showSampleData,
                  activeTrackColor: c.brandPrimary,
                  inactiveTrackColor: c.borderSubtle,
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
    );
  }

  Widget _buildAnalysisBanner(LabAnalysisState state) {
    final c = _c;
    final isDone = state.status == LabAnalysisStatus.completed;
    // In progress sits on the brand gradient (white content); complete is a
    // soft success card with token text.
    final Color fg = isDone ? c.statusSuccess : Colors.white;
    final Color fgMuted =
        isDone ? c.textSecondary : Colors.white.withValues(alpha: 0.78);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      decoration: isDone
          ? BoxDecoration(
              color: c.statusSuccessSubtle,
              borderRadius: BorderRadius.circular(20),
            )
          : BoxDecoration(
              gradient: ZyndioGradients.brand,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:
                      ZyndioGradients.brand.colors.last.withValues(alpha: 0.24),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isDone && state.submission != null) {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) =>
                      LabReportSubmittedScreen(submission: state.submission!),
                ),
              );
            } else {
              context.push('/health_data/upload');
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  Icon(LucideIcons.checkCircle2, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDone
                            ? 'Analysis Complete'
                            : 'AI Analysis in Progress',
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          color: fg,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        isDone
                            ? 'Your report is ready to verify'
                            : state.statusMessage,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          color: fgMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
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
                    style: const TextStyle(
                      fontFamily: ZyndioType.family,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontFeatures: ZyndioType.tabular,
                      fontSize: 15,
                    ),
                  )
                else
                  Text(
                    'VIEW',
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      color: fg,
                      fontWeight: FontWeight.w700,
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
                        color: fg.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.x, size: 14, color: fg),
                    ),
                  )
                else
                  Icon(LucideIcons.chevronRight, size: 16, color: fgMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ZyndioStateCard(
          icon: LucideIcons.flaskConical,
          title: 'No Health Data Yet',
          body:
              'Upload your latest ${widget.reportType == 'Blood' ? 'blood work' : '${widget.reportType.toLowerCase()} results'} to unlock comprehensive biomarker analysis and personalized longevity insights.',
          actionLabel: 'Show sample values',
          onAction: () {
            setState(() {
              _showSampleData = true;
              _cachedSampleReports ??= _getSampleReports();
              _selectedReportId = null;
            });
          },
        ),
      ),
    );
  }

  /// '2026-10-14' → '14 Oct 2026'; anything unparseable is shown as-is.
  static String _prettyDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildDashboard(List<LabReport> originalReports) {
    final c = _c;
    // 0. Newest report first.
    final reports = List<LabReport>.from(originalReports);
    reports.sort((a, b) => b.date.compareTo(a.date));

    // 1. Active report (the report picker sets it).
    final activeReport = reports.firstWhere((r) => r.id == _selectedReportId,
        orElse: () => reports.first);
    if (_selectedReportId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedReportId = activeReport.id);
      });
    }

    // 2. Latest value per biomarker across all reports (canonical names), so
    // older markers don't vanish when a newer report has only a few.
    final Map<String, LabMarker> aggregatedMarkersMap = {};
    for (final report in reports) {
      for (final marker in report.markers) {
        final key =
            ClinicalIntelligence.getCanonicalName(marker.name).toLowerCase();
        aggregatedMarkersMap.putIfAbsent(key, () => marker);
      }
    }
    final allAggregatedMarkers = aggregatedMarkersMap.values.toList();

    // 3. Search + category filter.
    final markers = allAggregatedMarkers.where((m) {
      final matchesSearch =
          m.name.toLowerCase().contains(_searchQuery.toLowerCase());
      if (_selectedCategory == 'All') return matchesSearch;
      return matchesSearch && _matchCategory(m, _selectedCategory);
    }).toList();

    // 4. Sort: markers outside range first, then most history, category, name.
    final Map<String, int> canonicalReportCounts = {};
    for (final report in reports) {
      for (final name in report.markers
          .map((m) => ClinicalIntelligence.getCanonicalName(m.name))
          .toSet()) {
        canonicalReportCounts[name] = (canonicalReportCounts[name] ?? 0) + 1;
      }
    }
    markers.sort((a, b) {
      if (a.isOutlier != b.isOutlier) return a.isOutlier ? -1 : 1;
      final aCount = canonicalReportCounts[
              ClinicalIntelligence.getCanonicalName(a.name)] ??
          0;
      final bCount = canonicalReportCounts[
              ClinicalIntelligence.getCanonicalName(b.name)] ??
          0;
      if (aCount != bCount) return bCount.compareTo(aCount);
      final catCompare = a.category.compareTo(b.category);
      if (catCompare != 0) return catCompare;
      return a.name.compareTo(b.name);
    });

    // 5. History per marker (oldest → newest) for the trend charts.
    final Map<String, List<Map<String, String>>> markersHistoryMap = {};
    for (final m in markers) {
      final canonicalName = ClinicalIntelligence.getCanonicalName(m.name);
      final history = <Map<String, String>>[];
      for (final r in reports) {
        for (final rm in r.markers) {
          if (ClinicalIntelligence.getCanonicalName(rm.name) == canonicalName) {
            history.add({
              'date': r.date,
              'value': rm.value,
              'originalValue': rm.value,
              'range': rm.range,
              'unit': rm.unit,
              'labName': rm.labName ?? r.labName ?? '',
            });
            break;
          }
        }
      }
      history.sort((a, b) => (a['date']!).compareTo(b['date']!));
      markersHistoryMap[canonicalName] = history;
    }

    final outlierMarkers =
        allAggregatedMarkers.where((m) => m.isOutlier).toList();
    final total = allAggregatedMarkers.length;
    final inRange = total - outlierMarkers.length;
    final categories = _categories;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        // ── Summary (Today's ring card) ──
        _SummaryCard(
          inRange: inRange,
          total: total,
          outliers: outlierMarkers,
          latestDate: _prettyDate(activeReport.date),
        ),
        const SizedBox(height: 28),

        // ── Biomarkers ──
        ZyndioSectionLabel(
          'Your biomarkers',
          trailing: Text(
            '$total markers',
            style: ZyndioType.footnote.copyWith(color: c.textTertiary),
          ),
        ),
        Container(
          decoration: zyndioCard(context, radius: 999),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: ZyndioType.subhead.copyWith(color: c.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search biomarkers',
              hintStyle: ZyndioType.subhead.copyWith(color: c.textTertiary),
              prefixIcon:
                  Icon(LucideIcons.search, size: 18, color: c.textTertiary),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ZyndioSegmentedTabs(
          labels: categories,
          selected: categories
              .indexOf(_selectedCategory)
              .clamp(0, categories.length - 1),
          onSelected: (i) => setState(() => _selectedCategory = categories[i]),
        ),
        const SizedBox(height: 16),
        if (markers.isEmpty)
          _buildEmptySearchState()
        else
          for (var i = 0; i < markers.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            BiomarkerCard(
              marker: markers[i],
              isImmersive: false,
              history: _normalisedHistory(
                markersHistoryMap[ClinicalIntelligence.getCanonicalName(
                        markers[i].name)] ??
                    const [],
                ClinicalIntelligence.getCanonicalName(markers[i].name),
              ),
            ),
          ],
        const SizedBox(height: 28),

        // ── Reports ──
        ZyndioSectionLabel(
          'Your reports',
          trailing: reports.length > 3
              ? GestureDetector(
                  onTap: () => _showReportSelector(context, reports),
                  child: Text(
                    'See all',
                    style: ZyndioType.footnote.copyWith(
                        color: c.brandPrimary, fontWeight: FontWeight.w600),
                  ),
                )
              : null,
        ),
        for (final (i, r) in reports.take(3).indexed) ...[
          ZyndioListRow(
            icon: LucideIcons.fileText,
            tint: const [
              ZyndioTint.violet,
              ZyndioTint.blue,
              ZyndioTint.teal
            ][i % 3],
            title: r.title.isNotEmpty ? r.title : 'Lab report',
            subtitle:
                '${_prettyDate(r.date)} · ${r.markers.length} ${r.markers.length == 1 ? 'marker' : 'markers'}',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReportDetailScreen(report: r)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ZyndioOutlineButton(
          label: 'Manage reports',
          icon: LucideIcons.settings2,
          onTap: () => _showReportSelector(context, reports),
        ),
        const SizedBox(height: 12),
        ZyndioGradientButton(
          label: 'Upload a lab report',
          icon: LucideIcons.upload,
          trailingArrow: false,
          onTap: () => context.push('/health_data/upload'),
        ),
        const SizedBox(height: 20),
        const DefaultRangesCaveat(),
      ],
    );
  }

  /// When a marker's history mixes units, convert to the canonical unit so
  /// the trend chart compares like with like.
  List<Map<String, String>> _normalisedHistory(
      List<Map<String, String>> rawHistory, String canonicalMarkerName) {
    final units =
        rawHistory.map((p) => (p['unit'] ?? '').toLowerCase().trim()).toSet();
    if (units.length <= 1) return rawHistory;
    return rawHistory.map((point) {
      final rawValue = double.tryParse(
              (point['value'] ?? '').replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0.0;
      final result = UnitConverter.normalize(
        value: rawValue,
        fromUnit: point['unit'] ?? '',
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
    }).toList();
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
      builder: (context) {
        final c = Theme.of(context).extension<ZyndioColors>()!;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Text(
                      'Lab Reports',
                      style: ZyndioType.title2.copyWith(color: c.textPrimary),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.bgSunken,
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(LucideIcons.x, size: 16, color: c.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  itemCount: reports.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final report = reports[index];

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedReportId = report.id);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.bgSunken,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const ZyndioIconTile(
                              icon: LucideIcons.microscope,
                              tint: ZyndioTint.blue,
                              size: 40,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.title,
                                    style: TextStyle(
                                      fontFamily: ZyndioType.family,
                                      fontSize: 16,
                                      height: 22 / 16,
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "${report.labName ?? 'General Lab'} • ${report.date}",
                                    style: TextStyle(
                                      fontFamily: ZyndioType.family,
                                      fontSize: 13,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(context);
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: c.bgSurface,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(24)),
                                    title: Text('Delete Report?',
                                        style: ZyndioType.title3
                                            .copyWith(color: c.textPrimary)),
                                    content: Text(
                                        'This will permanently remove this lab report and its biomarker data.',
                                        style: ZyndioType.subhead.copyWith(
                                            color: c.textSecondary,
                                            height: 22 / 15)),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text('CANCEL',
                                            style: TextStyle(
                                                fontFamily: ZyndioType.family,
                                                color: c.textSecondary,
                                                fontWeight: FontWeight.w600)),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text('DELETE',
                                            style: TextStyle(
                                                fontFamily: ZyndioType.family,
                                                color: c.statusCritical,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  if (report.id.startsWith('sample')) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Sample data cannot be deleted.')),
                                    );
                                    return;
                                  }

                                  final profile =
                                      ref.read(patientProfileProvider).value;
                                  if (profile == null) return;

                                  final success = await HealthDataRepository
                                      .deleteLabReport(report.id, profile.id,
                                          report.pdfPath);

                                  if (success) {
                                    ref.invalidate(labReportsProvider);
                                    if (mounted) navigator.pop();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Report deleted successfully.')),
                                    );
                                  } else if (context.mounted) {
                                    // TC-039: a failed delete shows an error
                                    // state (it used to do nothing).
                                    messenger.showSnackBar(
                                      SnackBar(
                                          content: const Text(
                                              labReportDeleteFailedMessage),
                                          backgroundColor: c.statusCritical),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Icon(LucideIcons.trash2,
                                    size: 18, color: c.textTertiary),
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
        );
      },
    );
  }

  Widget _buildEmptySearchState() {
    final c = _c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: zyndioCard(context),
      child: Center(
        child: Column(
          children: [
            Icon(LucideIcons.searchX, size: 32, color: c.textTertiary),
            const SizedBox(height: 12),
            Text(
              "No matching biomarkers",
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lab results summary, built like Today's Longevity card: a brand ring with
/// the in-range count, a status pill and the markers to discuss.
/// APP-06: neutral wording only, never a grade of the patient.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.inRange,
    required this.total,
    required this.outliers,
    required this.latestDate,
  });

  final int inRange;
  final int total;
  final List<LabMarker> outliers;
  final String latestDate;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    final z = context.z25;
    final n = outliers.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: zyndioCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: CustomPaint(
                  painter: ZyndioRingPainter(
                    fraction: total == 0 ? 0 : inRange / total,
                    track: z.tileBg,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$inRange',
                          style: ZyndioType.numericHero.copyWith(
                              fontSize: 38, height: 1.1, color: c.textPrimary),
                        ),
                        Text(
                          'of $total',
                          style: ZyndioType.footnote
                              .copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Within range',
                      style: ZyndioType.headline
                          .copyWith(fontSize: 18, color: c.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    ZyndioPill(
                      n == 0 ? 'All in range' : '$n to discuss',
                      tone: n == 0
                          ? ZyndioPillTone.success
                          : ZyndioPillTone.critical,
                      icon: n == 0
                          ? LucideIcons.checkCircle2
                          : LucideIcons.messageCircle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Latest report $latestDate',
                      style:
                          ZyndioType.footnote.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (n > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.statusCriticalSubtle,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Outside your clinic\'s range: discuss ${n == 1 ? 'it' : 'them'} with your care team.',
                    style: ZyndioType.footnote.copyWith(
                        color: c.statusCritical, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  for (final m in outliers.take(4))
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ZyndioType.subhead.copyWith(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            '${m.value} ${m.unit}'.trim(),
                            style: ZyndioType.numeric(ZyndioType.subhead)
                                .copyWith(
                                    color: c.statusCritical,
                                    fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(LucideIcons.info, size: 15, color: c.textTertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'A summary of your lab values. Not a diagnosis.',
                  style: ZyndioType.footnote.copyWith(color: c.textTertiary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
