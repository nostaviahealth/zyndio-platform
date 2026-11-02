import { User, LabReport, Message } from './types';

export const CURRENT_USER: User = {
  id: 'u-1', // Fictional demo patient (TC-030 item 12: no real names)
  name: 'Sam Patel',
  age: 34,
  bioAge: 31,
  avatarUrl: 'https://ui-avatars.com/api/?name=Sam+Patel&background=0D8ABC&color=fff',
  healthGrade: 'A-',
  primaryGoal: 'Longevity',
  isPremium: true,
  paceOfAging: 0.85, // Aging at 85% of normal rate - slower is better
};

export const BIOMARKER_HISTORY = [
  { date: 'Jan', value: 6.2, unit: '%', status: 'Abnormal' },
  { date: 'Mar', value: 6.0, unit: '%', status: 'Abnormal' },
  { date: 'May', value: 5.8, unit: '%', status: 'Normal' },
  { date: 'Jul', value: 5.6, unit: '%', status: 'Optimal' },
  { date: 'Sep', value: 5.5, unit: '%', status: 'Optimal' },
  { date: 'Nov', value: 5.7, unit: '%', status: 'Normal' },
];

export const DISEASE_RISK_HISTORY = [
  { date: 'Jan', value: 24, unit: '%', status: 'High' },
  { date: 'Mar', value: 22, unit: '%', status: 'High' },
  { date: 'May', value: 19, unit: '%', status: 'Medium' },
  { date: 'Jul', value: 17, unit: '%', status: 'Medium' },
  { date: 'Sep', value: 14, unit: '%', status: 'Low' },
  { date: 'Nov', value: 12, unit: '%', status: 'Low' },
];

export const RISK_DATA = [
  { subject: 'Heart Health', A: 72, fullMark: 100 },
  { subject: 'Thyroid Health', A: 92, fullMark: 100 },
  { subject: 'Immune Regulation', A: 85, fullMark: 100 },
  { subject: 'Hormone Health', A: 68, fullMark: 100 },
  { subject: 'Metabolic Health', A: 55, fullMark: 100 },
  { subject: 'Liver Health', A: 65, fullMark: 100 },
  { subject: 'Kidney Health', A: 95, fullMark: 100 },
  { subject: 'Nutrients', A: 78, fullMark: 100 },
  { subject: 'Blood Health', A: 88, fullMark: 100 },
  { subject: 'Inflammation', A: 60, fullMark: 100 },
];

export const AI_ANALYSIS_DATA = {
  diseaseRisks: [
    { condition: 'Type 2 Diabetes', probability: 78, level: 'High', drivers: ['HbA1c Trend', 'Fasting Insulin'] },
    { condition: 'Atherosclerotic CVD', probability: 42, level: 'Moderate', drivers: ['LDL-C', 'ApoB', 'Triglycerides'] },
    { condition: 'Metabolic Syndrome', probability: 65, level: 'High', drivers: ['Waist Circumference', 'Blood Pressure'] },
    { condition: 'Non-Alcoholic Fatty Liver', probability: 15, level: 'Low', drivers: ['ALT', 'AST'] },
  ],
  functionalGrades: [
    { system: 'Cardiovascular', grade: 'B-', score: 72, status: 'Stable' },
    { system: 'Metabolic', grade: 'C+', score: 58, status: 'Action Required' },
    { system: 'Immune', grade: 'A', score: 94, status: 'Optimal' },
    { system: 'Hormonal', grade: 'B', score: 82, status: 'Good' },
    { system: 'Liver', grade: 'C', score: 65, status: 'Warning' },
    { system: 'Neurological', grade: 'A-', score: 91, status: 'Optimal' },
  ]
};

export const LAB_REPORTS: LabReport[] = [
  {
    id: 'r1',
    date: '2023-11-15',
    title: 'Comprehensive Health Panel (100 Biomarkers)',
    summary: 'Complete metabolic, cardiovascular, hormonal, vitamin, and functional health assessment.',
    markers: [
      // Metabolic Health (15 markers)
      { name: 'HbA1c', value: '5.7%', range: '< 5.7%', status: 'Normal', insight: 'Borderline pre-diabetic range, showing improvement.' },
      { name: 'Fasting Glucose', value: '95 mg/dL', range: '70-100 mg/dL', status: 'Optimal' },
      { name: 'Fasting Insulin', value: '8.2 µIU/mL', range: '2.6-24.9 µIU/mL', status: 'Optimal' },
      { name: 'HOMA-IR', value: '1.9', range: '< 2.0', status: 'Optimal', insight: 'Good insulin sensitivity.' },
      { name: 'Triglycerides', value: '105 mg/dL', range: '< 150 mg/dL', status: 'Optimal' },
      { name: 'Total Cholesterol', value: '185 mg/dL', range: '< 200 mg/dL', status: 'Optimal' },
      { name: 'LDL Cholesterol', value: '95 mg/dL', range: '< 100 mg/dL', status: 'Optimal', insight: 'Improved with dietary changes.' },
      { name: 'HDL Cholesterol', value: '58 mg/dL', range: '> 40 mg/dL', status: 'Optimal' },
      { name: 'ApoB', value: '82 mg/dL', range: '< 90 mg/dL', status: 'Optimal' },
      { name: 'Lp(a)', value: '18 mg/dL', range: '< 30 mg/dL', status: 'Optimal' },
      { name: 'Non-HDL Cholesterol', value: '127 mg/dL', range: '< 130 mg/dL', status: 'Optimal' },
      { name: 'TC/HDL Ratio', value: '3.2', range: '< 5.0', status: 'Optimal' },
      { name: 'TG/HDL Ratio', value: '1.8', range: '< 2.0', status: 'Optimal' },
      { name: 'Uric Acid', value: '5.8 mg/dL', range: '3.5-7.2 mg/dL', status: 'Optimal' },
      { name: 'Homocysteine', value: '9.2 µmol/L', range: '< 15 µmol/L', status: 'Optimal' },

      // Cardiovascular (8 markers)
      { name: 'CRP (hs)', value: '0.8 mg/L', range: '< 1.0 mg/L', status: 'Optimal', insight: 'Low systemic inflammation.' },
      { name: 'Fibrinogen', value: '285 mg/dL', range: '200-400 mg/dL', status: 'Optimal' },
      { name: 'D-Dimer', value: '0.3 µg/mL', range: '< 0.5 µg/mL', status: 'Optimal' },
      { name: 'NT-proBNP', value: '68 pg/mL', range: '< 125 pg/mL', status: 'Optimal' },
      { name: 'Troponin I', value: '< 0.01 ng/mL', range: '< 0.04 ng/mL', status: 'Optimal' },
      { name: 'MPO (Myeloperoxidase)', value: '385 pmol/L', range: '< 500 pmol/L', status: 'Optimal' },
      { name: 'Omega-3 Index', value: '6.8%', range: '> 8%', status: 'Normal', insight: 'Increase fish oil supplementation.' },
      { name: 'Omega-6/Omega-3 Ratio', value: '4.2', range: '< 4.0', status: 'Normal' },

      // Liver Function (10 markers)
      { name: 'ALT (SGPT)', value: '28 U/L', range: '7-56 U/L', status: 'Optimal' },
      { name: 'AST (SGOT)', value: '24 U/L', range: '10-40 U/L', status: 'Optimal' },
      { name: 'AST/ALT Ratio', value: '0.86', range: '0.8-2.0', status: 'Optimal' },
      { name: 'GGT', value: '22 U/L', range: '9-48 U/L', status: 'Optimal' },
      { name: 'Alkaline Phosphatase', value: '68 U/L', range: '44-147 U/L', status: 'Optimal' },
      { name: 'Total Bilirubin', value: '0.8 mg/dL', range: '0.1-1.2 mg/dL', status: 'Optimal' },
      { name: 'Direct Bilirubin', value: '0.2 mg/dL', range: '0-0.3 mg/dL', status: 'Optimal' },
      { name: 'Total Protein', value: '7.2 g/dL', range: '6.0-8.3 g/dL', status: 'Optimal' },
      { name: 'Albumin', value: '4.5 g/dL', range: '3.5-5.5 g/dL', status: 'Optimal' },
      { name: 'Globulin', value: '2.7 g/dL', range: '2.0-3.5 g/dL', status: 'Optimal' },

      // Kidney Function (6 markers)
      { name: 'Creatinine', value: '0.95 mg/dL', range: '0.7-1.3 mg/dL', status: 'Optimal' },
      { name: 'BUN (Blood Urea Nitrogen)', value: '15 mg/dL', range: '7-20 mg/dL', status: 'Optimal' },
      { name: 'BUN/Creatinine Ratio', value: '15.8', range: '10-20', status: 'Optimal' },
      { name: 'eGFR', value: '95 mL/min', range: '> 60 mL/min', status: 'Optimal' },
      { name: 'Cystatin C', value: '0.88 mg/L', range: '0.51-0.98 mg/L', status: 'Optimal' },
      { name: 'Urine Microalbumin', value: '12 mg/L', range: '< 30 mg/L', status: 'Optimal' },

      // Thyroid (6 markers)
      { name: 'TSH', value: '1.8 mIU/L', range: '0.4-4.0 mIU/L', status: 'Optimal' },
      { name: 'Free T3', value: '3.2 pg/mL', range: '2.0-4.4 pg/mL', status: 'Optimal' },
      { name: 'Free T4', value: '1.3 ng/dL', range: '0.8-1.8 ng/dL', status: 'Optimal' },
      { name: 'T3 Reverse', value: '18 ng/dL', range: '9.2-24.1 ng/dL', status: 'Optimal' },
      { name: 'TPO Antibody', value: '< 10 IU/mL', range: '< 34 IU/mL', status: 'Optimal' },
      { name: 'Thyroglobulin', value: '22 ng/mL', range: '< 55 ng/mL', status: 'Optimal' },

      // Hormones (12 markers)
      { name: 'Testosterone (Total)', value: '625 ng/dL', range: '300-1000 ng/dL', status: 'Optimal' },
      { name: 'Testosterone (Free)', value: '18.5 pg/mL', range: '9-30 pg/mL', status: 'Optimal' },
      { name: 'SHBG', value: '38 nmol/L', range: '16.5-55.9 nmol/L', status: 'Optimal' },
      { name: 'DHEA-S', value: '285 µg/dL', range: '138-475 µg/dL', status: 'Optimal' },
      { name: 'Cortisol (AM)', value: '14.8 µg/dL', range: '6.2-19.4 µg/dL', status: 'Optimal' },
      { name: 'Estradiol', value: '28 pg/mL', range: '10-40 pg/mL', status: 'Optimal' },
      { name: 'Progesterone', value: '0.8 ng/mL', range: '< 1.4 ng/mL', status: 'Optimal' },
      { name: 'IGF-1', value: '195 ng/mL', range: '90-360 ng/mL', status: 'Optimal' },
      { name: 'Growth Hormone', value: '2.8 ng/mL', range: '< 10 ng/mL', status: 'Optimal' },
      { name: 'Prolactin', value: '12.5 ng/mL', range: '4.0-15.2 ng/mL', status: 'Optimal' },
      { name: 'FSH', value: '4.8 mIU/mL', range: '1.5-12.4 mIU/mL', status: 'Optimal' },
      { name: 'LH', value: '5.2 mIU/mL', range: '1.7-8.6 mIU/mL', status: 'Optimal' },

      // Vitamins (13 markers)
      { name: 'Vitamin D (25-OH)', value: '52 ng/mL', range: '30-100 ng/mL', status: 'Optimal' },
      { name: 'Vitamin B12', value: '685 pg/mL', range: '200-900 pg/mL', status: 'Optimal' },
      { name: 'Folate (Serum)', value: '15.8 ng/mL', range: '> 3.0 ng/mL', status: 'Optimal' },
      { name: 'Vitamin A (Retinol)', value: '58 µg/dL', range: '38-98 µg/dL', status: 'Optimal' },
      { name: 'Vitamin E', value: '12.5 mg/L', range: '5.5-17 mg/L', status: 'Optimal' },
      { name: 'Vitamin K1', value: '1.2 ng/mL', range: '0.2-3.2 ng/mL', status: 'Optimal' },
      { name: 'Vitamin C', value: '1.8 mg/dL', range: '0.4-2.0 mg/dL', status: 'Optimal' },
      { name: 'Biotin (B7)', value: '425 ng/L', range: '200-500 ng/L', status: 'Optimal' },
      { name: 'Thiamine (B1)', value: '95 nmol/L', range: '70-180 nmol/L', status: 'Optimal' },
      { name: 'Riboflavin (B2)', value: '145 µg/L', range: '100-300 µg/L', status: 'Optimal' },
      { name: 'Niacin (B3)', value: '3.8 µg/mL', range: '2-10 µg/mL', status: 'Optimal' },
      { name: 'Pantothenic Acid (B5)', value: '1.2 µg/mL', range: '0.5-2.5 µg/mL', status: 'Optimal' },
      { name: 'Pyridoxine (B6)', value: '68 nmol/L', range: '35-110 nmol/L', status: 'Optimal' },

      // Minerals & Electrolytes (10 markers)
      { name: 'Iron (Serum)', value: '95 µg/dL', range: '60-170 µg/dL', status: 'Optimal' },
      { name: 'Ferritin', value: '125 ng/mL', range: '30-400 ng/mL', status: 'Optimal' },
      { name: 'TIBC', value: '325 µg/dL', range: '250-450 µg/dL', status: 'Optimal' },
      { name: 'Transferrin Saturation', value: '29%', range: '20-50%', status: 'Optimal' },
      { name: 'Magnesium', value: '2.2 mg/dL', range: '1.7-2.2 mg/dL', status: 'Optimal' },
      { name: 'Zinc', value: '95 µg/dL', range: '60-120 µg/dL', status: 'Optimal' },
      { name: 'Copper', value: '105 µg/dL', range: '70-140 µg/dL', status: 'Optimal' },
      { name: 'Selenium', value: '125 µg/L', range: '70-150 µg/L', status: 'Optimal' },
      { name: 'Calcium', value: '9.5 mg/dL', range: '8.5-10.2 mg/dL', status: 'Optimal' },
      { name: 'Phosphorus', value: '3.8 mg/dL', range: '2.5-4.5 mg/dL', status: 'Optimal' },

      // Complete Blood Count (10 markers)
      { name: 'WBC (White Blood Cells)', value: '6.8 K/µL', range: '4.5-11 K/µL', status: 'Optimal' },
      { name: 'RBC (Red Blood Cells)', value: '5.2 M/µL', range: '4.7-6.1 M/µL', status: 'Optimal' },
      { name: 'Hemoglobin', value: '15.2 g/dL', range: '13.5-17.5 g/dL', status: 'Optimal' },
      { name: 'Hematocrit', value: '45%', range: '38.3-48.6%', status: 'Optimal' },
      { name: 'MCV', value: '88 fL', range: '80-100 fL', status: 'Optimal' },
      { name: 'MCH', value: '30 pg', range: '27-33 pg', status: 'Optimal' },
      { name: 'MCHC', value: '34 g/dL', range: '32-36 g/dL', status: 'Optimal' },
      { name: 'Platelet Count', value: '245 K/µL', range: '150-400 K/µL', status: 'Optimal' },
      { name: 'Neutrophils', value: '58%', range: '40-70%', status: 'Optimal' },
      { name: 'Lymphocytes', value: '32%', range: '20-40%', status: 'Optimal' },

      // Advanced Longevity (10 markers)
      { name: 'NAD+', value: '42 µM', range: '> 35 µM', status: 'Optimal', insight: 'Key cellular energy molecule.' },
      { name: 'Telomere Length', value: '7200 bp', range: '> 6500 bp', status: 'Optimal', insight: 'Longer telomeres associated with longevity.' },
      { name: 'SIRT1 Activity', value: '1.8 units', range: '> 1.5 units', status: 'Optimal' },
      { name: 'Oxidative Stress Index', value: '285 units', range: '< 350 units', status: 'Optimal' },
      { name: 'Glutathione', value: '850 µmol/L', range: '> 600 µmol/L', status: 'Optimal' },
      { name: 'CoQ10', value: '1.2 µg/mL', range: '0.6-2.5 µg/mL', status: 'Optimal' },
      { name: 'mTOR Activity', value: '1.2 units', range: '< 2.0 units', status: 'Optimal' },
      { name: 'AMPK Activity', value: '2.8 units', range: '> 2.0 units', status: 'Optimal' },
      { name: 'IL-6 (Interleukin-6)', value: '1.8 pg/mL', range: '< 5 pg/mL', status: 'Optimal' },
      { name: 'TNF-alpha', value: '3.2 pg/mL', range: '< 8.1 pg/mL', status: 'Optimal' },
    ]
  },
  {
    id: 'r2',
    date: '2023-08-10',
    title: 'Quarterly Checkup (50 Core Markers)',
    summary: 'Routine checkup showing progress in metabolic health.',
    markers: [
      { name: 'HbA1c', value: '6.0%', range: '< 5.7%', status: 'Abnormal' },
      { name: 'Triglycerides', value: '160 mg/dL', range: '< 150 mg/dL', status: 'Abnormal' },
      { name: 'LDL Cholesterol', value: '145 mg/dL', range: '< 100 mg/dL', status: 'Abnormal' },
      { name: 'Vitamin D (25-OH)', value: '28 ng/mL', range: '30-100 ng/mL', status: 'Abnormal' },
      { name: 'TSH', value: '1.9 mIU/L', range: '0.4-4.0 mIU/L', status: 'Optimal' },
    ]
  }
];

export const CHAT_HISTORY: Message[] = [
  { id: 'm1', sender: 'user', text: 'Why is my LDL still high despite the diet?', timestamp: new Date(Date.now() - 100000) },
  { id: 'm2', sender: 'ai', text: 'While your diet has improved, LDL can be slow to respond. Your saturated fat intake has decreased by 20%, which is great. However, stress levels (cortisol) can also impact lipid metabolism.', timestamp: new Date(Date.now() - 80000) },
  { id: 'm3', sender: 'doctor', text: 'Arjun, let\'s add a specialized fiber supplement called Psyllium Husk before dinner. It binds to cholesterol efficiently. Also, your Pitta levels are high, suggesting inflammation.', timestamp: new Date(Date.now() - 50000) },
];

export const PAST_CHAT_SESSIONS = [
  { id: 's1', title: 'Lipid Panel Analysis', date: 'Nov 15', summary: 'Discussion on elevated LDL and Psyllium Husk dosage.' },
  { id: 's2', title: 'Sleep Quality Review', date: 'Nov 10', summary: 'Correlation between deep sleep and cortisol spikes.' },
  { id: 's3', title: 'Dietary Adjustments', date: 'Oct 28', summary: 'Switching to Pitta-pacifying dinner options.' },
];

export const SUGGESTED_ACTIONS = [
  "Analyze my latest blood work",
  "Why is my energy low in the afternoon?",
  "Suggest a dinner for high Pitta",
  "Explain my disease risk score"
];

export const DAILY_SUPPLEMENTS = [
  { name: 'Ashwagandha KSM-66', dosage: '300mg', time: 'Morning' },
  { name: 'Omega-3 Fish Oil', dosage: '1000mg', time: 'Afternoon' },
  { name: 'Magnesium Glycinate', dosage: '400mg', time: 'Night' },
  { name: 'Triphala', dosage: '500mg', time: 'Night' },
];

// Wearable Devices
export const AVAILABLE_DEVICES = [
  {
    id: 'apple-watch',
    type: 'apple-watch' as const,
    name: 'Apple Watch',
    description: 'Track steps, heart rate, workouts, and sleep',
    color: 'blue',
    features: ['Steps', 'Heart Rate', 'HRV', 'Sleep', 'Calories', 'Workouts']
  },
  {
    id: 'fitbit',
    type: 'fitbit' as const,
    name: 'Fitbit',
    description: 'Steps, heart rate, sleep stages, and active minutes',
    color: 'teal',
    features: ['Steps', 'Heart Rate', 'Sleep Stages', 'Calories', 'SpO2']
  },
  {
    id: 'garmin',
    type: 'garmin' as const,
    name: 'Garmin',
    description: 'Advanced fitness tracking with VO2 Max and training load',
    color: 'blue',
    features: ['Steps', 'VO2 Max', 'Training Load', 'Recovery Time', 'Heart Rate']
  },
  {
    id: 'oura',
    type: 'oura' as const,
    name: 'Oura Ring',
    description: 'Sleep, readiness, and recovery insights',
    color: 'amber',
    features: ['Sleep Score', 'Readiness', 'HRV', 'Temperature', 'Activity']
  },
  {
    id: 'whoop',
    type: 'whoop' as const,
    name: 'WHOOP',
    description: 'Strain, recovery, and sleep performance tracking',
    color: 'yellow',
    features: ['Strain', 'Recovery', 'Sleep Performance', 'HRV', 'Respiratory Rate']
  }
];

// ============ HEALTH VAULT — PANEL TYPE CONFIG ============

export const PANEL_TYPE_CONFIG = [
  {
    key: 'standard_blood' as const,
    label: 'Blood Panel',
    description: 'Standard blood work and biomarkers',
    icon: 'Activity',
    accentColor: '#10B981',
    accentBg: 'bg-emerald-50',
    accentText: 'text-emerald-700',
    accentBorder: 'border-emerald-200',
    route: '/health-data',
  },
  {
    key: 'gut_microbiome' as const,
    label: 'Gut Microbiome',
    description: 'Microbiome composition and diversity',
    icon: 'Bug',
    accentColor: '#8B5CF6',
    accentBg: 'bg-violet-50',
    accentText: 'text-violet-700',
    accentBorder: 'border-violet-200',
    route: '/health-vault/gut-microbiome',
  },
  {
    key: 'genetic' as const,
    label: 'Genetic Panel',
    description: 'DNA variants and gene analysis',
    icon: 'Dna',
    accentColor: '#6366F1',
    accentBg: 'bg-indigo-50',
    accentText: 'text-indigo-700',
    accentBorder: 'border-indigo-200',
    route: '/health-vault/genetic',
  },
  {
    key: 'methylation' as const,
    label: 'Biological Age',
    description: 'Epigenetic clock and aging pace',
    icon: 'FlaskConical',
    accentColor: '#06B6D4',
    accentBg: 'bg-cyan-50',
    accentText: 'text-cyan-700',
    accentBorder: 'border-cyan-200',
    route: '/health-vault/biological-age',
  },
  {
    key: 'heavy_metals' as const,
    label: 'Heavy Metals',
    description: 'Toxic metal exposure levels',
    icon: 'AlertTriangle',
    accentColor: '#F59E0B',
    accentBg: 'bg-amber-50',
    accentText: 'text-amber-700',
    accentBorder: 'border-amber-200',
    route: '/health-vault/heavy-metals',
  },
  {
    key: 'toxicity' as const,
    label: 'Toxicity Panel',
    description: 'Mycotoxins, pesticides and environmental',
    icon: 'ShieldAlert',
    accentColor: '#F43F5E',
    accentBg: 'bg-rose-50',
    accentText: 'text-rose-700',
    accentBorder: 'border-rose-200',
    route: '/health-vault/toxicity',
  },
];

// ============ DEMO DATA — GUT MICROBIOME ============

export const GUT_MICROBIOME_REPORT: LabReport = {
  id: 'gut-1',
  date: '2026-05-20',
  title: 'GI-MAP Comprehensive Stool Analysis',
  summary: 'Microbiome diversity is good. Firmicutes:Bacteroidetes ratio slightly elevated. H. pylori detected.',
  reportType: 'gut_microbiome',
  providerName: 'Diagnostic Solutions — GI-MAP',
  aiInterpretation: 'Your gut microbiome shows good overall diversity (Shannon Index 3.4), but the Firmicutes-to-Bacteroidetes ratio of 1.8:1 is mildly pro-inflammatory. H. pylori was detected at a moderate level, which may explain your occasional digestive discomfort. Akkermansia muciniphila is below optimal range — supplementing with polyphenol-rich foods can help increase this keystone species.',
  panelMetadata: {
    phylumRatios: [
      { name: 'Firmicutes', percentage: 52.3, color: '#8B5CF6' },
      { name: 'Bacteroidetes', percentage: 29.1, color: '#06B6D4' },
      { name: 'Proteobacteria', percentage: 8.2, color: '#F59E0B' },
      { name: 'Actinobacteria', percentage: 6.1, color: '#10B981' },
      { name: 'Verrucomicrobia', percentage: 2.3, color: '#EC4899' },
      { name: 'Other', percentage: 2.0, color: '#94A3B8' },
    ],
    diversityIndices: [
      { name: 'Shannon Index', value: 3.4, status: 'Good' },
      { name: 'Simpson Index', value: 0.89, status: 'Good' },
      { name: 'Firmicutes:Bacteroidetes', value: 1.8, status: 'Elevated' },
    ],
    pathogens: [
      { name: 'H. pylori', detected: true, level: 'Moderate' },
      { name: 'C. difficile', detected: false },
      { name: 'Campylobacter', detected: false },
      { name: 'E. coli (pathogenic)', detected: false },
      { name: 'Candida albicans', detected: true, level: 'Low' },
      { name: 'Giardia lamblia', detected: false },
    ],
  },
  markers: [
    { name: 'Akkermansia muciniphila', value: '1.8%', range: '3.0–8.0%', status: 'Abnormal', insight: 'Key mucin-degrading species — low levels linked to impaired gut lining.', category: 'Beneficial Bacteria' },
    { name: 'Faecalibacterium prausnitzii', value: '8.1%', range: '5.0–15.0%', status: 'Optimal', insight: 'Primary butyrate producer — anti-inflammatory.', category: 'Beneficial Bacteria' },
    { name: 'Bifidobacterium spp.', value: '4.2%', range: '3.0–10.0%', status: 'Optimal', category: 'Beneficial Bacteria' },
    { name: 'Lactobacillus spp.', value: '2.1%', range: '1.0–5.0%', status: 'Optimal', category: 'Beneficial Bacteria' },
    { name: 'Roseburia spp.', value: '3.5%', range: '2.0–8.0%', status: 'Optimal', insight: 'Important short-chain fatty acid producer.', category: 'Beneficial Bacteria' },
    { name: 'Prevotella copri', value: '5.8%', range: '2.0–10.0%', status: 'Normal', category: 'Commensal Bacteria' },
    { name: 'Calprotectin', value: '45 µg/g', range: '<50 µg/g', status: 'Normal', insight: 'Intestinal inflammation marker within normal limits.', category: 'Gut Health Markers' },
    { name: 'Zonulin', value: '88 ng/mL', range: '<50 ng/mL', status: 'Abnormal', insight: 'Elevated — suggests increased intestinal permeability (leaky gut).', category: 'Gut Health Markers' },
    { name: 'sIgA', value: '620 µg/mL', range: '510–2040 µg/mL', status: 'Normal', insight: 'Mucosal immune function within range.', category: 'Gut Health Markers' },
    { name: 'Pancreatic Elastase', value: '350 µg/g', range: '>200 µg/g', status: 'Optimal', insight: 'Good digestive enzyme production.', category: 'Digestive Markers' },
    { name: 'Beta-glucuronidase', value: '1200 U/mL', range: '<2000 U/mL', status: 'Normal', category: 'Digestive Markers' },
    { name: 'Short Chain Fatty Acids (Total)', value: '95 µmol/g', range: '80–120 µmol/g', status: 'Optimal', insight: 'Healthy SCFA production from beneficial bacteria.', category: 'Metabolites' },
  ],
};

// ============ DEMO DATA — GENETIC PANEL ============

export const GENETIC_PANEL_REPORT: LabReport = {
  id: 'gen-1',
  date: '2026-03-10',
  title: 'Comprehensive Genetic Analysis',
  summary: 'Key variants identified in MTHFR (heterozygous), APOE (ε3/ε4), and COMT. Actionable recommendations generated.',
  reportType: 'genetic',
  providerName: 'SelfDecode',
  aiInterpretation: 'Your genetic profile reveals a heterozygous MTHFR C677T variant, meaning your folate metabolism operates at ~65% efficiency. Combined with your COMT intermediate status, we recommend methylated B-vitamins (methylfolate, methylcobalamin) instead of standard forms. Your APOE ε3/ε4 genotype places cardiovascular and cognitive health as priority areas — your LDL and ApoB targets should be more aggressive (<70 mg/dL and <60 mg/dL respectively).',
  panelMetadata: {
    isOneTime: true,
  },
  markers: [
    { name: 'MTHFR C677T', value: 'CT', range: 'CC (wild type)', status: 'Abnormal', genotype: 'CT', riskLevel: 'moderate', insight: 'Heterozygous — ~65% enzyme efficiency. Switch to methylfolate.', category: 'Methylation Genes' },
    { name: 'MTHFR A1298C', value: 'AA', range: 'AA (wild type)', status: 'Optimal', genotype: 'AA', riskLevel: 'low', insight: 'Wild type — normal enzyme activity.', category: 'Methylation Genes' },
    { name: 'COMT Val158Met', value: 'AG', range: 'GG (wild type)', status: 'Normal', genotype: 'AG', riskLevel: 'moderate', insight: 'Intermediate metabolizer — balanced dopamine/estrogen clearance.', category: 'Methylation Genes' },
    { name: 'APOE', value: 'ε3/ε4', range: 'ε3/ε3 (common)', status: 'Abnormal', genotype: 'ε3/ε4', riskLevel: 'high', insight: 'One copy of ε4 allele — elevated cardiovascular and Alzheimer risk. Prioritize ApoB management.', category: 'Cardiovascular Genes' },
    { name: 'VDR Taq', value: 'TT', range: 'CC (wild type)', status: 'Abnormal', genotype: 'TT', riskLevel: 'moderate', insight: 'Homozygous variant — reduced vitamin D receptor sensitivity. May need higher doses.', category: 'Nutrient Metabolism' },
    { name: 'CYP1A2 *1F', value: 'AC', range: 'AA (fast)', status: 'Normal', genotype: 'AC', riskLevel: 'moderate', insight: 'Slow caffeine metabolizer — limit to 1 cup before noon.', category: 'Drug Metabolism' },
    { name: 'FTO rs9939609', value: 'AT', range: 'TT (low risk)', status: 'Normal', genotype: 'AT', riskLevel: 'moderate', insight: 'Heterozygous — moderate obesity susceptibility. Responds well to exercise.', category: 'Metabolic Genes' },
    { name: 'BDNF Val66Met', value: 'GG', range: 'GG (wild type)', status: 'Optimal', genotype: 'GG', riskLevel: 'low', insight: 'Wild type — normal BDNF secretion and neuroplasticity.', category: 'Neurological Genes' },
    { name: 'SOD2 Ala16Val', value: 'CT', range: 'CC (wild type)', status: 'Normal', genotype: 'CT', riskLevel: 'moderate', insight: 'Heterozygous — moderate antioxidant defense. Supplement with CoQ10 + liposomal glutathione.', category: 'Antioxidant Defense' },
    { name: 'TNF-α -308', value: 'GG', range: 'GG (wild type)', status: 'Optimal', genotype: 'GG', riskLevel: 'low', insight: 'Wild type — normal inflammatory response.', category: 'Inflammation Genes' },
    { name: 'GSTM1', value: 'Present', range: 'Present', status: 'Optimal', genotype: 'Present', riskLevel: 'low', insight: 'Gene present — Phase II detox pathway functional.', category: 'Detoxification' },
    { name: 'HLA-DQ2', value: 'Negative', range: 'Negative', status: 'Optimal', genotype: 'Negative', riskLevel: 'low', insight: 'No celiac disease predisposition.', category: 'Immune Genes' },
  ],
};

// ============ DEMO DATA — METHYLATION / BIOLOGICAL AGE ============

export const METHYLATION_REPORT: LabReport = {
  id: 'meth-1',
  date: '2026-06-01',
  title: 'TruAge COMPLETE Epigenetic Report',
  summary: 'Biological age 31.2 vs chronological 34. DunedinPACE 0.85 — aging 15% slower than average.',
  reportType: 'methylation',
  providerName: 'TruDiagnostic',
  aiInterpretation: 'Excellent results. Your biological age of 31.2 compared to chronological age of 34 represents 2.8 years of deceleration. Your DunedinPACE of 0.85 means you are currently aging at 85% of the normal rate — placing you in the top 22% for your age cohort. GrimAge shows the strongest deceleration, likely driven by your exercise and supplement regimen.',
  panelMetadata: {
    biologicalAge: 31.2,
    chronologicalAge: 34,
    ageAcceleration: -2.8,
    paceOfAging: 0.85,
    clockScores: [
      { name: 'Horvath', value: 30.8 },
      { name: 'Hannum', value: 32.1 },
      { name: 'PhenoAge', value: 31.2 },
      { name: 'GrimAge', value: 29.5 },
      { name: 'DunedinPACE', value: 0.85 },
    ],
  },
  markers: [
    { name: 'Biological Age', value: '31.2 years', range: '< 34 years', status: 'Optimal', insight: '2.8 years younger than chronological age.', category: 'Core Metrics' },
    { name: 'DunedinPACE', value: '0.85', range: '<1.0 (slower)', status: 'Optimal', insight: 'Aging at 85% of normal speed. Top 22% for age cohort.', category: 'Core Metrics' },
    { name: 'Horvath Clock', value: '30.8 years', range: '< 34 years', status: 'Optimal', insight: 'First-generation clock — strong deceleration.', category: 'Epigenetic Clocks' },
    { name: 'Hannum Clock', value: '32.1 years', range: '< 34 years', status: 'Optimal', category: 'Epigenetic Clocks' },
    { name: 'PhenoAge', value: '31.2 years', range: '< 34 years', status: 'Optimal', insight: 'Phenotypic age capturing multi-organ aging.', category: 'Epigenetic Clocks' },
    { name: 'GrimAge', value: '29.5 years', range: '< 34 years', status: 'Optimal', insight: 'Strongest deceleration — 4.5 years younger. Mortality-predictive clock.', category: 'Epigenetic Clocks' },
    { name: 'Immune Age', value: '33 years', range: '< 34 years', status: 'Normal', insight: 'Immune system aging is close to chronological age.', category: 'System Ages' },
    { name: 'Metabolic Age', value: '30 years', range: '< 34 years', status: 'Optimal', category: 'System Ages' },
    { name: 'Inflammation Age', value: '32 years', range: '< 34 years', status: 'Optimal', category: 'System Ages' },
    { name: 'Telomere Length', value: '7.2 kb', range: '6.0–8.5 kb', status: 'Normal', insight: '72nd percentile for age group.', category: 'Telomere' },
  ],
};

// ============ DEMO DATA — HEAVY METALS ============

export const HEAVY_METALS_REPORT: LabReport = {
  id: 'metals-1',
  date: '2026-04-15',
  title: 'Heavy Metals Panel — Provoked Urine',
  summary: 'Mercury elevated at 8.2 µg/L (reference <4.0). Lead and arsenic within normal ranges.',
  reportType: 'heavy_metals',
  providerName: "Doctor's Data",
  aiInterpretation: 'Mercury is elevated at 2x the reference limit, likely driven by dietary fish intake (you consume fish 4x/week). Lead, cadmium, and aluminum are all within safe ranges. Given your GSTM1 Present genotype (from genetic panel), your Phase II detox pathway is functional — a targeted chelation support protocol with NAC and modified citrus pectin should be effective.',
  panelMetadata: {
    specimenType: 'provoked_urine',
    provocationAgent: 'DMSA',
  },
  markers: [
    { name: 'Mercury (Hg)', value: '8.2 µg/L', range: '<4.0 µg/L', status: 'Abnormal', insight: 'Elevated. Common source: fish consumption. Reduce to 2x/week, favor low-mercury species.', category: 'Priority Metals' },
    { name: 'Lead (Pb)', value: '1.8 µg/dL', range: '<3.5 µg/dL', status: 'Optimal', category: 'Priority Metals' },
    { name: 'Arsenic (As)', value: '12 µg/L', range: '<15 µg/L', status: 'Normal', insight: 'Within range. Monitor if rice consumption is high.', category: 'Priority Metals' },
    { name: 'Cadmium (Cd)', value: '0.3 µg/L', range: '<0.9 µg/L', status: 'Optimal', category: 'Priority Metals' },
    { name: 'Aluminum (Al)', value: '12 µg/L', range: '<15 µg/L', status: 'Normal', category: 'Secondary Metals' },
    { name: 'Nickel (Ni)', value: '3.2 µg/L', range: '<6.0 µg/L', status: 'Optimal', category: 'Secondary Metals' },
    { name: 'Tin (Sn)', value: '1.5 µg/L', range: '<5.0 µg/L', status: 'Optimal', category: 'Secondary Metals' },
    { name: 'Barium (Ba)', value: '2.8 µg/L', range: '<7.0 µg/L', status: 'Optimal', category: 'Secondary Metals' },
    { name: 'Thallium (Tl)', value: '0.1 µg/L', range: '<0.5 µg/L', status: 'Optimal', category: 'Trace Metals' },
    { name: 'Uranium (U)', value: '0.02 µg/L', range: '<0.1 µg/L', status: 'Optimal', category: 'Trace Metals' },
  ],
};

// ============ DEMO DATA — TOXICITY PANEL ============

export const TOXICITY_REPORT: LabReport = {
  id: 'tox-1',
  date: '2026-02-28',
  title: 'GPL-TOX — Toxic Non-Metal Chemical Profile',
  summary: 'Ochratoxin A elevated at 3x threshold. Glyphosate detected above reference. Other mycotoxins clear.',
  reportType: 'toxicity',
  providerName: 'Great Plains Laboratory',
  aiInterpretation: 'Two toxins of concern were identified. Ochratoxin A is elevated at 3x the threshold — common sources include water-damaged buildings, coffee, and wine. Glyphosate was detected at 2.4x the reference, likely from dietary exposure. Your protocol has been updated with activated charcoal binder (away from meals), NAC for glutathione support, and increased cruciferous vegetable intake.',
  panelMetadata: {
    toxinCategory: 'mixed',
    toxinLoadScore: 62,
  },
  markers: [
    { name: 'Ochratoxin A', value: '12.3 ppb', range: '<4.0 ppb', status: 'Abnormal', detected: true, insight: 'Elevated — 3x threshold. Sources: water-damaged buildings, coffee, wine, grains.', category: 'Mycotoxins' },
    { name: 'Aflatoxin M1', value: '0.8 ppb', range: '<2.0 ppb', status: 'Normal', detected: false, category: 'Mycotoxins' },
    { name: 'Gliotoxin', value: '<0.1 ppb', range: '<0.5 ppb', status: 'Optimal', detected: false, category: 'Mycotoxins' },
    { name: 'Trichothecenes', value: '<0.2 ppb', range: '<0.5 ppb', status: 'Optimal', detected: false, category: 'Mycotoxins' },
    { name: 'Zearalenone', value: '1.2 ppb', range: '<2.0 ppb', status: 'Normal', detected: false, category: 'Mycotoxins' },
    { name: 'Glyphosate', value: '1.2 µg/L', range: '<0.5 µg/L', status: 'Abnormal', detected: true, insight: 'Detected above reference. Likely dietary — switch to organic produce for key items.', category: 'Pesticides' },
    { name: 'Organophosphates', value: '<0.1 µg/L', range: '<0.5 µg/L', status: 'Optimal', detected: false, category: 'Pesticides' },
    { name: '2,4-D', value: '<0.1 µg/L', range: '<0.5 µg/L', status: 'Optimal', detected: false, category: 'Pesticides' },
    { name: 'BPA (Bisphenol A)', value: '1.8 µg/L', range: '<2.0 µg/L', status: 'Normal', detected: true, insight: 'Near threshold. Reduce plastic food container usage.', category: 'Plasticizers' },
    { name: 'Phthalates (DEHP)', value: '15 µg/L', range: '<20 µg/L', status: 'Normal', detected: true, category: 'Plasticizers' },
  ],
};
