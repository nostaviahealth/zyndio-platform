// APP-05: mapping, plausibility, confidence, printed ranges and the identity
// check in labNormalize.ts. Fictional names and values only.
import { describe, expect, it } from 'vitest';
import { LAB_CATALOG } from '../../supabase/functions/_shared/labCatalog.ts';
import {
  buildAliasIndex,
  checkIdentity,
  namesMatch,
  normalizeExtraction,
  normalizeResult,
  parsePrintedDate,
  parseReferenceRange,
  parseReportedValue,
  type AnalyteMapRow,
} from '../../supabase/functions/_shared/labNormalize.ts';
import { reviewedAnalyteMap } from './reviewedMap.ts';

const MAP: AnalyteMapRow[] = reviewedAnalyteMap();
const ALIASES = buildAliasIndex(MAP);
const SURE = { analyte: 0.99, value: 0.99, unit: 0.99, reference_range: 0.99 };
const ACCOUNT = { name: 'Jordan Rivera', dob: '1979-03-14' };
const SURE_REPORT = { patient_name: 0.99, patient_dob: 0.99, collection_date: 0.99, lab_name: 0.99 };

describe('mapping through the reviewed table', () => {
  it('maps printed names case/punctuation-insensitively to the reviewed LOINC', () => {
    for (const [printed, key, loinc] of [
      ['HEMOGLOBIN A1C', 'hba1c', '4548-4'],
      ['Insulin, Fasting', 'insulin_fasting', '20448-7'],
      ['Apolipoprotein B', 'apob', '1884-6'],
      ['hs-CRP', 'hscrp', '30522-7'],
      ['LDL-C (calculated)', 'ldl_c_calc', '13457-7'],
      ['LDL Cholesterol, Direct', 'ldl_c_direct', '18262-6'],
      ['ALT (SGPT)', 'alt', '1742-6'],
      ['Vitamin D, 25-Hydroxy', 'vitamin_d', '62292-8'],
    ]) {
      const r = normalizeResult({ analyte: printed, value: '1', unit: LAB_CATALOG.find((a) => a.key === key)!.canonicalUnit, confidence: SURE }, ALIASES);
      expect([printed, r.analyte_key, r.loinc, r.is_unmapped]).toEqual([printed, key, loinc, false]);
    }
  });

  it('an unknown analyte is stored unmapped, as reported, with no LOINC and no conversion', () => {
    const r = normalizeResult({ analyte: 'Lp-PLA2 Activity', value: '180', unit: 'nmol/min/mL', reference_range: '<225', confidence: SURE }, ALIASES);
    expect(r.is_unmapped).toBe(true);
    expect(r.analyte_key).toBe('unmapped:lp_pla2_activity');
    expect(r.loinc).toBeNull();
    expect(r.value).toBe(180);
    expect(r.unit).toBe('nmol/min/mL');
    expect(r.conversion_kind).toBeNull();
    expect(r.conversion_factor).toBeNull();
    expect(r.range_high).toBe(225);
    expect(r.status).toBe('within_range');
  });

  it('ambiguous names are not guessed: plain "LDL Cholesterol" and plain "Glucose" stay unmapped', () => {
    expect(normalizeResult({ analyte: 'LDL Cholesterol', value: '100', unit: 'mg/dL', confidence: SURE }, ALIASES).is_unmapped).toBe(true);
    expect(normalizeResult({ analyte: 'Glucose', value: '99', unit: 'mg/dL', confidence: SURE }, ALIASES).is_unmapped).toBe(true);
  });
});

describe('printed reference ranges', () => {
  it('parses the common shapes', () => {
    expect(parseReferenceRange('4.0-5.6')).toEqual({ low: 4, high: 5.6 });
    expect(parseReferenceRange('4.0 – 5.6')).toEqual({ low: 4, high: 5.6 });
    expect(parseReferenceRange('70 to 99')).toEqual({ low: 70, high: 99 });
    expect(parseReferenceRange('<5.7')).toEqual({ low: null, high: 5.7 });
    expect(parseReferenceRange('≥ 40')).toEqual({ low: 40, high: null });
    expect(parseReferenceRange('see note')).toBeNull();
  });

  it('keeps the printed text and converts the bounds to canonical units', () => {
    const r = normalizeResult({ analyte: 'Glucose, fasting', value: '5.5', unit: 'mmol/L', reference_range: '3.9-5.5', confidence: SURE }, ALIASES);
    expect(r.reference_range_text).toBe('3.9-5.5');
    expect(r.range_low).toBeCloseTo(70.3, 1);
    expect(r.range_high).toBeCloseTo(99.1, 1);
    expect(r.status).toBe('within_range');
  });

  it('outside the printed range is outside_range; no range is no_range; an unreadable range needs review', () => {
    expect(normalizeResult({ analyte: 'HbA1c', value: '6.2', unit: '%', reference_range: '<5.7', confidence: SURE }, ALIASES).status).toBe('outside_range');
    expect(normalizeResult({ analyte: 'ApoB', value: '84', unit: 'mg/dL', confidence: SURE }, ALIASES).status).toBe('no_range');
    const odd = normalizeResult({ analyte: 'ApoB', value: '84', unit: 'mg/dL', reference_range: 'see comment', confidence: SURE }, ALIASES);
    expect(odd.status).toBe('needs_review');
    expect(odd.review_reasons).toContain('range_not_parsed');
  });
});

describe('values', () => {
  it('reads plain, bounded, flagged and decimal-comma values', () => {
    expect(parseReportedValue('5.5')).toEqual({ value: 5.5, comparator: null, ambiguous: false });
    expect(parseReportedValue('6.2 H')).toEqual({ value: 6.2, comparator: null, ambiguous: false });
    expect(parseReportedValue('<0.3')).toEqual({ value: 0.3, comparator: '<', ambiguous: false });
    expect(parseReportedValue('≥ 90')).toEqual({ value: 90, comparator: '>=', ambiguous: false });
    expect(parseReportedValue('5,5')).toEqual({ value: 5.5, comparator: null, ambiguous: false });
    expect(parseReportedValue('1,234')).toEqual({ value: 1234, comparator: null, ambiguous: true });
    expect(parseReportedValue('positive')).toBeNull();
  });

  it('a non-numeric, bounded or ambiguous value needs review and is kept as printed', () => {
    const text = normalizeResult({ analyte: 'HbA1c', value: 'see note', unit: '%', confidence: SURE }, ALIASES);
    expect([text.value, text.reported_value, text.status]).toEqual([null, 'see note', 'needs_review']);
    expect(text.review_reasons).toContain('value_not_numeric');
    const bound = normalizeResult({ analyte: 'hsCRP', value: '<0.2', unit: 'mg/L', confidence: SURE }, ALIASES);
    expect([bound.value, bound.value_comparator, bound.status]).toEqual([0.2, '<', 'needs_review']);
  });
});

describe('plausibility limits', () => {
  it('a physiologically implausible value is kept but needs review', () => {
    // A lost decimal point: HbA1c 55 %.
    const r = normalizeResult({ analyte: 'HbA1c', value: '55', unit: '%', confidence: SURE }, ALIASES);
    expect(r.value).toBe(55);
    expect(r.status).toBe('needs_review');
    expect(r.review_reasons).toEqual(['implausible_value']);
  });

  it('limits apply after conversion (glucose 5.5 mg/dL read as if mmol/L is implausible)', () => {
    expect(normalizeResult({ analyte: 'Glucose, fasting', value: '5.5', unit: 'mg/dL', confidence: SURE }, ALIASES).review_reasons).toContain('implausible_value');
    expect(normalizeResult({ analyte: 'Glucose, fasting', value: '5.5', unit: 'mmol/L', confidence: SURE }, ALIASES).review_reasons).toEqual([]);
  });

  it('every catalog analyte has sane limits that contain a typical value', () => {
    for (const a of LAB_CATALOG) {
      expect(a.plausible.min, a.key).toBeLessThan(a.plausible.max);
      expect(a.plausible.min, a.key).toBeGreaterThanOrEqual(0);
    }
  });
});

describe('confidence', () => {
  it('every field gets a score; any field below the threshold marks the result needs review', () => {
    const r = normalizeResult({ analyte: 'hsCRP', value: '1.7', unit: 'mg/L', reference_range: '<3.0', confidence: { analyte: 0.98, value: 0.6, unit: 0.97, reference_range: 0.95 } }, ALIASES);
    expect(r.field_confidence).toEqual({ analyte: 0.98, value: 0.6, unit: 0.97, reference_range: 0.95 });
    expect(r.confidence).toBe(0.6);
    expect(r.status).toBe('needs_review');
    expect(r.review_reasons).toEqual(['low_confidence:value']);
  });

  it('a field the extractor did not score counts as 0', () => {
    const r = normalizeResult({ analyte: 'ApoB', value: '84', unit: 'mg/dL', confidence: { analyte: 0.99, value: 0.99 } }, ALIASES);
    expect(r.field_confidence.unit).toBe(0);
    expect(r.review_reasons).toEqual(['low_confidence:unit']);
  });

  it('the threshold is configurable', () => {
    const conf = { analyte: 0.9, value: 0.9, unit: 0.9 };
    expect(normalizeResult({ analyte: 'ApoB', value: '84', unit: 'mg/dL', confidence: conf }, ALIASES, 0.85).status).toBe('no_range');
    expect(normalizeResult({ analyte: 'ApoB', value: '84', unit: 'mg/dL', confidence: conf }, ALIASES, 0.95).status).toBe('needs_review');
  });

  it('a missing unit on a mapped analyte needs review (never assumed)', () => {
    const r = normalizeResult({ analyte: 'ApoB', value: '84', confidence: { analyte: 1, value: 1 } }, ALIASES);
    expect(r.unit).toBeNull();
    expect(r.review_reasons).toEqual(['unit_missing']);
  });
});

describe('dates', () => {
  it('reads ISO, US slash dates (month first) and unambiguous day-first dates, refuses guesses', () => {
    expect(parsePrintedDate('2026-10-14')).toBe('2026-10-14');
    expect(parsePrintedDate('10/14/2026')).toBe('2026-10-14');
    expect(parsePrintedDate('04/02/2026')).toBe('2026-04-02');
    expect(parsePrintedDate('14/10/2026')).toBe('2026-10-14');
    expect(parsePrintedDate('14.10.2026')).toBe('2026-10-14');
    expect(parsePrintedDate('03/03/1979')).toBe('1979-03-03');
    expect(parsePrintedDate('03.04.1979')).toBeNull();
    expect(parsePrintedDate('03/04-1979')).toBeNull();
    expect(parsePrintedDate('2026-02-30')).toBeNull();
    expect(parsePrintedDate('Oct 14')).toBeNull();
  });
});

describe('identity check', () => {
  it('names match regardless of order, case, accents, middle names and a first initial', () => {
    expect(namesMatch('RIVERA, JORDAN', 'Jordan Rivera')).toBe(true);
    expect(namesMatch('Jordan A. Rivera', 'Jordan Rivera')).toBe(true);
    expect(namesMatch('J RIVERA', 'Jordan Rivera')).toBe(true);
    expect(namesMatch('Jordán Rivera', 'Jordan Rivera')).toBe(true);
    expect(namesMatch('Sam Okafor', 'Jordan Rivera')).toBe(false);
    expect(namesMatch('Jordan Okafor', 'Jordan Rivera')).toBe(false);
    expect(namesMatch('Rivera', 'Jordan Rivera')).toBe(false);
  });

  it('matching name and DOB: no hold', () => {
    const c = checkIdentity({ name: 'RIVERA, JORDAN', dob: '03/14/1979', confidence: SURE_REPORT }, ACCOUNT);
    expect(c).toEqual({ hold: false, name: 'match', dob: 'match', reasons: [] });
  });

  it('a different name, or a different DOB, holds the report', () => {
    expect(checkIdentity({ name: 'Sam Okafor', dob: '1979-03-14', confidence: SURE_REPORT }, ACCOUNT)).toMatchObject({ hold: true, reasons: ['name_mismatch'] });
    expect(checkIdentity({ name: 'Jordan Rivera', dob: '1980-03-14', confidence: SURE_REPORT }, ACCOUNT)).toMatchObject({ hold: true, reasons: ['dob_mismatch'] });
  });

  it('an identity field read with low confidence holds the report', () => {
    expect(checkIdentity({ name: 'Jordan Rivera', dob: '1979-03-14', confidence: { ...SURE_REPORT, patient_dob: 0.4 } }, ACCOUNT)).toMatchObject({ hold: true, dob: 'unreadable' });
  });

  it('a report that prints neither name nor DOB holds (nothing ties it to the patient)', () => {
    expect(checkIdentity({ confidence: SURE_REPORT }, ACCOUNT)).toMatchObject({ hold: true, reasons: ['nothing_to_compare'] });
  });

  it('only one field printed and it matches: no hold; account without a DOB is compared on name alone', () => {
    expect(checkIdentity({ name: 'Jordan Rivera', confidence: SURE_REPORT }, ACCOUNT).hold).toBe(false);
    expect(checkIdentity({ name: 'Jordan Rivera', dob: '1979-03-14', confidence: SURE_REPORT }, { name: 'Jordan Rivera', dob: null })).toMatchObject({ hold: false, dob: 'account_missing' });
  });
});

describe('a whole report', () => {
  it('a mismatched identity makes the report identity_hold regardless of the results', () => {
    const r = normalizeExtraction(
      { patient_name: 'Sam Okafor', patient_dob: '1979-03-14', collection_date: '2026-10-14', lab_name: 'Fictional Reference Lab', confidence: SURE_REPORT, results: [{ analyte: 'HbA1c', value: '5.5', unit: '%', confidence: SURE }] },
      MAP, ACCOUNT, { today: '2026-11-04' },
    );
    expect(r.status).toBe('identity_hold');
    expect(r.identity.hold).toBe(true);
  });

  it('a future or missing collection date needs review', () => {
    const future = normalizeExtraction({ patient_name: 'Jordan Rivera', collection_date: '2027-01-01', confidence: SURE_REPORT, results: [{ analyte: 'HbA1c', value: '5.5', unit: '%', confidence: SURE }] }, MAP, ACCOUNT, { today: '2026-11-04' });
    expect(future.status).toBe('needs_review');
    expect(future.collected_on).toBeNull();
    expect(future.report_reasons).toContain('collection_date_implausible');
    const missing = normalizeExtraction({ patient_name: 'Jordan Rivera', confidence: SURE_REPORT, results: [{ analyte: 'HbA1c', value: '5.5', unit: '%', confidence: SURE }] }, MAP, ACCOUNT, { today: '2026-11-04' });
    expect(missing.report_reasons).toContain('collection_date_missing');
  });

  it('a report with no results needs review', () => {
    const r = normalizeExtraction({ patient_name: 'Jordan Rivera', collection_date: '2026-10-14', confidence: SURE_REPORT, results: [] }, MAP, ACCOUNT, { today: '2026-11-04' });
    expect(r.status).toBe('needs_review');
    expect(r.report_reasons).toEqual(['no_results']);
  });
});
