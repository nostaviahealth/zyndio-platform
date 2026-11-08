// Phase 2 (C2) Deterministic 35-Field Outcomes Engine (Schedule C / Appendix A & B)
// PRD pages 14-25, 35-36, 40-43.
//
// Rules enforced:
// 1. Identity continuity:
//    - Echoes `partner_patient_id` from DEXASCAN.
//    - Derives `zyndio_patient_token` = `zpt_` + HMAC-SHA256(partnerSecret, platformPatientId).
//    - Never exposes raw `platform_patient_id` UUID in any outbound record or event payload.
//    - Uses `rec_` prefix for `record_id` and `evt_` prefix for `event_id`.
// 2. Derived measures & trend rules:
//    - `% total body-weight change` = round(((followup - baseline) / baseline) * 100, 1)
//      reported alongside `elapsed_treatment_days`.
//    - `HOMA-IR` (same-draw rule, page 18): computed ONLY when fasting glucose (mg/dL)
//      and fasting insulin (uIU/mL) share the exact same draw date (YYYY-MM-DD):
//      `(fasting_insulin * fasting_glucose) / 405`.
//    - Trend direction (`improving | stable | worsening | insufficient_data`) + `trend_reason`:
//      * Returns `insufficient_data` if baseline or follow-up is missing, in `needs_review`,
//        outside milestone window, or method changed:
//        - DEXA scanner `vendor`, `model`, or `software_version` changed (visceral fat / regional / DEXA)
//        - LDL assay `calculated` vs `direct`
//        - HRV metric `sdnn` vs `rmssd`
//        - Lp(a) unit mismatch (`mg/dL` vs `nmol/L`)
//      * Lower-is-better: `hba1c`, `fasting_glucose`, `fasting_insulin`, `homa_ir`,
//        `triglycerides`, `apob`, `ldl_c`, `non_hdl_c`, `hscrp`, `blood_pressure`,
//        `resting_hr`, `fat_mass`, `visceral_fat`, `weight`, `body_fat_pct`, `lp_a`.
//      * Higher-is-better: `hdl_c`, `hrv` (within one method), `vo2max`, `lean_mass`,
//        `appendicular_lean_mass`, `steps`, `active_minutes`.
//      * Judged-against-range: `alt`, `ast`, `ggt`, `creatinine`, `egfr`, thyroid (`tsh`,
//        `free_t3`, `free_t4`), sex hormones (`testosterone`, `estradiol`, `shbg`),
//        `vitamin_d`, `ferritin`, `igf_1`.
// 3. Flags & Governance:
//    - `lean_mass_flag`: `'none' | 'watch' | 'flagged'` against configured threshold.
//    - `clinical_context_flag`: raised when a value crosses a critical threshold, a safety
//      marker (`alt`, `ast`, `ggt`, `egfr`) worsens, `lean_mass_flag === 'flagged'`,
//      an adverse effect is recorded, treatment is paused/stopped, or any input is in
//      `'needs_review'`.
//    - `clinician_summary`: fixed-template deterministic narrative from the numbers
//      (never free AI text).
//    - Clean outbound payload: zero legacy brand strings, zero raw wearable streams,
//      zero `platform_patient_id` UUIDs, zero medication `dose` fields.

export type MilestoneKey = 'baseline' | 'd90' | 'd180' | 'd365' | 'adhoc';

export type OutcomeRecordState =
  | 'computed'
  | 'in_review'
  | 'approved'
  | 'held'
  | 'sent_back'
  | 'delivered'
  | 'withdrawn';

export type TrendDirection = 'improving' | 'stable' | 'worsening' | 'insufficient_data';

export type LeanMassFlag = 'none' | 'watch' | 'flagged';

export interface DexaScannerMeta {
  vendor: string;
  model: string;
  software_version: string;
  site_id?: string | null;
}

export interface SourceProvenance {
  source_type: 'dexa_scan' | 'lab_report' | 'wearable_summary' | 'clinical_record' | 'derived';
  source_id: string;
  recorded_at: string; // YYYY-MM-DD or ISO timestamp
  partner_scan_id?: string;
  partner_scan_version?: number;
  device_vendor?: string;
  device_model?: string;
  software_version?: string;
  lab_report_id?: string;
  draw_date?: string;
  method?: string;
}

export interface BiomarkerSampleInput {
  value: number | null;
  unit: string;
  draw_date?: string | null; // YYYY-MM-DD
  taken_at?: string | null;
  status?: 'within_range' | 'outside_range' | 'needs_review' | 'baseline' | 'no_range';
  method?: string | null; // e.g. 'calculated' | 'direct' for LDL, 'sdnn' | 'rmssd' for HRV
  range_low?: number | null;
  range_high?: number | null;
  outside_window?: boolean;
  critical?: boolean;
  source_id?: string | null;
  lab_report_id?: string | null;
}

export interface DexaScanInput {
  partner_scan_id: string;
  partner_scan_version?: number;
  scan_date: string; // YYYY-MM-DD
  scanner: DexaScannerMeta;
  outside_window?: boolean;
  status?: 'within_range' | 'outside_range' | 'needs_review' | 'baseline' | 'no_range';
  measures: {
    weight_lb?: number | null;
    fat_mass_lb?: number | null;
    lean_mass_lb?: number | null;
    visceral_fat?: number | null;
    visceral_fat_unit?: string | null;
    body_fat_pct?: number | null;
    appendicular_lean_mass_lb?: number | null;
  };
}

export interface BloodPressureSampleInput {
  systolic: number | null;
  diastolic: number | null;
  unit?: string;
  recorded_at?: string | null;
  status?: 'within_range' | 'outside_range' | 'needs_review' | 'baseline' | 'no_range';
  outside_window?: boolean;
  source_id?: string | null;
}

export interface TreatmentContextInput {
  medication_name: string;
  started_on: string | null;
  status: 'active' | 'paused' | 'stopped' | 'discontinued' | 'completed';
  pause_or_stop_reason?: string | null;
  adverse_effect_recorded?: boolean;
  adverse_effect_summary?: string | null;
  source?: string | null;
  // Note: any `dose` key passed at runtime is stripped and never stored/emitted.
}

export interface LeanMassThresholds {
  /** Loss percentage (positive number, e.g. 2.0 means -2.0% change) triggering 'watch'. */
  watchLossPct: number;
  /** Loss percentage (positive number, e.g. 5.0 means -5.0% change) triggering 'flagged'. */
  flaggedLossPct: number;
  /** Optional absolute pound loss triggering 'watch'. */
  watchLossLb?: number;
  /** Optional absolute pound loss triggering 'flagged'. */
  flaggedLossLb?: number;
}

export const DEFAULT_LEAN_MASS_THRESHOLDS: LeanMassThresholds = {
  watchLossPct: 2.0,
  flaggedLossPct: 5.0,
};

export interface ComputeOutcomeMeasureResult {
  key: string;
  label: string;
  baseline: number | null;
  followup: number | null;
  delta_abs: number | null;
  delta_pct: number | null;
  unit: string | null;
  raw_baseline?: { value: number | null; unit: string | null };
  raw_followup?: { value: number | null; unit: string | null };
  normalised: boolean;
  trend: TrendDirection;
  trend_reason: string;
  elapsed_treatment_days?: number | null;
  method_baseline?: string | null;
  method_followup?: string | null;
  same_draw_verified?: boolean;
  range_low?: number | null;
  range_high?: number | null;
  worsened_safety?: boolean;
  crossed_critical?: boolean;
  baseline_provenance: SourceProvenance | null;
  followup_provenance: SourceProvenance | null;
}

export interface OutcomesEngineInput {
  record_id?: string;
  event_id?: string;
  record_version?: number;
  rules_version?: string;
  milestone: MilestoneKey;
  partner_patient_id: string;
  platform_patient_id: string;
  partner_secret: string;
  baseline_date: string;
  followup_date: string;
  treatment_started_on?: string | null;
  elapsed_treatment_days?: number | null;
  treatment_context?: TreatmentContextInput | null;
  baseline_dexa?: DexaScanInput | null;
  followup_dexa?: DexaScanInput | null;
  baseline_biomarkers?: Partial<Record<string, BiomarkerSampleInput>>;
  followup_biomarkers?: Partial<Record<string, BiomarkerSampleInput>>;
  baseline_bp?: BloodPressureSampleInput | null;
  followup_bp?: BloodPressureSampleInput | null;
  lean_mass_thresholds?: Partial<LeanMassThresholds>;
  stability_band_pct?: number;
  state?: OutcomeRecordState;
  approved_by?: string | null;
  approved_at?: string | null;
  clinician_summary_override?: string | null;
}

/** Canonical 35 Schedule C field names in deterministic order. */
export const SCHEDULE_C_35_FIELD_NAMES = [
  // 1-7: Header & Identity (7)
  'record_id',
  'event_id',
  'partner_patient_id',
  'zyndio_patient_token',
  'milestone',
  'record_version',
  'rules_version',
  // 8-11: Timeline & Treatment Context (4)
  'baseline_date',
  'followup_date',
  'elapsed_treatment_days',
  'treatment_context',
  // 12-17: DEXA Body Composition (6)
  'weight',
  'fat_mass',
  'lean_mass',
  'visceral_fat',
  'body_fat_pct',
  'appendicular_lean_mass',
  // 18-22: Core Glycemic & Metabolic Biomarkers (5)
  'hba1c',
  'fasting_glucose',
  'fasting_insulin',
  'homa_ir',
  'triglycerides',
  // 23-27: Lipids & Cardiovascular Biomarkers (5)
  'apob',
  'ldl_c',
  'hdl_c',
  'non_hdl_c',
  'lp_a',
  // 28-31: Inflammation, Vitals & Wearable Summary Aggregates (4)
  'hscrp',
  'blood_pressure',
  'resting_hr_and_hrv',
  'activity_and_vo2max',
  // 32-35: Safety Panel, Flags & Clinician Sign-off (4)
  'safety_panel',
  'lean_mass_flag',
  'clinical_context_flag',
  'clinician_signoff',
] as const;

export type ScheduleCFieldName = (typeof SCHEDULE_C_35_FIELD_NAMES)[number];

export interface ScheduleC35Payload {
  record_id: string;
  event_id: string;
  partner_patient_id: string;
  zyndio_patient_token: string;
  milestone: MilestoneKey;
  record_version: number;
  rules_version: string;
  baseline_date: string;
  followup_date: string;
  elapsed_treatment_days: number;
  treatment_context: {
    medication_name: string | null;
    started_on: string | null;
    status: string | null;
    pause_or_stop_reason: string | null;
    adverse_effect_recorded: boolean;
    adverse_effect_summary: string | null;
    source: string | null;
  };
  weight: ComputeOutcomeMeasureResult;
  fat_mass: ComputeOutcomeMeasureResult;
  lean_mass: ComputeOutcomeMeasureResult & { lean_mass_flag: LeanMassFlag };
  visceral_fat: ComputeOutcomeMeasureResult;
  body_fat_pct: ComputeOutcomeMeasureResult;
  appendicular_lean_mass: ComputeOutcomeMeasureResult;
  hba1c: ComputeOutcomeMeasureResult;
  fasting_glucose: ComputeOutcomeMeasureResult;
  fasting_insulin: ComputeOutcomeMeasureResult;
  homa_ir: ComputeOutcomeMeasureResult;
  triglycerides: ComputeOutcomeMeasureResult;
  apob: ComputeOutcomeMeasureResult;
  ldl_c: ComputeOutcomeMeasureResult;
  hdl_c: ComputeOutcomeMeasureResult;
  non_hdl_c: ComputeOutcomeMeasureResult;
  lp_a: ComputeOutcomeMeasureResult;
  hscrp: ComputeOutcomeMeasureResult;
  blood_pressure: {
    systolic: ComputeOutcomeMeasureResult;
    diastolic: ComputeOutcomeMeasureResult;
    trend: TrendDirection;
    trend_reason: string;
  };
  resting_hr_and_hrv: {
    resting_hr: ComputeOutcomeMeasureResult;
    hrv: ComputeOutcomeMeasureResult;
  };
  activity_and_vo2max: {
    vo2max: ComputeOutcomeMeasureResult;
    steps: ComputeOutcomeMeasureResult;
    active_minutes: ComputeOutcomeMeasureResult;
  };
  safety_panel: {
    alt: ComputeOutcomeMeasureResult;
    ast: ComputeOutcomeMeasureResult;
    ggt: ComputeOutcomeMeasureResult;
    creatinine: ComputeOutcomeMeasureResult;
    egfr: ComputeOutcomeMeasureResult;
    tsh: ComputeOutcomeMeasureResult;
    vitamin_d: ComputeOutcomeMeasureResult;
    ferritin: ComputeOutcomeMeasureResult;
    igf_1: ComputeOutcomeMeasureResult;
  };
  lean_mass_flag: LeanMassFlag;
  clinical_context_flag: boolean;
  clinician_signoff: {
    state: OutcomeRecordState;
    clinician_summary: string;
    clinical_context_reasons: string[];
    approved_by: string | null;
    approved_at: string | null;
  };
}

export interface ComputedOutcomeRecord {
  record_id: string;
  event_id: string;
  partner_patient_id: string;
  zyndio_patient_token: string;
  milestone: MilestoneKey;
  record_version: number;
  rules_version: string;
  state: OutcomeRecordState;
  lean_mass_flag: LeanMassFlag;
  clinical_context_flag: boolean;
  clinical_context_reasons: string[];
  clinician_summary: string;
  elapsed_treatment_days: number;
  schedule_c_field_count: 35;
  schedule_c_fields: ScheduleC35Payload;
  measures: Record<string, ComputeOutcomeMeasureResult>;
}

// ---------------------------------------------------------------------------
// Pure TypeScript FIPS 180-4 SHA-256 + RFC 2104 HMAC-SHA256
// Synchronous, deterministic, zero external dependencies across Deno & Node.
// ---------------------------------------------------------------------------

const SHA256_K = new Uint32Array([
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

function rotr(n: number, x: number): number {
  return (x >>> n) | (x << (32 - n));
}

function sha256Bytes(data: Uint8Array): Uint8Array {
  let h0 = 0x6a09e667;
  let h1 = 0xbb67ae85;
  let h2 = 0x3c6ef372;
  let h3 = 0xa54ff53a;
  let h4 = 0x510e527f;
  let h5 = 0x9b05688c;
  let h6 = 0x1f83d9ab;
  let h7 = 0x5be0cd19;

  const bitLen = data.length * 8;
  const padLen = ((data.length + 9 + 63) & ~63);
  const padded = new Uint8Array(padLen);
  padded.set(data);
  padded[data.length] = 0x80;
  const view = new DataView(padded.buffer);
  view.setUint32(padLen - 8, Math.floor(bitLen / 0x100000000), false);
  view.setUint32(padLen - 4, bitLen >>> 0, false);

  const w = new Uint32Array(64);
  for (let offset = 0; offset < padLen; offset += 64) {
    for (let i = 0; i < 16; i++) {
      w[i] = view.getUint32(offset + i * 4, false);
    }
    for (let i = 16; i < 64; i++) {
      const s0 = rotr(7, w[i - 15]) ^ rotr(18, w[i - 15]) ^ (w[i - 15] >>> 3);
      const s1 = rotr(17, w[i - 2]) ^ rotr(19, w[i - 2]) ^ (w[i - 2] >>> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) >>> 0;
    }

    let a = h0;
    let b = h1;
    let c = h2;
    let d = h3;
    let e = h4;
    let f = h5;
    let g = h6;
    let h = h7;

    for (let i = 0; i < 64; i++) {
      const S1 = rotr(6, e) ^ rotr(11, e) ^ rotr(25, e);
      const ch = (e & f) ^ (~e & g);
      const temp1 = (h + S1 + ch + SHA256_K[i] + w[i]) >>> 0;
      const S0 = rotr(2, a) ^ rotr(13, a) ^ rotr(22, a);
      const maj = (a & b) ^ (a & c) ^ (b & c);
      const temp2 = (S0 + maj) >>> 0;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) >>> 0;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) >>> 0;
    }

    h0 = (h0 + a) >>> 0;
    h1 = (h1 + b) >>> 0;
    h2 = (h2 + c) >>> 0;
    h3 = (h3 + d) >>> 0;
    h4 = (h4 + e) >>> 0;
    h5 = (h5 + f) >>> 0;
    h6 = (h6 + g) >>> 0;
    h7 = (h7 + h) >>> 0;
  }

  const out = new Uint8Array(32);
  const outView = new DataView(out.buffer);
  outView.setUint32(0, h0, false);
  outView.setUint32(4, h1, false);
  outView.setUint32(8, h2, false);
  outView.setUint32(12, h3, false);
  outView.setUint32(16, h4, false);
  outView.setUint32(20, h5, false);
  outView.setUint32(24, h6, false);
  outView.setUint32(28, h7, false);
  return out;
}

export function hmacSha256Hex(secret: string, message: string): string {
  const enc = new TextEncoder();
  let keyBytes: Uint8Array = enc.encode(secret);
  if (keyBytes.length > 64) {
    keyBytes = sha256Bytes(keyBytes);
  }
  const blockKey = new Uint8Array(64);
  blockKey.set(keyBytes);

  const oKeyPad = new Uint8Array(64);
  const iKeyPad = new Uint8Array(64);
  for (let i = 0; i < 64; i++) {
    oKeyPad[i] = blockKey[i] ^ 0x5c;
    iKeyPad[i] = blockKey[i] ^ 0x36;
  }

  const msgBytes = enc.encode(message);
  const innerInput = new Uint8Array(64 + msgBytes.length);
  innerInput.set(iKeyPad);
  innerInput.set(msgBytes, 64);
  const innerHash = sha256Bytes(innerInput);

  const outerInput = new Uint8Array(64 + 32);
  outerInput.set(oKeyPad);
  outerInput.set(innerHash, 64);
  const digest = sha256Bytes(outerInput);

  return Array.from(digest)
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Generates `zyndio_patient_token` (`zpt_` + HMAC-SHA256 hex of `platform_patient_id`
 * with the partner-specific secret). Never exposes `platform_patient_id`.
 */
export function computeZyndioPatientToken(platformPatientId: string, partnerSecret: string): string {
  if (!platformPatientId || !platformPatientId.trim()) {
    throw new Error('platform_patient_id is required to derive zyndio_patient_token');
  }
  if (!partnerSecret || !partnerSecret.trim()) {
    throw new Error('partner_secret is required to derive zyndio_patient_token');
  }
  const mac = hmacSha256Hex(partnerSecret.trim(), platformPatientId.trim());
  return `zpt_${mac}`;
}

export function formatRecordId(idOrSeed: string): string {
  const clean = idOrSeed.trim();
  return clean.startsWith('rec_') ? clean : `rec_${clean}`;
}

export function formatEventId(idOrSeed: string): string {
  const clean = idOrSeed.trim();
  return clean.startsWith('evt_') ? clean : `evt_${clean}`;
}

// ---------------------------------------------------------------------------
// Math & Normalisation Helpers
// ---------------------------------------------------------------------------

export function roundTo(value: number, decimals = 1): number {
  const factor = Math.pow(10, decimals);
  const rounded = Math.round((value + Number.EPSILON) * factor) / factor;
  return Object.is(rounded, -0) ? 0 : rounded;
}

/**
 * Computes `% change`: `round(((followup - baseline) / baseline) * 100, 1)`.
 */
export function computePercentChange(baseline: number | null, followup: number | null): number | null {
  if (baseline === null || followup === null || !Number.isFinite(baseline) || !Number.isFinite(followup) || baseline === 0) {
    return null;
  }
  return roundTo(((followup - baseline) / baseline) * 100, 1);
}

export function computeAbsoluteDelta(baseline: number | null, followup: number | null, decimals = 1): number | null {
  if (baseline === null || followup === null || !Number.isFinite(baseline) || !Number.isFinite(followup)) {
    return null;
  }
  return roundTo(followup - baseline, decimals);
}

export function computeElapsedDays(startDateIso: string | null | undefined, endDateIso: string | null | undefined): number {
  if (!startDateIso || !endDateIso) return 0;
  const start = new Date(startDateIso.slice(0, 10) + 'T00:00:00Z');
  const end = new Date(endDateIso.slice(0, 10) + 'T00:00:00Z');
  const diffMs = end.getTime() - start.getTime();
  if (!Number.isFinite(diffMs)) return 0;
  return Math.max(0, Math.round(diffMs / (1000 * 60 * 60 * 24)));
}

/**
 * Normalises biomarker values into canonical Schedule C units while preserving raw values.
 * Note: Lp(a) (`lp_a`) cannot be linearly converted between `mg/dL` and `nmol/L`;
 * unit mismatches on Lp(a) are preserved as-is and flagged as `insufficient_data`.
 */
export function normaliseBiomarkerUnit(
  key: string,
  value: number | null,
  unit: string | null | undefined
): { value: number | null; unit: string; normalised: boolean } {
  const rawUnit = (unit ?? '').trim();
  if (value === null || !Number.isFinite(value)) {
    return { value: null, unit: rawUnit || canonicalUnitFor(key), normalised: false };
  }

  const lowerUnit = rawUnit.toLowerCase();
  switch (key) {
    case 'fasting_glucose':
      if (value < 0) return { value: null, unit: rawUnit || 'mg/dL', normalised: false };
      if (lowerUnit === 'mmol/l' || lowerUnit === 'mm') {
        return { value: roundTo(value * 18.0182, 1), unit: 'mg/dL', normalised: true };
      }
      if (lowerUnit === 'mg/dl' || lowerUnit === '') {
        return { value: roundTo(value, 1), unit: 'mg/dL', normalised: lowerUnit === 'mg/dl' };
      }
      return { value: null, unit: rawUnit, normalised: false };
    case 'triglycerides':
      if (value < 0) return { value: null, unit: rawUnit || 'mg/dL', normalised: false };
      if (lowerUnit === 'mmol/l' || lowerUnit === 'mm') {
        return { value: roundTo(value * 88.57, 1), unit: 'mg/dL', normalised: true };
      }
      if (lowerUnit === 'mg/dl' || lowerUnit === '') {
        return { value: roundTo(value, 1), unit: 'mg/dL', normalised: lowerUnit === 'mg/dl' };
      }
      return { value: null, unit: rawUnit, normalised: false };
    case 'ldl_c':
    case 'hdl_c':
    case 'non_hdl_c':
      if (value < 0) return { value: null, unit: rawUnit || 'mg/dL', normalised: false };
      if (lowerUnit === 'mmol/l' || lowerUnit === 'mm') {
        return { value: roundTo(value * 38.67, 1), unit: 'mg/dL', normalised: true };
      }
      if (lowerUnit === 'mg/dl' || lowerUnit === '') {
        return { value: roundTo(value, 1), unit: 'mg/dL', normalised: lowerUnit === 'mg/dl' };
      }
      return { value: null, unit: rawUnit, normalised: false };
    case 'apob':
      if (value < 0) return { value: null, unit: rawUnit || 'mg/dL', normalised: false };
      if (lowerUnit === 'g/l') {
        return { value: roundTo(value * 100, 1), unit: 'mg/dL', normalised: true };
      }
      if (lowerUnit === 'mg/dl' || lowerUnit === '') {
        return { value: roundTo(value, 1), unit: 'mg/dL', normalised: lowerUnit === 'mg/dl' };
      }
      return { value: null, unit: rawUnit, normalised: false };
    case 'creatinine':
      if (value < 0) return { value: null, unit: rawUnit || 'mg/dL', normalised: false };
      if (lowerUnit === 'umol/l' || lowerUnit === 'µmol/l') {
        return { value: roundTo(value / 88.4, 2), unit: 'mg/dL', normalised: true };
      }
      if (lowerUnit === 'mg/dl' || lowerUnit === '') {
        return { value: roundTo(value, 2), unit: 'mg/dL', normalised: lowerUnit === 'mg/dl' };
      }
      return { value: null, unit: rawUnit, normalised: false };
    case 'weight':
    case 'fat_mass':
    case 'lean_mass':
    case 'appendicular_lean_mass':
    case 'visceral_fat':
      if (value < 0) return { value: null, unit: rawUnit || 'lb', normalised: false };
      if (lowerUnit === 'kg' || lowerUnit === 'kgs') {
        return { value: roundTo(value * 2.20462, 1), unit: 'lb', normalised: true };
      }
      if (lowerUnit === 'lb' || lowerUnit === 'lbs' || lowerUnit === 'pound' || lowerUnit === 'pounds' || lowerUnit === '') {
        return { value: roundTo(value, 1), unit: 'lb', normalised: lowerUnit !== '' };
      }
      return { value: null, unit: rawUnit, normalised: false };
    case 'fasting_insulin':
      if (value < 0) return { value: null, unit: rawUnit || 'uIU/mL', normalised: false };
      if (lowerUnit === 'pmol/l') {
        return { value: roundTo(value / 6.945, 1), unit: 'uIU/mL', normalised: true };
      }
      if (lowerUnit === 'uiu/ml' || lowerUnit === 'mu/l' || lowerUnit === '') {
        return { value: roundTo(value, 1), unit: 'uIU/mL', normalised: lowerUnit !== '' };
      }
      return { value: null, unit: rawUnit, normalised: false };
    case 'body_fat_pct':
      if (value < 0 || value > 100) return { value: null, unit: rawUnit || '%', normalised: false };
      return { value: roundTo(value, 1), unit: '%', normalised: false };
    case 'lp_a':
      // Never convert between mg/dL and nmol/L
      return { value: roundTo(value, 1), unit: rawUnit || 'nmol/L', normalised: false };
    default:
      return { value: roundTo(value, 1), unit: rawUnit || canonicalUnitFor(key), normalised: false };
  }
}

export function canonicalUnitFor(key: string): string {
  switch (key) {
    case 'weight':
    case 'fat_mass':
    case 'lean_mass':
    case 'appendicular_lean_mass':
      return 'lb';
    case 'body_fat_pct':
    case 'hba1c':
      return '%';
    case 'visceral_fat':
      return 'lbs';
    case 'fasting_glucose':
    case 'triglycerides':
    case 'apob':
    case 'ldl_c':
    case 'hdl_c':
    case 'non_hdl_c':
    case 'creatinine':
      return 'mg/dL';
    case 'fasting_insulin':
      return 'uIU/mL';
    case 'homa_ir':
      return 'index';
    case 'hscrp':
      return 'mg/L';
    case 'lp_a':
      return 'nmol/L';
    case 'systolic_bp':
    case 'diastolic_bp':
      return 'mmHg';
    case 'resting_hr':
      return 'bpm';
    case 'hrv':
      return 'ms';
    case 'vo2max':
      return 'mL/kg/min';
    case 'steps':
      return 'steps/day';
    case 'active_minutes':
      return 'min/week';
    case 'alt':
    case 'ast':
    case 'ggt':
      return 'U/L';
    case 'egfr':
      return 'mL/min/1.73m2';
    case 'tsh':
      return 'mIU/L';
    case 'vitamin_d':
    case 'ferritin':
    case 'igf_1':
      return 'ng/mL';
    default:
      return '';
  }
}

// ---------------------------------------------------------------------------
// HOMA-IR Same-Draw Rule (PRD page 18)
// ---------------------------------------------------------------------------

export interface HomaIrComputation {
  value: number | null;
  same_draw_verified: boolean;
  draw_date: string | null;
  reason: string;
}

/**
 * Computes HOMA-IR = `(fasting_insulin * fasting_glucose) / 405` ONLY when
 * fasting glucose and fasting insulin share the exact same draw date (YYYY-MM-DD)
 * and neither is in `needs_review`.
 */
export function computeHomaIrSameDraw(
  glucose: BiomarkerSampleInput | null | undefined,
  insulin: BiomarkerSampleInput | null | undefined
): HomaIrComputation {
  if (!glucose || !insulin || glucose.value === null || insulin.value === null) {
    return {
      value: null,
      same_draw_verified: false,
      draw_date: null,
      reason: 'missing_glucose_or_insulin',
    };
  }
  if (glucose.status === 'needs_review' || insulin.status === 'needs_review') {
    return {
      value: null,
      same_draw_verified: false,
      draw_date: null,
      reason: 'input_needs_review',
    };
  }
  const gDate = (glucose.draw_date ?? glucose.taken_at ?? '').slice(0, 10);
  const iDate = (insulin.draw_date ?? insulin.taken_at ?? '').slice(0, 10);
  if (!gDate || !iDate || gDate !== iDate) {
    return {
      value: null,
      same_draw_verified: false,
      draw_date: null,
      reason: 'different_draw_dates',
    };
  }

  const normGlucose = normaliseBiomarkerUnit('fasting_glucose', glucose.value, glucose.unit);
  const normInsulin = normaliseBiomarkerUnit('fasting_insulin', insulin.value, insulin.unit);
  if (
    normGlucose.value === null ||
    normInsulin.value === null ||
    normGlucose.value <= 0 ||
    normInsulin.value <= 0
  ) {
    return {
      value: null,
      same_draw_verified: false,
      draw_date: gDate,
      reason: 'invalid_numeric_value',
    };
  }

  const homa = roundTo((normInsulin.value * normGlucose.value) / 405, 2);
  return {
    value: homa,
    same_draw_verified: true,
    draw_date: gDate,
    reason: 'same_draw_verified',
  };
}

// ---------------------------------------------------------------------------
// Measure Classification & Trend Direction Rules
// ---------------------------------------------------------------------------

export const LOWER_IS_BETTER_MEASURES: ReadonlySet<string> = new Set([
  'hba1c',
  'fasting_glucose',
  'fasting_insulin',
  'homa_ir',
  'triglycerides',
  'apob',
  'ldl_c',
  'non_hdl_c',
  'hscrp',
  'blood_pressure',
  'systolic_bp',
  'diastolic_bp',
  'resting_hr',
  'fat_mass',
  'visceral_fat',
  'weight',
  'body_fat_pct',
  'lp_a',
]);

export const HIGHER_IS_BETTER_MEASURES: ReadonlySet<string> = new Set([
  'hdl_c',
  'hrv',
  'vo2max',
  'lean_mass',
  'appendicular_lean_mass',
  'steps',
  'active_minutes',
]);

export const JUDGED_AGAINST_RANGE_MEASURES: ReadonlySet<string> = new Set([
  'alt',
  'ast',
  'ggt',
  'creatinine',
  'egfr',
  'tsh',
  'free_t3',
  'free_t4',
  'testosterone',
  'estradiol',
  'shbg',
  'vitamin_d',
  'ferritin',
  'igf_1',
]);

export function didDexaScannerChange(
  baselineScanner: DexaScannerMeta | null | undefined,
  followupScanner: DexaScannerMeta | null | undefined
): boolean {
  if (!baselineScanner || !followupScanner) return false;
  return (
    baselineScanner.vendor.trim().toLowerCase() !== followupScanner.vendor.trim().toLowerCase() ||
    baselineScanner.model.trim().toLowerCase() !== followupScanner.model.trim().toLowerCase() ||
    baselineScanner.software_version.trim().toLowerCase() !== followupScanner.software_version.trim().toLowerCase()
  );
}

/**
 * Evaluates lean mass preservation flag (`'none' | 'watch' | 'flagged'`) against thresholds.
 */
export function evaluateLeanMassFlag(
  baselineLeanLb: number | null,
  followupLeanLb: number | null,
  thresholds: LeanMassThresholds = DEFAULT_LEAN_MASS_THRESHOLDS
): LeanMassFlag {
  if (baselineLeanLb === null || followupLeanLb === null || baselineLeanLb <= 0) {
    return 'none';
  }
  const deltaLb = computeAbsoluteDelta(baselineLeanLb, followupLeanLb, 1);
  const deltaPct = computePercentChange(baselineLeanLb, followupLeanLb);
  if (deltaLb === null || deltaPct === null || deltaPct >= 0) {
    return 'none';
  }
  const lossPct = Math.abs(deltaPct);
  const lossLb = Math.abs(deltaLb);

  if (
    lossPct >= thresholds.flaggedLossPct ||
    (thresholds.flaggedLossLb !== undefined && lossLb >= thresholds.flaggedLossLb)
  ) {
    return 'flagged';
  }
  if (
    lossPct >= thresholds.watchLossPct ||
    (thresholds.watchLossLb !== undefined && lossLb >= thresholds.watchLossLb)
  ) {
    return 'watch';
  }
  return 'none';
}

export function evaluateCriticalThreshold(key: string, value: number | null): boolean {
  if (value === null || !Number.isFinite(value)) return false;
  switch (key) {
    case 'hba1c':
      return value >= 9.0;
    case 'fasting_glucose':
      return value >= 200 || value < 54;
    case 'triglycerides':
      return value >= 500;
    case 'systolic_bp':
      return value >= 180 || value < 85;
    case 'diastolic_bp':
      return value >= 120;
    case 'egfr':
      return value < 60;
    case 'alt':
    case 'ast':
    case 'ggt':
      return value >= 120;
    default:
      return false;
  }
}

function evaluateRangeTrend(
  key: string,
  baseline: number,
  followup: number,
  rangeLow: number | null | undefined,
  rangeHigh: number | null | undefined
): { trend: TrendDirection; reason: string; worsenedSafety: boolean } {
  const low = rangeLow ?? defaultRangeFor(key).low;
  const high = rangeHigh ?? defaultRangeFor(key).high;

  const baseIn = (low === null || baseline >= low) && (high === null || baseline <= high);
  const followIn = (low === null || followup >= low) && (high === null || followup <= high);

  // Safety markers: ALT, AST, GGT (higher above range_high is worse), eGFR (lower below range_low is worse)
  if (key === 'alt' || key === 'ast' || key === 'ggt') {
    const upper = high ?? 40;
    if (followup > upper && (followup > baseline || baseIn)) {
      return { trend: 'worsening', reason: 'exceeded_upper_reference_limit', worsenedSafety: true };
    }
    if (!baseIn && followIn) {
      return { trend: 'improving', reason: 'returned_within_reference_range', worsenedSafety: false };
    }
    return { trend: 'stable', reason: 'within_reference_range', worsenedSafety: false };
  }

  if (key === 'egfr') {
    const lower = low ?? 60;
    if (followup < lower && (followup < baseline || baseIn)) {
      return { trend: 'worsening', reason: 'fell_below_lower_reference_limit', worsenedSafety: true };
    }
    if (!baseIn && followIn) {
      return { trend: 'improving', reason: 'returned_within_reference_range', worsenedSafety: false };
    }
    return { trend: 'stable', reason: 'within_reference_range', worsenedSafety: false };
  }

  if (!baseIn && followIn) {
    return { trend: 'improving', reason: 'returned_within_reference_range', worsenedSafety: false };
  }
  if (baseIn && !followIn) {
    return { trend: 'worsening', reason: 'moved_outside_reference_range', worsenedSafety: false };
  }
  return { trend: 'stable', reason: 'within_reference_range', worsenedSafety: false };
}

function defaultRangeFor(key: string): { low: number | null; high: number | null } {
  switch (key) {
    case 'alt':
    case 'ast':
      return { low: 7, high: 40 };
    case 'ggt':
      return { low: 5, high: 45 };
    case 'creatinine':
      return { low: 0.6, high: 1.3 };
    case 'egfr':
      return { low: 60, high: null };
    case 'tsh':
      return { low: 0.45, high: 4.5 };
    case 'vitamin_d':
      return { low: 30, high: 100 };
    case 'ferritin':
      return { low: 20, high: 300 };
    case 'igf_1':
      return { low: 75, high: 250 };
    default:
      return { low: null, high: null };
  }
}

export function evaluateMeasureComparison(params: {
  key: string;
  label: string;
  baselineSample?: BiomarkerSampleInput | null;
  followupSample?: BiomarkerSampleInput | null;
  baselineProvenance?: SourceProvenance | null;
  followupProvenance?: SourceProvenance | null;
  scannerChanged?: boolean;
  elapsedTreatmentDays?: number | null;
  stabilityBandPct?: number;
  decimals?: number;
}): ComputeOutcomeMeasureResult {
  const {
    key,
    label,
    baselineSample,
    followupSample,
    baselineProvenance = null,
    followupProvenance = null,
    scannerChanged = false,
    elapsedTreatmentDays,
    stabilityBandPct = 1.0,
    decimals = 1,
  } = params;

  const rawBaseVal = baselineSample?.value ?? null;
  const rawFollowVal = followupSample?.value ?? null;
  const rawBaseUnit = baselineSample?.unit ?? null;
  const rawFollowUnit = followupSample?.unit ?? null;

  const normBase = normaliseBiomarkerUnit(key, rawBaseVal, rawBaseUnit);
  const normFollow = normaliseBiomarkerUnit(key, rawFollowVal, rawFollowUnit);

  const unit = normFollow.unit || normBase.unit || canonicalUnitFor(key);
  const delta_abs = computeAbsoluteDelta(normBase.value, normFollow.value, decimals);
  const delta_pct = computePercentChange(normBase.value, normFollow.value);

  const methodBaseline = baselineSample?.method ?? null;
  const methodFollowup = followupSample?.method ?? null;

  const crossedCritical =
    Boolean(baselineSample?.critical) ||
    Boolean(followupSample?.critical) ||
    evaluateCriticalThreshold(key, normFollow.value);

  const baseResult = {
    key,
    label,
    baseline: normBase.value,
    followup: normFollow.value,
    delta_abs,
    delta_pct,
    unit,
    raw_baseline: { value: rawBaseVal, unit: rawBaseUnit },
    raw_followup: { value: rawFollowVal, unit: rawFollowUnit },
    normalised: normBase.normalised || normFollow.normalised,
    ...(elapsedTreatmentDays !== undefined ? { elapsed_treatment_days: elapsedTreatmentDays } : {}),
    method_baseline: methodBaseline,
    method_followup: methodFollowup,
    range_low: followupSample?.range_low ?? baselineSample?.range_low ?? defaultRangeFor(key).low,
    range_high: followupSample?.range_high ?? baselineSample?.range_high ?? defaultRangeFor(key).high,
    worsened_safety: false,
    crossed_critical: crossedCritical,
    baseline_provenance: baselineProvenance,
    followup_provenance: followupProvenance,
  };

  // 1. Input needs_review check
  if (baselineSample?.status === 'needs_review' || followupSample?.status === 'needs_review') {
    return {
      ...baseResult,
      trend: 'insufficient_data',
      trend_reason: 'input_needs_review',
    };
  }

  // 2. Missing baseline or follow-up check
  if (normBase.value === null || normFollow.value === null || normBase.value === 0) {
    return {
      ...baseResult,
      trend: 'insufficient_data',
      trend_reason: normBase.value === 0 ? 'zero_baseline' : 'missing_baseline_or_followup',
    };
  }

  // 3. Outside milestone window check
  if (baselineSample?.outside_window || followupSample?.outside_window) {
    return {
      ...baseResult,
      trend: 'insufficient_data',
      trend_reason: 'outside_milestone_window',
    };
  }

  // 4. Method-changed checks (Schedule C / PRD page 21)
  if (
    scannerChanged &&
    (key === 'visceral_fat' ||
      key === 'appendicular_lean_mass' ||
      key === 'fat_mass' ||
      key === 'lean_mass' ||
      key === 'body_fat_pct')
  ) {
    return {
      ...baseResult,
      trend: 'insufficient_data',
      trend_reason: 'method_changed_dexa_scanner',
    };
  }

  if (key === 'ldl_c' && methodBaseline && methodFollowup && methodBaseline.toLowerCase() !== methodFollowup.toLowerCase()) {
    return {
      ...baseResult,
      trend: 'insufficient_data',
      trend_reason: 'method_changed_ldl_assay',
    };
  }

  if (key === 'hrv' && methodBaseline && methodFollowup && methodBaseline.toLowerCase() !== methodFollowup.toLowerCase()) {
    return {
      ...baseResult,
      trend: 'insufficient_data',
      trend_reason: 'method_changed_hrv_metric',
    };
  }

  if (
    key === 'lp_a' &&
    rawBaseUnit &&
    rawFollowUnit &&
    rawBaseUnit.trim().toLowerCase() !== rawFollowUnit.trim().toLowerCase()
  ) {
    return {
      ...baseResult,
      delta_abs: null,
      delta_pct: null,
      trend: 'insufficient_data',
      trend_reason: 'method_changed_lpa_units',
    };
  }

  if (
    methodBaseline &&
    methodFollowup &&
    methodBaseline.trim().toLowerCase() !== methodFollowup.trim().toLowerCase()
  ) {
    return {
      ...baseResult,
      trend: 'insufficient_data',
      trend_reason: 'method_changed',
    };
  }

  // 5. Judged-against-range measures (safety & endocrine)
  if (JUDGED_AGAINST_RANGE_MEASURES.has(key)) {
    const rangeEval = evaluateRangeTrend(
      key,
      normBase.value,
      normFollow.value,
      baseResult.range_low,
      baseResult.range_high
    );
    return {
      ...baseResult,
      trend: rangeEval.trend,
      trend_reason: rangeEval.reason,
      worsened_safety: rangeEval.worsenedSafety,
    };
  }

  // 6. Lower-is-better & Higher-is-better measures
  if (delta_pct === null) {
    return {
      ...baseResult,
      trend: 'insufficient_data',
      trend_reason: 'percent_change_undefined',
    };
  }
  const pct = delta_pct;
  if (Math.abs(pct) <= stabilityBandPct) {
    return {
      ...baseResult,
      trend: 'stable',
      trend_reason: 'within_stability_band',
    };
  }

  if (LOWER_IS_BETTER_MEASURES.has(key)) {
    const improving = pct < -stabilityBandPct;
    return {
      ...baseResult,
      trend: improving ? 'improving' : 'worsening',
      trend_reason: improving ? 'favourable_reduction' : 'unfavourable_increase',
    };
  }

  if (HIGHER_IS_BETTER_MEASURES.has(key)) {
    const improving = pct > stabilityBandPct;
    return {
      ...baseResult,
      trend: improving ? 'improving' : 'worsening',
      trend_reason: improving ? 'favourable_increase' : 'unfavourable_decrease',
    };
  }

  return {
    ...baseResult,
    trend: 'stable',
    trend_reason: 'evaluated',
  };
}

// ---------------------------------------------------------------------------
// Deterministic Fixed-Template Narrative Builder (`clinician_summary`)
// ---------------------------------------------------------------------------

function fmtDelta(m: ComputeOutcomeMeasureResult): string {
  if (m.baseline === null || m.followup === null) {
    return `${m.label}: insufficient data`;
  }
  const unitSuffix = m.unit ? (m.unit === '%' ? '%' : ` ${m.unit}`) : '';
  const baseStr = `${m.baseline}${m.unit === '%' ? '%' : ''}`;
  const followStr = `${m.followup}${unitSuffix}`;
  const absSign = (m.delta_abs ?? 0) > 0 ? '+' : '';
  const pctSign = (m.delta_pct ?? 0) > 0 ? '+' : '';
  const absUnit = m.unit && m.unit !== '%' ? ` ${m.unit}` : '';
  return `${m.label} ${baseStr} -> ${followStr} (${absSign}${m.delta_abs}${absUnit}, ${pctSign}${m.delta_pct}%, ${m.trend})`;
}

export function buildDeterministicClinicianSummary(params: {
  milestone: MilestoneKey;
  elapsedTreatmentDays: number;
  weight: ComputeOutcomeMeasureResult;
  fatMass: ComputeOutcomeMeasureResult;
  leanMass: ComputeOutcomeMeasureResult;
  leanMassFlag: LeanMassFlag;
  hba1c: ComputeOutcomeMeasureResult;
  fastingInsulin: ComputeOutcomeMeasureResult;
  apob: ComputeOutcomeMeasureResult;
  hscrp: ComputeOutcomeMeasureResult;
  clinicalContextFlag: boolean;
  clinicalContextReasons: string[];
}): string {
  const milestoneLabel = params.milestone.toUpperCase();
  const bodyParts = [
    fmtDelta(params.weight),
    fmtDelta(params.fatMass),
    `${fmtDelta(params.leanMass)} [lean_mass_flag=${params.leanMassFlag}]`,
  ];

  const bioParts = [
    params.hba1c,
    params.fastingInsulin,
    params.apob,
    params.hscrp,
  ]
    .filter((m) => m.baseline !== null && m.followup !== null)
    .map(fmtDelta);

  const flagSentence = params.clinicalContextFlag
    ? `Clinical context flag: RAISED (${params.clinicalContextReasons.join('; ')}). Clinician review and flag clearance required prior to release.`
    : 'Clinical context flag: clear.';

  return [
    `[ Zyndio Outcomes Summary | Milestone ${milestoneLabel} | ${params.elapsedTreatmentDays} elapsed treatment days ]`,
    `Body composition: ${bodyParts.join('; ')}.`,
    bioParts.length > 0 ? `Biomarkers: ${bioParts.join('; ')}.` : 'Biomarkers: no paired draws in milestone window.',
    flagSentence,
  ].join(' ');
}

// ---------------------------------------------------------------------------
// Main 35-Field Outcomes Record Computation
// ---------------------------------------------------------------------------

export function computeOutcomeRecord(input: OutcomesEngineInput): ComputedOutcomeRecord {
  const record_id = formatRecordId(input.record_id ?? `c2_${input.milestone}_v${input.record_version ?? 1}`);
  const event_id = formatEventId(input.event_id ?? `c2_${input.milestone}_v${input.record_version ?? 1}`);
  const record_version = input.record_version ?? 1;
  const rules_version = input.rules_version ?? 'v1.0';
  const zyndio_patient_token = computeZyndioPatientToken(input.platform_patient_id, input.partner_secret);

  const elapsed_treatment_days =
    input.elapsed_treatment_days ??
    computeElapsedDays(input.treatment_started_on ?? input.baseline_date, input.followup_date);

  const stabilityBandPct = input.stability_band_pct ?? 1.0;
  const leanThresholds: LeanMassThresholds = {
    ...DEFAULT_LEAN_MASS_THRESHOLDS,
    ...(input.lean_mass_thresholds ?? {}),
  };

  const scannerChanged = didDexaScannerChange(
    input.baseline_dexa?.scanner,
    input.followup_dexa?.scanner
  );

  const dexaProvenance = (dexa: DexaScanInput | null | undefined): SourceProvenance | null =>
    dexa
      ? {
          source_type: 'dexa_scan',
          source_id: dexa.partner_scan_id,
          recorded_at: dexa.scan_date,
          partner_scan_id: dexa.partner_scan_id,
          partner_scan_version: dexa.partner_scan_version ?? 1,
          device_vendor: dexa.scanner.vendor,
          device_model: dexa.scanner.model,
          software_version: dexa.scanner.software_version,
        }
      : null;

  const baseDexaProv = dexaProvenance(input.baseline_dexa);
  const followDexaProv = dexaProvenance(input.followup_dexa);

  const buildDexaMeasure = (
    key: string,
    label: string,
    baseVal: number | null | undefined,
    followVal: number | null | undefined,
    unit: string,
    includeElapsed = false,
    honorScannerChange = true,
    units?: { baseline?: string | null; followup?: string | null }
  ): ComputeOutcomeMeasureResult =>
    evaluateMeasureComparison({
      key,
      label,
      baselineSample:
        baseVal !== undefined && baseVal !== null
          ? {
              value: baseVal,
              unit: units?.baseline ?? unit,
              status: input.baseline_dexa?.status,
              outside_window: input.baseline_dexa?.outside_window,
            }
          : input.baseline_dexa?.status === 'needs_review'
          ? { value: null, unit: units?.baseline ?? unit, status: 'needs_review' }
          : null,
      followupSample:
        followVal !== undefined && followVal !== null
          ? {
              value: followVal,
              unit: units?.followup ?? unit,
              status: input.followup_dexa?.status,
              outside_window: input.followup_dexa?.outside_window,
            }
          : input.followup_dexa?.status === 'needs_review'
          ? { value: null, unit: units?.followup ?? unit, status: 'needs_review' }
          : null,
      baselineProvenance: baseDexaProv,
      followupProvenance: followDexaProv,
      scannerChanged: honorScannerChange ? scannerChanged : false,
      elapsedTreatmentDays: includeElapsed ? elapsed_treatment_days : undefined,
      stabilityBandPct,
    });

  // Weight is gravimetric scale/DEXA total mass; visceral/regional depend on scanner software
  const weight = buildDexaMeasure(
    'weight',
    'Total weight',
    input.baseline_dexa?.measures.weight_lb,
    input.followup_dexa?.measures.weight_lb,
    'lb',
    true,
    false
  );
  const fat_mass = buildDexaMeasure(
    'fat_mass',
    'Fat mass',
    input.baseline_dexa?.measures.fat_mass_lb,
    input.followup_dexa?.measures.fat_mass_lb,
    'lb',
    false,
    scannerChanged
  );
  const lean_mass_base = buildDexaMeasure(
    'lean_mass',
    'Lean mass',
    input.baseline_dexa?.measures.lean_mass_lb,
    input.followup_dexa?.measures.lean_mass_lb,
    'lb',
    false,
    scannerChanged
  );
  const lean_mass_flag = evaluateLeanMassFlag(
    lean_mass_base.baseline,
    lean_mass_base.followup,
    leanThresholds
  );
  const lean_mass = { ...lean_mass_base, lean_mass_flag };

  const visceral_fat = buildDexaMeasure(
    'visceral_fat',
    'Visceral fat',
    input.baseline_dexa?.measures.visceral_fat,
    input.followup_dexa?.measures.visceral_fat,
    input.baseline_dexa?.measures.visceral_fat_unit ?? 'lb',
    false,
    true,
    {
      baseline: input.baseline_dexa?.measures.visceral_fat_unit,
      followup: input.followup_dexa?.measures.visceral_fat_unit,
    }
  );
  const body_fat_pct = buildDexaMeasure(
    'body_fat_pct',
    'Body fat %',
    input.baseline_dexa?.measures.body_fat_pct,
    input.followup_dexa?.measures.body_fat_pct,
    '%',
    false,
    true
  );
  const appendicular_lean_mass = buildDexaMeasure(
    'appendicular_lean_mass',
    'Appendicular lean mass',
    input.baseline_dexa?.measures.appendicular_lean_mass_lb,
    input.followup_dexa?.measures.appendicular_lean_mass_lb,
    'lb',
    false,
    true
  );

  const labProv = (
    key: string,
    sample: BiomarkerSampleInput | undefined,
    fallbackDate: string,
    sourceType: 'lab_report' | 'wearable_summary' = 'lab_report'
  ): SourceProvenance | null =>
    sample && sample.value !== null
      ? {
          source_type: sourceType,
          source_id: sample.source_id ?? sample.lab_report_id ?? `src_${key}_${fallbackDate}`,
          recorded_at: (sample.draw_date ?? sample.taken_at ?? fallbackDate).slice(0, 10),
          ...(sample.lab_report_id ? { lab_report_id: sample.lab_report_id } : {}),
          draw_date: (sample.draw_date ?? sample.taken_at ?? fallbackDate).slice(0, 10),
          ...(sample.method ? { method: sample.method } : {}),
        }
      : null;

  const buildBioMeasure = (
    key: string,
    label: string,
    sourceType: 'lab_report' | 'wearable_summary' = 'lab_report',
    decimals = 1
  ): ComputeOutcomeMeasureResult => {
    const bSample = input.baseline_biomarkers?.[key] ?? null;
    const fSample = input.followup_biomarkers?.[key] ?? null;
    return evaluateMeasureComparison({
      key,
      label,
      baselineSample: bSample,
      followupSample: fSample,
      baselineProvenance: labProv(key, bSample ?? undefined, input.baseline_date, sourceType),
      followupProvenance: labProv(key, fSample ?? undefined, input.followup_date, sourceType),
      stabilityBandPct,
      decimals,
    });
  };

  const hba1c = buildBioMeasure('hba1c', 'HbA1c');
  const fasting_glucose = buildBioMeasure('fasting_glucose', 'Fasting glucose');
  const fasting_insulin = buildBioMeasure('fasting_insulin', 'Fasting insulin');

  // HOMA-IR same-draw rule
  const baseHoma = computeHomaIrSameDraw(
    input.baseline_biomarkers?.fasting_glucose,
    input.baseline_biomarkers?.fasting_insulin
  );
  const followHoma = computeHomaIrSameDraw(
    input.followup_biomarkers?.fasting_glucose,
    input.followup_biomarkers?.fasting_insulin
  );
  const homaSameDraw = baseHoma.same_draw_verified && followHoma.same_draw_verified;
  const homaEval = evaluateMeasureComparison({
    key: 'homa_ir',
    label: 'HOMA-IR',
    baselineSample:
      baseHoma.value !== null
        ? { value: baseHoma.value, unit: 'index', draw_date: baseHoma.draw_date }
        : null,
    followupSample:
      followHoma.value !== null
        ? { value: followHoma.value, unit: 'index', draw_date: followHoma.draw_date }
        : null,
    baselineProvenance:
      baseHoma.value !== null && baseHoma.draw_date
        ? {
            source_type: 'derived',
            source_id: `homa_ir_baseline_${baseHoma.draw_date}`,
            recorded_at: baseHoma.draw_date,
            draw_date: baseHoma.draw_date,
          }
        : null,
    followupProvenance:
      followHoma.value !== null && followHoma.draw_date
        ? {
            source_type: 'derived',
            source_id: `homa_ir_followup_${followHoma.draw_date}`,
            recorded_at: followHoma.draw_date,
            draw_date: followHoma.draw_date,
          }
        : null,
    stabilityBandPct,
    decimals: 2,
  });
  const homa_ir: ComputeOutcomeMeasureResult = {
    ...homaEval,
    same_draw_verified: homaSameDraw,
    trend_reason:
      !baseHoma.same_draw_verified && baseHoma.reason === 'different_draw_dates'
        ? 'different_draw_dates'
        : !followHoma.same_draw_verified && followHoma.reason === 'different_draw_dates'
        ? 'different_draw_dates'
        : homaEval.trend_reason,
  };

  const triglycerides = buildBioMeasure('triglycerides', 'Triglycerides');
  const apob = buildBioMeasure('apob', 'ApoB');
  const ldl_c = buildBioMeasure('ldl_c', 'LDL-C');
  const hdl_c = buildBioMeasure('hdl_c', 'HDL-C');
  const non_hdl_c = buildBioMeasure('non_hdl_c', 'Non-HDL-C');
  const lp_a = buildBioMeasure('lp_a', 'Lp(a)');
  const hscrp = buildBioMeasure('hscrp', 'hsCRP');

  // Blood pressure
  const systolic = evaluateMeasureComparison({
    key: 'systolic_bp',
    label: 'Systolic BP',
    baselineSample: input.baseline_bp
      ? {
          value: input.baseline_bp.systolic,
          unit: 'mmHg',
          status: input.baseline_bp.status,
          outside_window: input.baseline_bp.outside_window,
        }
      : null,
    followupSample: input.followup_bp
      ? {
          value: input.followup_bp.systolic,
          unit: 'mmHg',
          status: input.followup_bp.status,
          outside_window: input.followup_bp.outside_window,
        }
      : null,
    baselineProvenance:
      input.baseline_bp && input.baseline_bp.systolic !== null
        ? {
            source_type: 'clinical_record',
            source_id: input.baseline_bp.source_id ?? `bp_${input.baseline_date}`,
            recorded_at: input.baseline_bp.recorded_at ?? input.baseline_date,
          }
        : null,
    followupProvenance:
      input.followup_bp && input.followup_bp.systolic !== null
        ? {
            source_type: 'clinical_record',
            source_id: input.followup_bp.source_id ?? `bp_${input.followup_date}`,
            recorded_at: input.followup_bp.recorded_at ?? input.followup_date,
          }
        : null,
    stabilityBandPct,
  });
  const diastolic = evaluateMeasureComparison({
    key: 'diastolic_bp',
    label: 'Diastolic BP',
    baselineSample: input.baseline_bp
      ? {
          value: input.baseline_bp.diastolic,
          unit: 'mmHg',
          status: input.baseline_bp.status,
          outside_window: input.baseline_bp.outside_window,
        }
      : null,
    followupSample: input.followup_bp
      ? {
          value: input.followup_bp.diastolic,
          unit: 'mmHg',
          status: input.followup_bp.status,
          outside_window: input.followup_bp.outside_window,
        }
      : null,
    stabilityBandPct,
  });

  const resting_hr = buildBioMeasure('resting_hr', 'Resting HR', 'wearable_summary');
  const hrv = buildBioMeasure('hrv', 'HRV', 'wearable_summary');
  const vo2max = buildBioMeasure('vo2max', 'VO2max', 'wearable_summary');
  const steps = buildBioMeasure('steps', 'Daily steps (milestone avg)', 'wearable_summary');
  const active_minutes = buildBioMeasure('active_minutes', 'Active minutes (weekly avg)', 'wearable_summary');

  const alt = buildBioMeasure('alt', 'ALT');
  const ast = buildBioMeasure('ast', 'AST');
  const ggt = buildBioMeasure('ggt', 'GGT');
  const creatinine = buildBioMeasure('creatinine', 'Creatinine', 'lab_report', 2);
  const egfr = buildBioMeasure('egfr', 'eGFR');
  const tsh = buildBioMeasure('tsh', 'TSH', 'lab_report', 2);
  const vitamin_d = buildBioMeasure('vitamin_d', 'Vitamin D');
  const ferritin = buildBioMeasure('ferritin', 'Ferritin');
  const igf_1 = buildBioMeasure('igf_1', 'IGF-1');

  const allMeasures: Record<string, ComputeOutcomeMeasureResult> = {
    weight,
    fat_mass,
    lean_mass,
    visceral_fat,
    body_fat_pct,
    appendicular_lean_mass,
    hba1c,
    fasting_glucose,
    fasting_insulin,
    homa_ir,
    triglycerides,
    apob,
    ldl_c,
    hdl_c,
    non_hdl_c,
    lp_a,
    hscrp,
    systolic_bp: systolic,
    diastolic_bp: diastolic,
    resting_hr,
    hrv,
    vo2max,
    steps,
    active_minutes,
    alt,
    ast,
    ggt,
    creatinine,
    egfr,
    tsh,
    vitamin_d,
    ferritin,
    igf_1,
  };

  // Evaluate clinical_context_flag & reasons (Schedule C / PRD page 22)
  const clinical_context_reasons: string[] = [];

  if (lean_mass_flag === 'flagged') {
    clinical_context_reasons.push('lean_mass_loss_flagged');
  }

  for (const m of Object.values(allMeasures)) {
    if (m.crossed_critical) {
      clinical_context_reasons.push(`critical_threshold_${m.key}`);
    }
    if (m.worsened_safety) {
      clinical_context_reasons.push(`safety_marker_worsened_${m.key}`);
    }
    if (m.trend_reason === 'input_needs_review') {
      clinical_context_reasons.push(`input_needs_review_${m.key}`);
    }
  }

  // Also check if any raw biomarker in input had status === 'needs_review'
  for (const [k, s] of Object.entries(input.baseline_biomarkers ?? {})) {
    if (s?.status === 'needs_review' && !clinical_context_reasons.includes(`input_needs_review_${k}`)) {
      clinical_context_reasons.push(`input_needs_review_${k}`);
    }
  }
  for (const [k, s] of Object.entries(input.followup_biomarkers ?? {})) {
    if (s?.status === 'needs_review' && !clinical_context_reasons.includes(`input_needs_review_${k}`)) {
      clinical_context_reasons.push(`input_needs_review_${k}`);
    }
  }

  const tc = input.treatment_context;
  if (tc?.adverse_effect_recorded) {
    clinical_context_reasons.push('adverse_effect_recorded');
  }
  if (tc && (tc.status === 'paused' || tc.status === 'stopped' || tc.status === 'discontinued')) {
    clinical_context_reasons.push(`treatment_${tc.status}`);
  }

  const clinical_context_flag = clinical_context_reasons.length > 0;

  const clinician_summary =
    input.clinician_summary_override && input.clinician_summary_override.trim().length > 0
      ? input.clinician_summary_override.trim()
      : buildDeterministicClinicianSummary({
          milestone: input.milestone,
          elapsedTreatmentDays: elapsed_treatment_days,
          weight,
          fatMass: fat_mass,
          leanMass: lean_mass,
          leanMassFlag: lean_mass_flag,
          hba1c,
          fastingInsulin: fasting_insulin,
          apob,
          hscrp,
          clinicalContextFlag: clinical_context_flag,
          clinicalContextReasons: clinical_context_reasons,
        });

  const state: OutcomeRecordState = input.state ?? 'in_review';

  // Explicit 35-field Schedule C payload (no dose, no platform_patient_id, no raw wearable stream)
  const schedule_c_fields: ScheduleC35Payload = {
    record_id,
    event_id,
    partner_patient_id: input.partner_patient_id,
    zyndio_patient_token,
    milestone: input.milestone,
    record_version,
    rules_version,
    baseline_date: input.baseline_date,
    followup_date: input.followup_date,
    elapsed_treatment_days,
    treatment_context: {
      medication_name: tc?.medication_name ?? null,
      started_on: tc?.started_on ?? null,
      status: tc?.status ?? null,
      pause_or_stop_reason: tc?.pause_or_stop_reason ?? null,
      adverse_effect_recorded: Boolean(tc?.adverse_effect_recorded),
      adverse_effect_summary: tc?.adverse_effect_summary ?? null,
      source: tc?.source ?? null,
    },
    weight,
    fat_mass,
    lean_mass,
    visceral_fat,
    body_fat_pct,
    appendicular_lean_mass,
    hba1c,
    fasting_glucose,
    fasting_insulin,
    homa_ir,
    triglycerides,
    apob,
    ldl_c,
    hdl_c,
    non_hdl_c,
    lp_a,
    hscrp,
    blood_pressure: {
      systolic,
      diastolic,
      trend: systolic.trend,
      trend_reason: systolic.trend_reason,
    },
    resting_hr_and_hrv: {
      resting_hr,
      hrv,
    },
    activity_and_vo2max: {
      vo2max,
      steps,
      active_minutes,
    },
    safety_panel: {
      alt,
      ast,
      ggt,
      creatinine,
      egfr,
      tsh,
      vitamin_d,
      ferritin,
      igf_1,
    },
    lean_mass_flag,
    clinical_context_flag,
    clinician_signoff: {
      state,
      clinician_summary,
      clinical_context_reasons,
      approved_by: input.approved_by ?? null,
      approved_at: input.approved_at ?? null,
    },
  };

  return {
    record_id,
    event_id,
    partner_patient_id: input.partner_patient_id,
    zyndio_patient_token,
    milestone: input.milestone,
    record_version,
    rules_version,
    state,
    lean_mass_flag,
    clinical_context_flag,
    clinical_context_reasons,
    clinician_summary,
    elapsed_treatment_days,
    schedule_c_field_count: 35,
    schedule_c_fields,
    measures: allMeasures,
  };
}

// ---------------------------------------------------------------------------
// Outbound Sanitizer & Schedule C Clean Record Verifier (PRD page 36)
// ---------------------------------------------------------------------------

const FORBIDDEN_OUTBOUND_KEYS = new Set([
  'platform_patient_id',
  'raw_wearable_stream',
  'wearable_samples',
  'epoch_samples',
  'rr_intervals',
  'dose',
  'dosage',
  'dose_mg',
]);

export function assertCleanOutboundOutcomeRecord(
  payload: unknown,
  forbiddenUuid?: string
): { valid: boolean; violations: string[] } {
  const violations: string[] = [];
  const json = JSON.stringify(payload);

  const forbiddenLegacyBrand = new RegExp('nost' + 'avia', 'i');
  if (forbiddenLegacyBrand.test(json)) {
    violations.push('Outbound payload contains forbidden legacy brand string');
  }
  if (forbiddenUuid && json.includes(forbiddenUuid)) {
    violations.push('Outbound payload leaks raw platform_patient_id UUID');
  }

  function walk(node: unknown, path: string) {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) {
      node.forEach((child, idx) => walk(child, `${path}[${idx}]`));
      return;
    }
    for (const [k, v] of Object.entries(node as Record<string, unknown>)) {
      if (FORBIDDEN_OUTBOUND_KEYS.has(k.toLowerCase())) {
        violations.push(`Forbidden key "${k}" at ${path}.${k}`);
      }
      walk(v, `${path}.${k}`);
    }
  }

  walk(payload, '$');
  return { valid: violations.length === 0, violations };
}

// ---------------------------------------------------------------------------
// Golden Fixture Input & Reference Numbers (PRD pages 35-36 & 43)
// ---------------------------------------------------------------------------

export const GOLDEN_FIXTURE_INPUT: OutcomesEngineInput = {
  record_id: 'rec_golden_d180_v1',
  event_id: 'evt_golden_d180_v1',
  record_version: 1,
  rules_version: 'v1.0',
  milestone: 'd180',
  partner_patient_id: 'DEX-PAT-10482',
  platform_patient_id: '00000000-0000-0000-0000-0000000a1001',
  partner_secret: 'dexascan-partner-hmac-secret-test-only',
  baseline_date: '2026-05-01',
  followup_date: '2026-10-28',
  treatment_started_on: '2026-05-01',
  elapsed_treatment_days: 180,
  treatment_context: {
    medication_name: 'GLP-1 / GIP Receptor Agonist Program',
    started_on: '2026-05-01',
    status: 'active',
    adverse_effect_recorded: false,
    source: 'Zyndio clinical record',
  },
  baseline_dexa: {
    partner_scan_id: 'DEXA-SCAN-20260501-01',
    partner_scan_version: 1,
    scan_date: '2026-05-01',
    scanner: {
      vendor: 'Hologic',
      model: 'Horizon A',
      software_version: 'APEX 5.6.1',
      site_id: 'SITE-SF-01',
    },
    measures: {
      weight_lb: 228,
      fat_mass_lb: 82,
      lean_mass_lb: 137,
      visceral_fat: 3.4,
      visceral_fat_unit: 'lbs',
      body_fat_pct: 36.0,
      appendicular_lean_mass_lb: 61.2,
    },
  },
  followup_dexa: {
    partner_scan_id: 'DEXA-SCAN-20261028-01',
    partner_scan_version: 1,
    scan_date: '2026-10-28',
    scanner: {
      vendor: 'Hologic',
      model: 'Horizon A',
      software_version: 'APEX 5.6.1',
      site_id: 'SITE-SF-01',
    },
    measures: {
      weight_lb: 194,
      fat_mass_lb: 55,
      lean_mass_lb: 133,
      visceral_fat: 2.1,
      visceral_fat_unit: 'lbs',
      body_fat_pct: 28.4,
      appendicular_lean_mass_lb: 59.8,
    },
  },
  baseline_biomarkers: {
    hba1c: { value: 6.2, unit: '%', draw_date: '2026-05-01', lab_report_id: 'lab_base_01' },
    fasting_glucose: { value: 108, unit: 'mg/dL', draw_date: '2026-05-01', lab_report_id: 'lab_base_01' },
    fasting_insulin: { value: 18.1, unit: 'uIU/mL', draw_date: '2026-05-01', lab_report_id: 'lab_base_01' },
    triglycerides: { value: 168, unit: 'mg/dL', draw_date: '2026-05-01', lab_report_id: 'lab_base_01' },
    apob: { value: 106, unit: 'mg/dL', draw_date: '2026-05-01', lab_report_id: 'lab_base_01' },
    ldl_c: { value: 134, unit: 'mg/dL', draw_date: '2026-05-01', method: 'calculated', lab_report_id: 'lab_base_01' },
    hdl_c: { value: 46, unit: 'mg/dL', draw_date: '2026-05-01', lab_report_id: 'lab_base_01' },
    non_hdl_c: { value: 158, unit: 'mg/dL', draw_date: '2026-05-01', lab_report_id: 'lab_base_01' },
    lp_a: { value: 42, unit: 'nmol/L', draw_date: '2026-05-01', lab_report_id: 'lab_base_01' },
    hscrp: { value: 3.8, unit: 'mg/L', draw_date: '2026-05-01', lab_report_id: 'lab_base_01' },
    alt: { value: 28, unit: 'U/L', draw_date: '2026-05-01', range_low: 7, range_high: 40, lab_report_id: 'lab_base_01' },
    ast: { value: 24, unit: 'U/L', draw_date: '2026-05-01', range_low: 7, range_high: 40, lab_report_id: 'lab_base_01' },
    ggt: { value: 22, unit: 'U/L', draw_date: '2026-05-01', range_low: 5, range_high: 45, lab_report_id: 'lab_base_01' },
    creatinine: { value: 0.92, unit: 'mg/dL', draw_date: '2026-05-01', range_low: 0.6, range_high: 1.3, lab_report_id: 'lab_base_01' },
    egfr: { value: 94, unit: 'mL/min/1.73m2', draw_date: '2026-05-01', range_low: 60, range_high: null, lab_report_id: 'lab_base_01' },
  },
  followup_biomarkers: {
    hba1c: { value: 5.5, unit: '%', draw_date: '2026-10-28', lab_report_id: 'lab_d180_01' },
    fasting_glucose: { value: 92, unit: 'mg/dL', draw_date: '2026-10-28', lab_report_id: 'lab_d180_01' },
    fasting_insulin: { value: 9.4, unit: 'uIU/mL', draw_date: '2026-10-28', lab_report_id: 'lab_d180_01' },
    triglycerides: { value: 112, unit: 'mg/dL', draw_date: '2026-10-28', lab_report_id: 'lab_d180_01' },
    apob: { value: 84, unit: 'mg/dL', draw_date: '2026-10-28', lab_report_id: 'lab_d180_01' },
    ldl_c: { value: 102, unit: 'mg/dL', draw_date: '2026-10-28', method: 'calculated', lab_report_id: 'lab_d180_01' },
    hdl_c: { value: 54, unit: 'mg/dL', draw_date: '2026-10-28', lab_report_id: 'lab_d180_01' },
    non_hdl_c: { value: 118, unit: 'mg/dL', draw_date: '2026-10-28', lab_report_id: 'lab_d180_01' },
    lp_a: { value: 40, unit: 'nmol/L', draw_date: '2026-10-28', lab_report_id: 'lab_d180_01' },
    hscrp: { value: 1.7, unit: 'mg/L', draw_date: '2026-10-28', lab_report_id: 'lab_d180_01' },
    alt: { value: 21, unit: 'U/L', draw_date: '2026-10-28', range_low: 7, range_high: 40, lab_report_id: 'lab_d180_01' },
    ast: { value: 19, unit: 'U/L', draw_date: '2026-10-28', range_low: 7, range_high: 40, lab_report_id: 'lab_d180_01' },
    ggt: { value: 17, unit: 'U/L', draw_date: '2026-10-28', range_low: 5, range_high: 45, lab_report_id: 'lab_d180_01' },
    creatinine: { value: 0.89, unit: 'mg/dL', draw_date: '2026-10-28', range_low: 0.6, range_high: 1.3, lab_report_id: 'lab_d180_01' },
    egfr: { value: 98, unit: 'mL/min/1.73m2', draw_date: '2026-10-28', range_low: 60, range_high: null, lab_report_id: 'lab_d180_01' },
  },
};
