// APP-05: one test per unit-conversion factor (the brief's table), through
// the same normalizeResult() the Edge Function uses. Each checks the
// canonical value, the unit, and that the original value, original unit and
// the factor used are kept. Fictional values only.
import { describe, expect, it } from 'vitest';
import { LAB_CATALOG } from '../../supabase/functions/_shared/labCatalog.ts';
import {
  buildAliasIndex,
  convertToCanonical,
  normalizeResult,
  type AnalyteMapRow,
} from '../../supabase/functions/_shared/labNormalize.ts';

const MAP: AnalyteMapRow[] = LAB_CATALOG.map((a) => ({ analyte_key: a.key, loinc: a.loinc, aliases: [a.label] }));
const ALIASES = buildAliasIndex(MAP);
const SURE = { analyte: 1, value: 1, unit: 1, reference_range: 1 };

function norm(key: string, value: string, unit: string) {
  const a = LAB_CATALOG.find((x) => x.key === key)!;
  return normalizeResult({ analyte: a.label, value, unit, confidence: SURE }, ALIASES);
}

function expectConverted(
  key: string,
  reported: [string, string],
  canonical: [number, string],
  kind: string,
  factor: number,
) {
  const r = norm(key, reported[0], reported[1]);
  expect(r.analyte_key).toBe(key);
  expect(r.value).toBeCloseTo(canonical[0], 6);
  expect(r.unit).toBe(canonical[1]);
  expect(r.reported_value).toBe(reported[0]);
  expect(r.reported_unit).toBe(reported[1]);
  expect(r.conversion_kind).toBe(kind);
  expect(r.conversion_factor).toBe(factor);
  expect(r.review_reasons).toEqual([]);
}

describe('APP-05 unit conversions (one per factor)', () => {
  it('HbA1c: % = mmol/mol / 10.929 + 2.15', () => {
    // 44 mmol/mol -> 6.176 -> 6.2 %
    expectConverted('hba1c', ['44', 'mmol/mol'], [6.2, '%'], 'hba1c', 10.929);
    const raw = convertToCanonical(LAB_CATALOG.find((a) => a.key === 'hba1c')!, 44, 'mmol/mol')!;
    expect(raw.value).toBeCloseTo(44 / 10.929 + 2.15, 10);
  });

  it('Glucose: mmol/L x 18.016', () => {
    expectConverted('glucose_fasting', ['5.5', 'mmol/L'], [99, 'mg/dL'], 'multiply', 18.016);
  });

  it('Insulin: pmol/L / 6.0', () => {
    expectConverted('insulin_fasting', ['108.6', 'pmol/L'], [18.1, 'uIU/mL'], 'divide', 6.0);
  });

  it.each([
    ['cholesterol_total', '5.17', 200],
    ['ldl_c_calc', '2.59', 100],
    ['ldl_c_direct', '2.59', 100],
    ['hdl_c', '1.29', 50],
    ['non_hdl_c', '3.88', 150],
  ])('Cholesterol (%s): mmol/L x 38.67', (key, mmol, mgdl) => {
    expectConverted(key, [mmol, 'mmol/L'], [mgdl, 'mg/dL'], 'multiply', 38.67);
  });

  it('Triglycerides: mmol/L x 88.57', () => {
    expectConverted('triglycerides', ['1.37', 'mmol/L'], [121, 'mg/dL'], 'multiply', 88.57);
  });

  it('ApoB: g/L x 100', () => {
    expectConverted('apob', ['1.06', 'g/L'], [106, 'mg/dL'], 'multiply', 100);
  });

  it('Lp(a): never converted - mg/dL and nmol/L stored as reported, molar result keeps its own LOINC', () => {
    const mass = norm('lpa', '32', 'mg/dL');
    expect([mass.value, mass.unit, mass.conversion_kind, mass.conversion_factor, mass.loinc]).toEqual([32, 'mg/dL', 'none', 1, '10835-7']);
    const molar = norm('lpa', '75', 'nmol/L');
    expect([molar.value, molar.unit, molar.conversion_kind, molar.conversion_factor, molar.loinc]).toEqual([75, 'nmol/L', 'none', 1, '43583-4']);
    // Anything else (e.g. g/L) is not guessed.
    const other = norm('lpa', '0.3', 'g/L');
    expect(other.value).toBe(0.3);
    expect(other.unit).toBe('g/L');
    expect(other.review_reasons).toContain('unit_not_convertible');
    expect(other.status).toBe('needs_review');
  });

  it('hsCRP: mg/dL x 10', () => {
    expectConverted('hscrp', ['0.38', 'mg/dL'], [3.8, 'mg/L'], 'multiply', 10);
  });

  it.each(['alt', 'ast', 'ggt'])('%s: µkat/L x 60', (key) => {
    expectConverted(key, ['0.5', 'µkat/L'], [30, 'U/L'], 'multiply', 60);
    // ukat/L and the Greek-mu spelling are the same unit.
    expect(norm(key, '0.5', 'ukat/L').value).toBe(30);
    expect(norm(key, '0.5', 'μkat/L').value).toBe(30);
  });

  it('Creatinine: µmol/L / 88.42', () => {
    expectConverted('creatinine', ['79.6', 'µmol/L'], [0.9, 'mg/dL'], 'divide', 88.42);
    expect(norm('creatinine', '79.6', 'umol/L').value).toBe(0.9);
  });

  it('Vitamin D: nmol/L / 2.496', () => {
    expectConverted('vitamin_d', ['87.4', 'nmol/L'], [35, 'ng/mL'], 'divide', 2.496);
  });

  it('Ferritin: 1:1 (µg/L = ng/mL)', () => {
    expectConverted('ferritin', ['120', 'µg/L'], [120, 'ng/mL'], 'none', 1);
    expectConverted('ferritin', ['120', 'mcg/L'], [120, 'ng/mL'], 'none', 1);
  });

  it('Testosterone: nmol/L x 28.84', () => {
    expectConverted('testosterone', ['17.3', 'nmol/L'], [499, 'ng/dL'], 'multiply', 28.84);
  });

  it('Estradiol: pmol/L / 3.671', () => {
    expectConverted('estradiol', ['110', 'pmol/L'], [30, 'pg/mL'], 'divide', 3.671);
  });

  it('FT4: pmol/L / 12.87', () => {
    expectConverted('ft4', ['16', 'pmol/L'], [1.24, 'ng/dL'], 'divide', 12.87);
  });

  it('FT3: pmol/L / 1.536', () => {
    expectConverted('ft3', ['4.6', 'pmol/L'], [3.0, 'pg/mL'], 'divide', 1.536);
  });

  it('IGF-1: nmol/L x 7.649', () => {
    expectConverted('igf1', ['20', 'nmol/L'], [153, 'ng/mL'], 'multiply', 7.649);
  });

  it('a value already in the canonical unit is stored as is (factor 1, no rounding)', () => {
    expectConverted('hba1c', ['6.23', '%'], [6.23, '%'], 'none', 1);
    expectConverted('insulin_fasting', ['9.4', 'µIU/mL'], [9.4, 'uIU/mL'], 'none', 1);
    expectConverted('tsh', ['2.1', 'uIU/mL'], [2.1, 'mIU/L'], 'none', 1);
  });

  it('every conversion in the catalog is covered by a test above', () => {
    const covered = new Set([
      'hba1c:mmol/mol', 'glucose_fasting:mmol/L', 'insulin_fasting:pmol/L', 'cholesterol_total:mmol/L',
      'ldl_c_calc:mmol/L', 'ldl_c_direct:mmol/L', 'hdl_c:mmol/L', 'non_hdl_c:mmol/L', 'triglycerides:mmol/L',
      'apob:g/L', 'hscrp:mg/dL', 'alt:µkat/L', 'ast:µkat/L', 'ggt:µkat/L', 'creatinine:µmol/L',
      'vitamin_d:nmol/L', 'testosterone:nmol/L', 'estradiol:pmol/L', 'ft4:pmol/L', 'ft3:pmol/L', 'igf1:nmol/L',
    ]);
    const inCatalog = LAB_CATALOG.flatMap((a) => a.conversions.map((c) => `${a.key}:${c.from}`));
    expect(new Set(inCatalog)).toEqual(covered);
  });
});
