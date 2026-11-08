import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  GOLDEN_FIXTURE_INPUT,
  SCHEDULE_C_35_FIELD_NAMES,
  assertCleanOutboundOutcomeRecord,
  computeHomaIrSameDraw,
  computeOutcomeRecord,
  computeZyndioPatientToken,
  evaluateMeasureComparison,
} from './outcomesEngine.ts';

Deno.test('Schedule C Golden Fixture reproduces exact PRD pages 35-36 & 43 numbers', () => {
  const rec = computeOutcomeRecord(GOLDEN_FIXTURE_INPUT);

  assertEquals(rec.schedule_c_field_count, 35);
  assertEquals(Object.keys(rec.schedule_c_fields).length, 35);
  assertEquals(Object.keys(rec.schedule_c_fields), [...SCHEDULE_C_35_FIELD_NAMES]);

  // Total weight: 228 lb -> 194 lb (-34 lb, -14.9%, improving)
  assertEquals(rec.measures.weight.baseline, 228);
  assertEquals(rec.measures.weight.followup, 194);
  assertEquals(rec.measures.weight.delta_abs, -34);
  assertEquals(rec.measures.weight.delta_pct, -14.9);
  assertEquals(rec.measures.weight.trend, 'improving');
  assertEquals(rec.measures.weight.elapsed_treatment_days, 180);

  // Fat mass: 82 lb -> 55 lb (-27 lb, -32.9%, improving)
  assertEquals(rec.measures.fat_mass.baseline, 82);
  assertEquals(rec.measures.fat_mass.followup, 55);
  assertEquals(rec.measures.fat_mass.delta_abs, -27);
  assertEquals(rec.measures.fat_mass.delta_pct, -32.9);
  assertEquals(rec.measures.fat_mass.trend, 'improving');

  // Lean mass: 137 lb -> 133 lb (-4 lb, -2.9%, watch under default 2%..5% threshold)
  assertEquals(rec.measures.lean_mass.baseline, 137);
  assertEquals(rec.measures.lean_mass.followup, 133);
  assertEquals(rec.measures.lean_mass.delta_abs, -4);
  assertEquals(rec.measures.lean_mass.delta_pct, -2.9);
  assertEquals(rec.lean_mass_flag, 'watch');

  // Stricter lean mass threshold (flaggedLossPct: 2.5) raises lean_mass_flag = 'flagged' and clinical_context_flag = true
  const strictRec = computeOutcomeRecord({
    ...GOLDEN_FIXTURE_INPUT,
    lean_mass_thresholds: { watchLossPct: 1.5, flaggedLossPct: 2.5 },
  });
  assertEquals(strictRec.lean_mass_flag, 'flagged');
  assertEquals(strictRec.clinical_context_flag, true);

  // HbA1c: 6.2% -> 5.5% (-0.7, -11.3%, improving)
  assertEquals(rec.measures.hba1c.baseline, 6.2);
  assertEquals(rec.measures.hba1c.followup, 5.5);
  assertEquals(rec.measures.hba1c.delta_abs, -0.7);
  assertEquals(rec.measures.hba1c.delta_pct, -11.3);
  assertEquals(rec.measures.hba1c.trend, 'improving');

  // Fasting insulin: 18.1 -> 9.4 uIU/mL (-8.7, -48.1%, improving)
  assertEquals(rec.measures.fasting_insulin.baseline, 18.1);
  assertEquals(rec.measures.fasting_insulin.followup, 9.4);
  assertEquals(rec.measures.fasting_insulin.delta_abs, -8.7);
  assertEquals(rec.measures.fasting_insulin.delta_pct, -48.1);
  assertEquals(rec.measures.fasting_insulin.trend, 'improving');

  // ApoB: 106 -> 84 mg/dL (-22, -20.8%, improving)
  assertEquals(rec.measures.apob.baseline, 106);
  assertEquals(rec.measures.apob.followup, 84);
  assertEquals(rec.measures.apob.delta_abs, -22);
  assertEquals(rec.measures.apob.delta_pct, -20.8);
  assertEquals(rec.measures.apob.trend, 'improving');

  // hsCRP: 3.8 -> 1.7 mg/L (-2.1, -55.3%, improving)
  assertEquals(rec.measures.hscrp.baseline, 3.8);
  assertEquals(rec.measures.hscrp.followup, 1.7);
  assertEquals(rec.measures.hscrp.delta_abs, -2.1);
  assertEquals(rec.measures.hscrp.delta_pct, -55.3);
  assertEquals(rec.measures.hscrp.trend, 'improving');

  // Outbound cleanliness check
  const cleanCheck = assertCleanOutboundOutcomeRecord(
    rec.schedule_c_fields,
    GOLDEN_FIXTURE_INPUT.platform_patient_id
  );
  assertEquals(cleanCheck.valid, true);
  assertEquals(rec.zyndio_patient_token.startsWith('zpt_'), true);
  assertEquals(
    rec.zyndio_patient_token,
    computeZyndioPatientToken(GOLDEN_FIXTURE_INPUT.platform_patient_id, GOLDEN_FIXTURE_INPUT.partner_secret)
  );
});

Deno.test('HOMA-IR same-draw rule: computed only when glucose and insulin share draw date', () => {
  const sameDraw = computeHomaIrSameDraw(
    { value: 108, unit: 'mg/dL', draw_date: '2026-05-01' },
    { value: 18.1, unit: 'uIU/mL', draw_date: '2026-05-01' }
  );
  assertEquals(sameDraw.same_draw_verified, true);
  assertEquals(sameDraw.value, 4.83);

  const differentDraws = computeHomaIrSameDraw(
    { value: 108, unit: 'mg/dL', draw_date: '2026-05-01' },
    { value: 18.1, unit: 'uIU/mL', draw_date: '2026-05-04' }
  );
  assertEquals(differentDraws.same_draw_verified, false);
  assertEquals(differentDraws.value, null);
  assertEquals(differentDraws.reason, 'different_draw_dates');
});

Deno.test('Method-change rule: returns insufficient_data when DEXA vendor, LDL assay, HRV metric, or Lp(a) unit changes', () => {
  const rec = computeOutcomeRecord({
    ...GOLDEN_FIXTURE_INPUT,
    followup_dexa: {
      ...GOLDEN_FIXTURE_INPUT.followup_dexa!,
      scanner: {
        vendor: 'GE Healthcare',
        model: 'Lunar iDXA',
        software_version: 'enCORE 18',
      },
    },
    baseline_biomarkers: {
      ...GOLDEN_FIXTURE_INPUT.baseline_biomarkers,
      ldl_c: { value: 134, unit: 'mg/dL', draw_date: '2026-05-01', method: 'calculated' },
      hrv: { value: 42, unit: 'ms', draw_date: '2026-05-01', method: 'rmssd' },
      lp_a: { value: 42, unit: 'mg/dL', draw_date: '2026-05-01' },
    },
    followup_biomarkers: {
      ...GOLDEN_FIXTURE_INPUT.followup_biomarkers,
      ldl_c: { value: 102, unit: 'mg/dL', draw_date: '2026-10-28', method: 'direct' },
      hrv: { value: 55, unit: 'ms', draw_date: '2026-10-28', method: 'sdnn' },
      lp_a: { value: 98, unit: 'nmol/L', draw_date: '2026-10-28' },
    },
  });

  assertEquals(rec.measures.visceral_fat.trend, 'insufficient_data');
  assertEquals(rec.measures.visceral_fat.trend_reason, 'method_changed_dexa_scanner');
  assertEquals(rec.measures.ldl_c.trend, 'insufficient_data');
  assertEquals(rec.measures.ldl_c.trend_reason, 'method_changed_ldl_assay');
  assertEquals(rec.measures.hrv.trend, 'insufficient_data');
  assertEquals(rec.measures.hrv.trend_reason, 'method_changed_hrv_metric');
  assertEquals(rec.measures.lp_a.trend, 'insufficient_data');
  assertEquals(rec.measures.lp_a.trend_reason, 'method_changed_lpa_units');
});

Deno.test('HOMA-IR converts pmol/L with 6.945 and refuses unknown, negative, or non-finite inputs', () => {
  const fromPmol = computeHomaIrSameDraw(
    { value: 108, unit: 'mg/dL', draw_date: '2026-05-01' },
    { value: 18.1 * 6.945, unit: 'pmol/L', draw_date: '2026-05-01' }
  );
  assertEquals(fromPmol.value, 4.83);

  const fromMm = computeHomaIrSameDraw(
    { value: 6, unit: 'mM', draw_date: '2026-05-01' },
    { value: 18.1, unit: 'uIU/mL', draw_date: '2026-05-01' }
  );
  assertEquals(fromMm.value, 4.83);

  const negative = computeHomaIrSameDraw(
    { value: -108, unit: 'mg/dL', draw_date: '2026-05-01' },
    { value: 18.1, unit: 'uIU/mL', draw_date: '2026-05-01' }
  );
  assertEquals(negative.value, null);
  assertEquals(negative.reason, 'invalid_numeric_value');

  const unknown = computeHomaIrSameDraw(
    { value: 6, unit: 'mystery', draw_date: '2026-05-01' },
    { value: 18.1, unit: 'uIU/mL', draw_date: '2026-05-01' }
  );
  assertEquals(unknown.value, null);
  assertEquals(unknown.reason, 'invalid_numeric_value');
});

Deno.test('a zero baseline is not a stable trend, and lb is not compared with kg as the same number', () => {
  const zero = evaluateMeasureComparison({
    key: 'weight',
    label: 'Total weight',
    baselineSample: { value: 0, unit: 'lb' },
    followupSample: { value: 10, unit: 'lb' },
  });
  assertEquals(zero.trend, 'insufficient_data');
  assertEquals(zero.trend_reason, 'zero_baseline');

  const rec = computeOutcomeRecord({
    ...GOLDEN_FIXTURE_INPUT,
    baseline_dexa: {
      ...GOLDEN_FIXTURE_INPUT.baseline_dexa!,
      measures: {
        ...GOLDEN_FIXTURE_INPUT.baseline_dexa!.measures,
        visceral_fat: 80,
        visceral_fat_unit: 'kg',
      },
    },
    followup_dexa: {
      ...GOLDEN_FIXTURE_INPUT.followup_dexa!,
      measures: {
        ...GOLDEN_FIXTURE_INPUT.followup_dexa!.measures,
        visceral_fat: 80,
        visceral_fat_unit: 'lbs',
      },
    },
  });
  assertEquals(rec.measures.visceral_fat.baseline, 176.4);
  assertEquals(rec.measures.visceral_fat.followup, 80);
});
