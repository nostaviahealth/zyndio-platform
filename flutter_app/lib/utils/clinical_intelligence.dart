import '../models/lab_report.dart';
import '../config/biomarker_constants.dart';

class ClinicalIntelligence {
  /// Map of biomarker names to their calibration data
  static final Map<String, MarkerDefinition> _definitions = {
    'HbA1c': MarkerDefinition(
      name: 'HbA1c',
      unit: '%',
      minRange: 4.0,
      maxRange: 5.6,
      minOptimal: 4.8,
      maxOptimal: 5.2,
      citations: [
        ClinicalCitation(
          source: 'Levine et al., 2018',
          title: 'An epigenetic biomarker of aging for lifespan and healthspan',
          url: 'https://pubmed.ncbi.nlm.nih.gov/29676998/',
        ),
        ClinicalCitation(
          source: 'ADA Standards',
          title: 'Classification and Diagnosis of Diabetes',
          url: 'https://diabetesjournals.org/care/article/46/Supplement_1/S19/148529/',
        ),
      ],
    ),
    'Vitamin D': MarkerDefinition(
      name: 'Vitamin D',
      unit: 'ng/mL',
      minRange: 30.0,
      maxRange: 100.0,
      minOptimal: 40.0,
      maxOptimal: 80.0,
      citations: [
        ClinicalCitation(
          source: 'Holick MF, et al.',
          title: 'Evaluation, treatment, and prevention of vitamin D deficiency',
          url: 'https://pubmed.ncbi.nlm.nih.gov/21646368/',
        ),
      ],
    ),
    'hs-CRP': MarkerDefinition(
      name: 'hs-CRP',
      unit: 'mg/L',
      minRange: 0.0,
      maxRange: 3.0,
      minOptimal: 0.0,
      maxOptimal: 1.0,
      citations: [
        ClinicalCitation(
          source: 'Ridker PM, 2003',
          title: 'C-reactive protein and the prediction of cardiovascular events',
          url: 'https://pubmed.ncbi.nlm.nih.gov/12711671/',
        ),
      ],
    ),
    'LDL': MarkerDefinition(
      name: 'LDL',
      unit: 'mg/dL',
      minRange: 0.0,
      maxRange: 100.0,
      minOptimal: 0.0,
      maxOptimal: 70.0,
      citations: [
        ClinicalCitation(
          source: 'Ference BA, et al., 2017',
          title: 'Low-density lipoproteins cause atherosclerotic cardiovascular disease',
          url: 'https://pubmed.ncbi.nlm.nih.gov/28444290/',
        ),
      ],
    ),
    'HDL': MarkerDefinition(
      name: 'HDL',
      unit: 'mg/dL',
      minRange: 40.0,
      maxRange: 100.0,
      minOptimal: 60.0,
      maxOptimal: 90.0,
      citations: [
        ClinicalCitation(
          source: 'Sirtori CR, 2006',
          title: 'HDL and cardiovascular risk',
          url: 'https://pubmed.ncbi.nlm.nih.gov/16843445/',
        ),
      ],
    ),
    'Triglycerides': MarkerDefinition(
      name: 'Triglycerides',
      unit: 'mg/dL',
      minRange: 0.0,
      maxRange: 150.0,
      minOptimal: 0.0,
      maxOptimal: 100.0,
      citations: [
        ClinicalCitation(
          source: 'Nordestgaard BG, 2016',
          title: 'Triglyceride-rich lipoproteins and atherosclerotic cardiovascular disease',
          url: 'https://pubmed.ncbi.nlm.nih.gov/27918805/',
        ),
      ],
    ),
    'TSH': MarkerDefinition(
      name: 'TSH',
      unit: 'mIU/L',
      minRange: 0.4,
      maxRange: 4.5,
      minOptimal: 1.0,
      maxOptimal: 2.5,
      citations: [
        ClinicalCitation(
          source: 'Garber JR, et al.',
          title: 'Clinical Practice Guidelines for Hypothyroidism in Adults',
          url: 'https://pubmed.ncbi.nlm.nih.gov/22961224/',
        ),
      ],
    ),
    'Insulin (Fasting)': MarkerDefinition(
      name: 'Insulin (Fasting)',
      unit: 'µIU/mL',
      minRange: 2.6,
      maxRange: 24.9,
      minOptimal: 2.6,
      maxOptimal: 5.0,
      citations: [
        ClinicalCitation(
          source: 'Centenarian Studies',
          title: 'Low fasting insulin levels and longevity',
          url: 'https://pubmed.ncbi.nlm.nih.gov/12970313/',
        ),
      ],
    ),
    'Glucose (Fasting)': MarkerDefinition(
      name: 'Glucose (Fasting)',
      unit: 'mg/dL',
      minRange: 70.0,
      maxRange: 99.0,
      minOptimal: 70.0,
      maxOptimal: 85.0,
      citations: [
        ClinicalCitation(
          source: 'Tiinamaija T, et al.',
          title: 'Fasting glucose and risk of cardiovascular disease',
          url: 'https://pubmed.ncbi.nlm.nih.gov/21220444/',
        ),
      ],
    ),
    'ALT': MarkerDefinition(
      name: 'ALT',
      unit: 'U/L',
      minRange: 0.0,
      maxRange: 40.0,
      minOptimal: 0.0,
      maxOptimal: 25.0,
      citations: [
        ClinicalCitation(
          source: 'NAFLD Research',
          title: 'Liver enzymes and metabolic syndrome',
          url: 'https://pubmed.ncbi.nlm.nih.gov/25559336/',
        ),
      ],
    ),
    'AST': MarkerDefinition(
      name: 'AST',
      unit: 'U/L',
      minRange: 0.0,
      maxRange: 40.0,
      minOptimal: 0.0,
      maxOptimal: 25.0,
      citations: [
        ClinicalCitation(
          source: 'Clinical Chemistry',
          title: 'Reference intervals for liver enzymes',
          url: 'https://pubmed.ncbi.nlm.nih.gov/15613524/',
        ),
      ],
    ),
    'Creatinine': MarkerDefinition(
      name: 'Creatinine',
      unit: 'mg/dL',
      minRange: 0.7,
      maxRange: 1.3,
      minOptimal: 0.7,
      maxOptimal: 1.0,
      citations: [
        ClinicalCitation(
          source: 'National Kidney Foundation',
          title: 'Serum Creatinine Reference Ranges',
          url: 'https://www.kidney.org/atoz/content/gfr',
        ),
      ],
    ),
    'eGFR': MarkerDefinition(
      name: 'eGFR',
      unit: 'mL/min',
      minRange: 60.0,
      maxRange: 120.0,
      minOptimal: 90.0,
      maxOptimal: 120.0,
      citations: [
        ClinicalCitation(
          source: 'KDIGO Guidelines',
          title: 'Evaluation and Management of Chronic Kidney Disease',
          url: 'https://kdigo.org/guidelines/ckd-evaluation-and-management/',
        ),
      ],
    ),
    'ApoB': MarkerDefinition(
      name: 'ApoB',
      unit: 'mg/dL',
      minRange: 0.0,
      maxRange: 90.0,
      minOptimal: 0.0,
      maxOptimal: 60.0,
      citations: [
        ClinicalCitation(
          source: 'Sniderman AD, et al.',
          title: 'Apolipoprotein B and Cardiovascular Risk',
          url: 'https://pubmed.ncbi.nlm.nih.gov/30584050/',
        ),
      ],
    ),
    'Homocysteine': MarkerDefinition(
      name: 'Homocysteine',
      unit: 'µmol/L',
      minRange: 0.0,
      maxRange: 15.0,
      minOptimal: 0.0,
      maxOptimal: 9.0,
      citations: [
        ClinicalCitation(
          source: 'Smith AD, et al.',
          title: 'Homocysteine-lowering, B vitamins, and brain atrophy',
          url: 'https://pubmed.ncbi.nlm.nih.gov/20838622/',
        ),
      ],
    ),
    'IGF-1': MarkerDefinition(
      name: 'IGF-1',
      unit: 'ng/mL',
      minRange: 50.0,
      maxRange: 300.0,
      minOptimal: 120.0,
      maxOptimal: 180.0,
      citations: [
        ClinicalCitation(
          source: 'Milman S, et al.',
          title: 'Low insulin-like growth factor-1 level predicts survival in humans',
          url: 'https://pubmed.ncbi.nlm.nih.gov/24719268/',
        ),
      ],
    ),
    'DHEA-S': MarkerDefinition(
      name: 'DHEA-S',
      unit: 'µg/dL',
      minRange: 100.0,
      maxRange: 500.0,
      minOptimal: 300.0,
      maxOptimal: 450.0,
      citations: [
        ClinicalCitation(
          source: 'Orentreich N, et al.',
          title: 'Age-related decline of DHEA-S',
          url: 'https://pubmed.ncbi.nlm.nih.gov/6462704/',
        ),
      ],
    ),
    'Ferritin': MarkerDefinition(
      name: 'Ferritin',
      unit: 'ng/mL',
      minRange: 30.0,
      maxRange: 400.0,
      minOptimal: 70.0,
      maxOptimal: 150.0,
      citations: [
        ClinicalCitation(
          source: 'WHO Guideline',
          title: 'Use of ferritin concentrations to assess iron status in populations',
          url: 'https://www.who.int/publications/i/item/9789240000124',
        ),
      ],
    ),
  };

  /// Enhance a raw LabMarker with clinical intelligence.
  /// ADDITIVE ONLY: preserves the lab's own range and status (source of truth).
  /// Adds longevity optimal ranges and clinical citations as bonus data.
  /// PROMOTES status to 'Optimal' if it is currently 'In-range' and hits target.
  static LabMarker calibrate(LabMarker marker) {
    final def = _definitions[marker.name] ?? _findFuzzy(marker.name);
    if (def == null) return marker;

    String finalStatus = marker.status;
    final val = double.tryParse(marker.value.replaceAll(RegExp(r'[^0-9.]'), ''));
    
    // Only promote to Optimal if the lab says it is healthy (In-range/Normal)
    final isHealthy = marker.status.toLowerCase() == 'in-range' || marker.status.toLowerCase() == 'normal';
    
    if (isHealthy && val != null) {
      if (val >= def.minOptimal && val <= def.maxOptimal) {
        finalStatus = 'Optimal';
      }
    }

    // 2. Fallback for missing range string
    String finalRange = marker.range;
    if (finalRange == '--' || finalRange.isEmpty) {
      finalRange = "${def.minRange} - ${def.maxRange}";
    }

    return LabMarker(
      name: marker.name,
      value: marker.value,
      range: finalRange,
      status: finalStatus,
      insight: marker.insight,
      category: marker.category,
      unit: marker.unit,
      labName: marker.labName,
      minRange: marker.minRange ?? def.minRange,
      maxRange: marker.maxRange ?? def.maxRange,
      minOptimal: marker.minOptimal ?? def.minOptimal,
      maxOptimal: marker.maxOptimal ?? def.maxOptimal,
      citations: marker.citations ?? (def.citations.isNotEmpty ? def.citations : null),
    );
  }

  /// Returns a standardized name for a biomarker to handle variations across labs.
  /// e.g. "Vitamin D (25-OH)" and "25-Hydroxy Vitamin D" -> "Vitamin D"
  static String getCanonicalName(String name) {
    final def = _findFuzzy(name);
    if (def != null) return def.name;
    return name; // Fallback to original name if not in our database
  }

  static final Map<String, MarkerDefinition?> _fuzzyCache = {};

  static MarkerDefinition? _findFuzzy(String name) {
    if (_fuzzyCache.containsKey(name)) {
      return _fuzzyCache[name];
    }

    final normalized = name.toLowerCase();
    MarkerDefinition? result;
    
    // 1. Check specific definitions (with citations)
    for (var key in _definitions.keys) {
      if (normalized.contains(key.toLowerCase()) || key.toLowerCase().contains(normalized)) {
        result = _definitions[key];
        break;
      }
    }

    // 2. Fallback to biomarker_constants.dart (no citations, but has ranges)
    if (result == null) {
      for (var range in biomarkerRanges) {
        if (normalized == range.name.toLowerCase() || 
            range.aliases.any((a) => a.toLowerCase() == normalized) ||
            normalized.contains(range.name.toLowerCase())) {
          
          result = MarkerDefinition(
            name: range.name,
            unit: range.unit,
            minRange: range.inRangeMin ?? 0.0,
            maxRange: range.inRangeMax ?? (range.optimalMax != null ? range.optimalMax! * 1.5 : 200.0),
            minOptimal: range.optimalMin ?? range.inRangeMin ?? 0.0,
            maxOptimal: range.optimalMax ?? range.inRangeMax ?? 100.0,
            citations: [], // No specific citations for these yet
          );
          break;
        }
      }
    }
    
    _fuzzyCache[name] = result;
    return result;
  }

}

class MarkerDefinition {
  final String name;
  final String unit;
  final double minRange;
  final double maxRange;
  final double minOptimal;
  final double maxOptimal;
  final List<ClinicalCitation> citations;

  MarkerDefinition({
    required this.name,
    required this.unit,
    required this.minRange,
    required this.maxRange,
    required this.minOptimal,
    required this.maxOptimal,
    required this.citations,
  });
}
