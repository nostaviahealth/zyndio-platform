// APP-05 golden fixtures (tests/fixtures/labs, FICTIONAL): what a correct
// extractor reads off each report normalises to the expected canonical US
// values, and the SI-unit version of each report gives IDENTICAL values to
// the US version. Also: every fixture file is distinct by SHA-256 (the dedupe
// key), and the PDF / image files exist and are what they claim to be.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { normalizeExtraction, type RawExtraction } from '../../supabase/functions/_shared/labNormalize.ts';
import { reviewedAnalyteMap } from './reviewedMap.ts';

const DIR = fileURLToPath(new URL('../fixtures/labs/', import.meta.url));
const golden = JSON.parse(readFileSync(`${DIR}golden.json`, 'utf8')) as {
  account: { name: string; dob: string };
  reports: { files: string[]; collected_on: string; units: 'us' | 'si'; extraction: RawExtraction; expected: Record<string, number> }[];
};
const MAP = reviewedAnalyteMap();

function run(extraction: RawExtraction) {
  return normalizeExtraction(extraction, MAP, golden.account, { today: '2026-11-04' });
}

describe('APP-05 golden lab fixtures', () => {
  it('covers the brief: HbA1c 6.2 -> 5.5 %, insulin 18.1 -> 9.4, ApoB 106 -> 84, hsCRP 3.8 -> 1.7, US and SI, PDF and image', () => {
    const us = (date: string) => golden.reports.find((r) => r.units === 'us' && r.collected_on === date)!.expected;
    expect([us('2026-04-02').hba1c, us('2026-10-14').hba1c]).toEqual([6.2, 5.5]);
    expect([us('2026-04-02').insulin_fasting, us('2026-10-14').insulin_fasting]).toEqual([18.1, 9.4]);
    expect([us('2026-04-02').apob, us('2026-10-14').apob]).toEqual([106, 84]);
    expect([us('2026-04-02').hscrp, us('2026-10-14').hscrp]).toEqual([3.8, 1.7]);
    expect(golden.reports.map((r) => r.units).sort()).toEqual(['si', 'si', 'us', 'us']);
    for (const r of golden.reports) expect(r.files.map((f) => f.split('.').pop()).sort()).toEqual(['pdf', 'png']);
  });

  for (const report of golden.reports) {
    it(`${report.collected_on} (${report.units}): every result maps, normalises to the expected canonical value, nothing needs review`, () => {
      const n = run(report.extraction);
      expect(n.status).toBe('extracted');
      expect(n.identity).toMatchObject({ hold: false, name: 'match', dob: 'match' });
      expect(n.collected_on).toBe(report.collected_on);
      expect(n.lab_name).toBe('Fictional Reference Lab');
      expect(n.results.every((r) => !r.is_unmapped && r.loinc)).toBe(true);
      expect(n.results.flatMap((r) => r.review_reasons)).toEqual([]);
      expect(Object.fromEntries(n.results.map((r) => [r.analyte_key, r.value]))).toEqual(report.expected);
      // The as-printed value and unit are kept alongside.
      for (const [i, r] of n.results.entries()) {
        expect(r.reported_value).toBe(report.extraction.results[i].value);
        expect(r.reported_unit).toBe(report.extraction.results[i].unit);
      }
    });
  }

  for (const date of ['2026-04-02', '2026-10-14']) {
    it(`${date}: the SI report gives identical canonical values, units, LOINC and statuses to the US report`, () => {
      const pick = (units: string) => run(golden.reports.find((r) => r.units === units && r.collected_on === date)!.extraction)
        .results.map((r) => ({ key: r.analyte_key, loinc: r.loinc, value: r.value, unit: r.unit, status: r.status }));
      const us = pick('us');
      const si = pick('si');
      expect(si).toEqual(us);
      // ...and the SI report really did need converting.
      const siRaw = run(golden.reports.find((r) => r.units === 'si' && r.collected_on === date)!.extraction);
      expect(siRaw.results.every((r) => r.conversion_kind !== 'none')).toBe(true);
    });
  }

  it('the same report for another account (different printed name) is held', () => {
    const n = normalizeExtraction(golden.reports[0].extraction, MAP, { name: 'Sam Okafor', dob: '1979-03-14' }, { today: '2026-11-04' });
    expect(n.status).toBe('identity_hold');
    expect(n.identity.reasons).toEqual(['name_mismatch']);
  });

  it('fixture files are real PDFs / PNGs, distinct by SHA-256, and marked fictional', () => {
    const hashes = new Set<string>();
    for (const r of golden.reports) {
      for (const f of r.files) {
        const bytes = readFileSync(`${DIR}${f}`);
        if (f.endsWith('.pdf')) {
          expect(bytes.subarray(0, 5).toString('latin1')).toBe('%PDF-');
          expect(bytes.toString('latin1')).toContain('FICTIONAL SAMPLE REPORT');
        } else {
          expect([...bytes.subarray(0, 8)]).toEqual([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
        }
        hashes.add(createHash('sha256').update(bytes).digest('hex'));
      }
    }
    expect(hashes.size).toBe(8);
  });
});
