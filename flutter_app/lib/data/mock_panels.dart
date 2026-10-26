import '../models/lab_report.dart';

final LabReport gutMicrobiomeReport = LabReport(
  id: 'sample_gut_microbiome',
  date: '2026-07-15',
  title: 'Comprehensive Gut Microbiome',
  summary: 'Analysis of intestinal flora, diversity, and pathogen detection.',
  reportType: 'gut_microbiome',
  labName: 'Viome',
  aiInterpretation: 'Your gut diversity is above average. We found a healthy ratio of Firmicutes to Bacteroidetes, but a slight elevation in opportunistic bacteria which may cause occasional bloating.',
  panelMetadata: PanelMetadata(
    phylumRatios: [
      {'name': 'Firmicutes', 'percentage': 45.2, 'color': '#10B981'},
      {'name': 'Bacteroidetes', 'percentage': 38.5, 'color': '#3B82F6'},
      {'name': 'Proteobacteria', 'percentage': 12.1, 'color': '#F59E0B'},
      {'name': 'Actinobacteria', 'percentage': 4.2, 'color': '#8B5CF6'},
    ],
    diversityIndices: [
      {'name': 'Shannon Index', 'value': 4.2, 'status': 'Optimal'},
      {'name': 'Simpson Index', 'value': 0.88, 'status': 'Optimal'},
      {'name': 'F:B Ratio', 'value': 1.17, 'status': 'Normal'},
    ],
    pathogens: [
      {'name': 'C. difficile', 'detected': false},
      {'name': 'H. pylori', 'detected': false},
      {'name': 'Salmonella spp.', 'detected': false},
      {'name': 'Candida albicans', 'detected': true, 'level': 'Moderate'},
    ],
  ),
  markers: [
    LabMarker(name: 'Akkermansia muciniphila', value: '4.5', range: '2-5', status: 'Optimal', category: 'Beneficial Bacteria', unit: '%'),
    LabMarker(name: 'Lactobacillus spp.', value: '2.1', range: '> 1.5', status: 'Optimal', category: 'Beneficial Bacteria', unit: '%'),
    LabMarker(name: 'Bifidobacterium spp.', value: '1.2', range: '> 1.0', status: 'Normal', category: 'Beneficial Bacteria', unit: '%'),
    LabMarker(name: 'Faecalibacterium prausnitzii', value: '3.8', range: '> 2.0', status: 'Optimal', category: 'Beneficial Bacteria', unit: '%'),
    LabMarker(name: 'Escherichia spp.', value: '15.2', range: '< 10', status: 'High', category: 'Commensal Bacteria', unit: '%', insight: 'Elevated levels may indicate dysbiosis.'),
    LabMarker(name: 'Butyrate Production', value: 'High', range: 'Moderate-High', status: 'Optimal', category: 'Metabolites', unit: 'Relative'),
    LabMarker(name: 'Propionate Production', value: 'Moderate', range: 'Moderate-High', status: 'Normal', category: 'Metabolites', unit: 'Relative'),
  ],
);

final LabReport geneticPanelReport = LabReport(
  id: 'sample_genetic',
  date: '2026-06-10',
  title: 'Comprehensive DNA & Methylation',
  summary: 'Analysis of key genetic variants impacting methylation, detoxification, and cardiovascular health.',
  reportType: 'genetic',
  labName: '10x Genomics',
  aiInterpretation: 'You have the MTHFR C677T heterozygous variant, which mildly reduces methylation efficiency. Your cardiovascular and detox genes look optimal. Focus on bioavailable B-vitamins.',
  panelMetadata: PanelMetadata(
    isOneTime: true,
  ),
  markers: [
    LabMarker(name: 'MTHFR C677T', value: 'C/T', range: 'C/C', status: 'Abnormal', category: 'Methylation Genes', insight: 'Heterozygous. Mild reduction in enzyme efficiency (approx. 30%). Recommend methylfolate.'),
    LabMarker(name: 'MTHFR A1298C', value: 'A/A', range: 'A/A', status: 'Optimal', category: 'Methylation Genes', insight: 'Normal variant. No additional impairment.'),
    LabMarker(name: 'COMT V158M', value: 'Val/Val', range: 'Val/Met', status: 'Optimal', category: 'Methylation Genes', insight: 'Fast clearance of stress hormones. Handles methyl donors well.'),
    LabMarker(name: 'APOE', value: 'e3/e3', range: 'e3/e3', status: 'Optimal', category: 'Cardiovascular Genes', insight: 'Normal cardiovascular and Alzheimer\'s risk baseline.'),
    LabMarker(name: 'FTO (rs9939609)', value: 'T/A', range: 'T/T', status: 'Abnormal', category: 'Metabolic Genes', insight: 'Slightly higher predisposition to weight gain. Focus on satiety and protein.'),
    LabMarker(name: 'GSTP1', value: 'Ile/Val', range: 'Ile/Ile', status: 'Abnormal', category: 'Detoxification', insight: 'Mildly reduced Phase II detoxification capacity.'),
    LabMarker(name: 'VDR Taq', value: 'T/T', range: 'T/T', status: 'Optimal', category: 'Nutrient Metabolism', insight: 'Normal Vitamin D receptor sensitivity.'),
  ],
);

final LabReport biologicalAgeReport = LabReport(
  id: 'sample_bio_age',
  date: '2026-07-01',
  title: 'Epigenetic Biological Age',
  summary: 'Advanced DNA methylation analysis to determine cellular age and pace of aging.',
  reportType: 'methylation',
  labName: 'TruDiagnostic',
  aiInterpretation: 'Your biological age is tracking 2.8 years younger than your chronological age. Your DunedinPACE score indicates you are aging 15% slower than average.',
  panelMetadata: PanelMetadata(
    biologicalAge: 31.2,
    chronologicalAge: 34.0,
    ageAcceleration: -2.8,
    paceOfAging: 0.85,
    clockScores: [
      {'name': 'Horvath Clock', 'value': 33.1},
      {'name': 'Hannum Clock', 'value': 31.8},
      {'name': 'PhenoAge', 'value': 30.5},
      {'name': 'GrimAge', 'value': 32.4},
    ],
  ),
  markers: [
    LabMarker(name: 'Immune System Age', value: '33', range: '<34', status: 'Optimal', category: 'System Ages', unit: 'years'),
    LabMarker(name: 'Metabolic Age', value: '30', range: '<34', status: 'Optimal', category: 'System Ages', unit: 'years'),
    LabMarker(name: 'Inflammation Age', value: '32', range: '<34', status: 'Optimal', category: 'System Ages', unit: 'years'),
    LabMarker(name: 'Telomere Length', value: '8.2', range: '>7.5', status: 'Optimal', category: 'Cellular Health', unit: 'kb'),
    LabMarker(name: 'Mitotic Clock', value: 'Normal', range: 'Normal', status: 'Optimal', category: 'Cellular Health', unit: 'rate'),
  ],
);

final LabReport heavyMetalsReport = LabReport(
  id: 'sample_heavy_metals',
  date: '2026-06-20',
  title: 'Heavy Metals Toxicity',
  summary: 'Analysis of toxic heavy metal burden and essential mineral displacement.',
  reportType: 'heavy_metals',
  labName: 'Doctor\'s Data',
  aiInterpretation: 'Mercury levels are slightly elevated, likely from seafood consumption. Lead is well within normal limits. Essential minerals look strong, preventing major displacement.',
  panelMetadata: PanelMetadata(
    specimenType: 'provoked_urine',
    provocationAgent: 'DMSA 500mg',
  ),
  markers: [
    LabMarker(name: 'Mercury (Hg)', value: '8.4', range: '< 5.0', minRange: 0, maxRange: 5.0, status: 'High', category: 'Toxic Metals', unit: 'µg/g cr', insight: 'Elevated. Suggests recent exposure or accumulation. Consider reducing large fish intake.'),
    LabMarker(name: 'Lead (Pb)', value: '1.2', range: '< 2.0', minRange: 0, maxRange: 2.0, status: 'Normal', category: 'Toxic Metals', unit: 'µg/g cr'),
    LabMarker(name: 'Arsenic (As)', value: '35', range: '< 50', minRange: 0, maxRange: 50, status: 'Normal', category: 'Toxic Metals', unit: 'µg/g cr', insight: 'High-normal. Monitor rice and groundwater sources.'),
    LabMarker(name: 'Cadmium (Cd)', value: '0.4', range: '< 1.0', minRange: 0, maxRange: 1.0, status: 'Optimal', category: 'Toxic Metals', unit: 'µg/g cr'),
    LabMarker(name: 'Aluminum (Al)', value: '12', range: '< 35', minRange: 0, maxRange: 35, status: 'Optimal', category: 'Toxic Metals', unit: 'µg/g cr'),
    LabMarker(name: 'Zinc (Zn)', value: '850', range: '400-1200', minRange: 400, maxRange: 1200, status: 'Optimal', category: 'Essential Minerals', unit: 'µg/g cr'),
    LabMarker(name: 'Selenium (Se)', value: '65', range: '40-100', minRange: 40, maxRange: 100, status: 'Optimal', category: 'Essential Minerals', unit: 'µg/g cr'),
  ],
);

final LabReport toxicityReport = LabReport(
  id: 'sample_toxicity',
  date: '2026-05-15',
  title: 'Environmental Toxins & Mold',
  summary: 'Screening for mycotoxins, VOCs, and agricultural chemicals.',
  reportType: 'toxicity',
  labName: 'Great Plains Lab',
  aiInterpretation: 'We detected mild levels of Ochratoxin A, a common mold toxin. Your VOC clearance is good, but pesticide markers are borderline. Consider switching to organic produce for the dirty dozen.',
  panelMetadata: PanelMetadata(
    toxinCategory: 'mixed',
    toxinLoadScore: 68.0, // 0-100, higher is worse
  ),
  markers: [
    LabMarker(name: 'Ochratoxin A', value: '4.2', range: '< 2.0', minRange: 0, maxRange: 2.0, status: 'High', category: 'Mycotoxins', unit: 'ng/g cr', insight: 'Common water-damaged building toxin. Binder protocol recommended.'),
    LabMarker(name: 'Aflatoxin M1', value: '0.3', range: '< 0.5', minRange: 0, maxRange: 0.5, status: 'Normal', category: 'Mycotoxins', unit: 'ng/g cr'),
    LabMarker(name: 'Glyphosate', value: '1.8', range: '< 2.5', minRange: 0, maxRange: 2.5, status: 'Normal', category: 'Pesticides', unit: 'µg/g cr', insight: 'Approaching upper limit. Wash produce thoroughly or buy organic.'),
    LabMarker(name: 'Atrazine', value: '0.1', range: '< 0.5', minRange: 0, maxRange: 0.5, status: 'Optimal', category: 'Pesticides', unit: 'µg/g cr'),
    LabMarker(name: 'Xylene', value: '0.8', range: '< 1.5', minRange: 0, maxRange: 1.5, status: 'Normal', category: 'VOCs', unit: 'µg/g cr'),
    LabMarker(name: 'Phthalates (MEHP)', value: '12', range: '< 40', minRange: 0, maxRange: 40, status: 'Optimal', category: 'Plasticizers', unit: 'µg/g cr'),
    LabMarker(name: 'Parabens', value: '5', range: '< 20', minRange: 0, maxRange: 20, status: 'Optimal', category: 'Cosmetics', unit: 'µg/g cr'),
  ],
);

final List<LabReport> mockAdvancedPanels = [
  gutMicrobiomeReport,
  geneticPanelReport,
  biologicalAgeReport,
  heavyMetalsReport,
  toxicityReport,
];
