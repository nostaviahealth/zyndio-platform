// APP-05: the reviewed LOINC table (migration seed) and the conversion
// catalog (labCatalog.ts) describe the same analytes, and the brief's
// starting codes are all there, unchanged.
import { describe, expect, it } from 'vitest';
import { LAB_CATALOG } from '../../supabase/functions/_shared/labCatalog.ts';
import { analyteNameKey, unitKey } from '../../supabase/functions/_shared/labNormalize.ts';
import { reviewedAnalyteMap } from './reviewedMap.ts';

// APP-05 brief, 4 Nov 2026.
const BRIEF_CODES: Record<string, string> = {
  hba1c: '4548-4', glucose_fasting: '1558-6', insulin_fasting: '20448-7', triglycerides: '2571-8',
  cholesterol_total: '2093-3', ldl_c_calc: '13457-7', ldl_c_direct: '18262-6', hdl_c: '2085-9',
  non_hdl_c: '43396-1', apob: '1884-6', lpa: '10835-7', hscrp: '30522-7', alt: '1742-6', ast: '1920-8',
  ggt: '2324-2', creatinine: '2160-0', egfr: '98979-8', tsh: '3016-3', ft4: '3024-7', ft3: '3051-0',
  testosterone: '2986-8', estradiol: '2243-4', shbg: '13967-5', vitamin_d: '62292-8', ferritin: '2276-4',
  igf1: '2484-4',
};

describe('reviewed LOINC table vs conversion catalog', () => {
  const seeded = reviewedAnalyteMap();

  it('the seed has exactly the brief\'s starting codes', () => {
    expect(Object.fromEntries(seeded.map((r) => [r.analyte_key, r.loinc]))).toEqual(BRIEF_CODES);
  });

  it('every seeded analyte has a catalog entry with the same LOINC and canonical unit, and vice versa', () => {
    expect(seeded.map((r) => r.analyte_key).sort()).toEqual(LAB_CATALOG.map((a) => a.key).sort());
    for (const r of seeded) {
      const a = LAB_CATALOG.find((x) => x.key === r.analyte_key)!;
      expect([r.analyte_key, r.loinc, unitKey(r.canonical_unit)]).toEqual([a.key, a.loinc, unitKey(a.canonicalUnit)]);
    }
  });

  it('no alias maps to two analytes', () => {
    const owner = new Map<string, string>();
    for (const r of seeded) {
      for (const alias of [r.analyte_key, ...r.aliases]) {
        const k = analyteNameKey(alias);
        const prev = owner.get(k);
        expect(prev === undefined || prev === r.analyte_key, `${alias} -> ${prev} and ${r.analyte_key}`).toBe(true);
        owner.set(k, r.analyte_key);
      }
    }
  });

  it('aliases are ASCII (the SQL alias key does not strip accents)', () => {
    for (const r of seeded) for (const a of r.aliases) expect(/^[\x20-\x7e]+$/.test(a), a).toBe(true);
  });
});
