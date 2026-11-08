// APP-05: the analytes the lab pipeline understands - US canonical unit, the
// unit conversions it may apply, and physiological plausibility limits.
//
// Pure data, no Deno/npm imports, so the root vitest suite
// (tests/lab-pipeline/*) can import it as well as the Edge Function.
//
// The analyte -> LOINC mapping itself is NOT decided here: it lives in the
// reviewed table public.lab_analyte_loinc (migration
// 20261105130000_app05_lab_pipeline.sql), which the function reads at run
// time. tests/lab-pipeline/catalog-drift.test.ts fails if the two drift
// (every key and LOINC here must be in the migration's seed and vice versa).
//
// Conversions (APP-05 table). `kind`:
//   multiply  canonical = reported * factor
//   divide    canonical = reported / factor
//   hba1c     canonical % = reported mmol/mol / 10.929 + 2.15 (IFCC -> NGSP)
// A unit that is the canonical unit, or listed in `sameAs`, is stored as is
// (factor 1). Any other unit is NOT guessed: the value is stored as reported
// and marked needs_review (unit_not_convertible).
//
// Plausibility limits are deliberately wide - they catch extraction errors
// (a decimal point lost, a value read from the wrong column, a unit mix-up),
// not abnormal results. A value outside them is stored but marked
// needs_review (implausible_value), never dropped and never "corrected".

export type ConversionKind = 'multiply' | 'divide' | 'hba1c'

export interface UnitConversion {
  from: string
  kind: ConversionKind
  factor: number
}

export interface CatalogAnalyte {
  key: string
  label: string
  loinc: string
  canonicalUnit: string
  /** Units that mean the same thing as the canonical unit (factor 1). */
  sameAs: string[]
  conversions: UnitConversion[]
  /** Never convert (Lp(a): mass and molar results are different measures). */
  neverConvert?: boolean
  /** LOINC when the result is reported in another unit family (Lp(a) nmol/L). */
  loincByUnit?: Record<string, string>
  /** Plausible range for the canonical value (inclusive). */
  plausible: { min: number; max: number }
  /** Decimal places a converted canonical value is rounded to. */
  decimals: number
}

const CHOLESTEROL_FACTOR = 38.67

function lipid(key: string, label: string, loinc: string, min: number, max: number): CatalogAnalyte {
  return {
    key,
    label,
    loinc,
    canonicalUnit: 'mg/dL',
    sameAs: [],
    conversions: [{ from: 'mmol/L', kind: 'multiply', factor: CHOLESTEROL_FACTOR }],
    plausible: { min, max },
    decimals: 0,
  }
}

function enzyme(key: string, label: string, loinc: string): CatalogAnalyte {
  return {
    key,
    label,
    loinc,
    canonicalUnit: 'U/L',
    sameAs: ['IU/L'],
    conversions: [{ from: 'µkat/L', kind: 'multiply', factor: 60 }],
    plausible: { min: 1, max: 10000 },
    decimals: 0,
  }
}

export const LAB_CATALOG: readonly CatalogAnalyte[] = [
  {
    key: 'hba1c', label: 'HbA1c', loinc: '4548-4', canonicalUnit: '%', sameAs: [],
    conversions: [{ from: 'mmol/mol', kind: 'hba1c', factor: 10.929 }],
    plausible: { min: 3, max: 20 }, decimals: 1,
  },
  {
    key: 'glucose_fasting', label: 'Fasting glucose', loinc: '1558-6', canonicalUnit: 'mg/dL', sameAs: [],
    conversions: [{ from: 'mmol/L', kind: 'multiply', factor: 18.016 }],
    plausible: { min: 20, max: 1500 }, decimals: 0,
  },
  {
    key: 'insulin_fasting', label: 'Fasting insulin', loinc: '20448-7', canonicalUnit: 'uIU/mL', sameAs: ['mIU/L', 'mU/L', 'uU/mL'],
    conversions: [{ from: 'pmol/L', kind: 'divide', factor: 6.0 }],
    plausible: { min: 0.1, max: 1000 }, decimals: 1,
  },
  {
    key: 'triglycerides', label: 'Triglycerides', loinc: '2571-8', canonicalUnit: 'mg/dL', sameAs: [],
    conversions: [{ from: 'mmol/L', kind: 'multiply', factor: 88.57 }],
    plausible: { min: 5, max: 10000 }, decimals: 0,
  },
  lipid('cholesterol_total', 'Total cholesterol', '2093-3', 30, 1500),
  lipid('ldl_c_calc', 'LDL cholesterol (calculated)', '13457-7', 1, 1000),
  lipid('ldl_c_direct', 'LDL cholesterol (direct)', '18262-6', 1, 1000),
  lipid('hdl_c', 'HDL cholesterol', '2085-9', 1, 250),
  lipid('non_hdl_c', 'Non-HDL cholesterol', '43396-1', 1, 1200),
  {
    key: 'apob', label: 'ApoB', loinc: '1884-6', canonicalUnit: 'mg/dL', sameAs: [],
    conversions: [{ from: 'g/L', kind: 'multiply', factor: 100 }],
    plausible: { min: 5, max: 500 }, decimals: 0,
  },
  {
    // Lp(a) is never converted: mg/dL (mass) and nmol/L (particle number)
    // are different measures with no fixed factor. Both are stored as
    // reported; the molar result carries its own LOINC.
    key: 'lpa', label: 'Lp(a)', loinc: '10835-7', canonicalUnit: 'mg/dL', sameAs: [],
    conversions: [], neverConvert: true, loincByUnit: { 'nmol/L': '43583-4' },
    plausible: { min: 0, max: 1000 }, decimals: 0,
  },
  {
    key: 'hscrp', label: 'hsCRP', loinc: '30522-7', canonicalUnit: 'mg/L', sameAs: [],
    conversions: [{ from: 'mg/dL', kind: 'multiply', factor: 10 }],
    plausible: { min: 0, max: 500 }, decimals: 2,
  },
  enzyme('alt', 'ALT', '1742-6'),
  enzyme('ast', 'AST', '1920-8'),
  enzyme('ggt', 'GGT', '2324-2'),
  {
    key: 'creatinine', label: 'Creatinine', loinc: '2160-0', canonicalUnit: 'mg/dL', sameAs: [],
    conversions: [{ from: 'µmol/L', kind: 'divide', factor: 88.42 }],
    plausible: { min: 0.05, max: 30 }, decimals: 2,
  },
  {
    key: 'egfr', label: 'eGFR', loinc: '98979-8', canonicalUnit: 'mL/min/1.73m2', sameAs: [],
    conversions: [],
    plausible: { min: 1, max: 250 }, decimals: 0,
  },
  {
    key: 'tsh', label: 'TSH', loinc: '3016-3', canonicalUnit: 'mIU/L', sameAs: ['uIU/mL'],
    conversions: [],
    plausible: { min: 0.001, max: 500 }, decimals: 2,
  },
  {
    key: 'ft4', label: 'Free T4', loinc: '3024-7', canonicalUnit: 'ng/dL', sameAs: [],
    conversions: [{ from: 'pmol/L', kind: 'divide', factor: 12.87 }],
    plausible: { min: 0.05, max: 15 }, decimals: 2,
  },
  {
    key: 'ft3', label: 'Free T3', loinc: '3051-0', canonicalUnit: 'pg/mL', sameAs: [],
    conversions: [{ from: 'pmol/L', kind: 'divide', factor: 1.536 }],
    plausible: { min: 0.3, max: 40 }, decimals: 1,
  },
  {
    key: 'testosterone', label: 'Testosterone', loinc: '2986-8', canonicalUnit: 'ng/dL', sameAs: [],
    conversions: [{ from: 'nmol/L', kind: 'multiply', factor: 28.84 }],
    plausible: { min: 0.5, max: 5000 }, decimals: 0,
  },
  {
    key: 'estradiol', label: 'Estradiol', loinc: '2243-4', canonicalUnit: 'pg/mL', sameAs: [],
    conversions: [{ from: 'pmol/L', kind: 'divide', factor: 3.671 }],
    plausible: { min: 0.5, max: 20000 }, decimals: 0,
  },
  {
    key: 'shbg', label: 'SHBG', loinc: '13967-5', canonicalUnit: 'nmol/L', sameAs: [],
    conversions: [],
    plausible: { min: 1, max: 500 }, decimals: 0,
  },
  {
    key: 'vitamin_d', label: 'Vitamin D (25-OH)', loinc: '62292-8', canonicalUnit: 'ng/mL', sameAs: [],
    conversions: [{ from: 'nmol/L', kind: 'divide', factor: 2.496 }],
    plausible: { min: 1, max: 300 }, decimals: 0,
  },
  {
    key: 'ferritin', label: 'Ferritin', loinc: '2276-4', canonicalUnit: 'ng/mL', sameAs: ['µg/L'],
    conversions: [],
    plausible: { min: 0.5, max: 100000 }, decimals: 0,
  },
  {
    key: 'igf1', label: 'IGF-1', loinc: '2484-4', canonicalUnit: 'ng/mL', sameAs: [],
    conversions: [{ from: 'nmol/L', kind: 'multiply', factor: 7.649 }],
    plausible: { min: 5, max: 2000 }, decimals: 0,
  },
]

const BY_KEY = new Map(LAB_CATALOG.map((a) => [a.key, a]))

export function catalogAnalyte(key: string): CatalogAnalyte | undefined {
  return BY_KEY.get(key)
}
