import { supabase } from './supabase';

// TC-015 slice 1 read model: typed calls to the step-A RPCs ONLY
// (physician_patient_roster / physician_roster_chip_counts /
// patient_latest_results / patient_trend / open_patient_detail). Every server
// payload is mapped through an explicit whitelist here, so a column that should
// never reach the clinician portal - a treatment dose above all - cannot leak
// into the UI even if a future migration adds it to the RPC's JSON. The RLS /
// pgTAP / integration suites prove the server side; these mappers are the
// client-side belt-and-braces. See tests/admin-shell/clinical-api.test.ts.

export type FlagKey =
  | 'clinical_context'
  | 'outside_range'
  | 'needs_review'
  | 'identity_hold'
  | 'missing_labs'
  | 'question_waiting';

const FLAG_KEYS: ReadonlySet<string> = new Set<FlagKey>([
  'clinical_context',
  'outside_range',
  'needs_review',
  'identity_hold',
  'missing_labs',
  'question_waiting',
]);

export type LabStatus = 'within_range' | 'outside_range' | 'needs_review' | 'baseline' | 'no_range';

// POR-05: where a result's range came from. 'approved' = the clinic's
// physician-approved range set (no default-range caveat); 'default' = the
// general default stored with the result; 'none' = no range at all.
export type RangeSource = 'approved' | 'default' | 'none';

export type RosterFilter = 'all' | 'flagged' | 'missing_labs' | 'questions_waiting';
export type RosterSort = 'recent' | 'questions_waiting' | 'name';
export type TrendPeriod = '3M' | '6M' | '1Y' | 'All';

export interface RosterPatient {
  patientId: string;
  displayName: string;
  mrn: string;
  sex: string | null;
  birthDate: string | null;
  programStartedOn: string | null;
  latestLabAt: string | null;
  lastActivityAt: string | null;
  openQuestions: number;
  flags: FlagKey[];
}

export interface RosterResult {
  rows: RosterPatient[];
  totalCount: number;
}

export interface RosterParams {
  search?: string | null;
  filter?: RosterFilter;
  sort?: RosterSort;
  limit?: number;
  offset?: number;
}

export interface ChipCounts {
  all: number;
  flagged: number;
  missingLabs: number;
  questionsWaiting: number;
}

export interface LatestResult {
  analyteKey: string;
  analyteLabel: string;
  value: number | null;
  originalValue: number | null;
  unit: string | null;
  status: LabStatus;
  isUnmapped: boolean;
  rangeLow: number | null;
  rangeHigh: number | null;
  takenAt: string | null;
  // Optional so older fixtures/tests stay valid; absent reads as 'default'.
  rangeSource?: RangeSource;
  rangeSetVersion?: number | null;
}

export interface TrendPoint {
  takenAt: string | null;
  value: number | null;
  originalValue: number | null;
  unit: string | null;
  status: LabStatus;
  rangeLow: number | null;
  rangeHigh: number | null;
  rangeSource?: RangeSource;
}

// name / started_on / status / source only - never a dose (there is no dose
// column in the schema, and this whitelist is the second line of defence).
export interface TreatmentContext {
  name: string;
  startedOn: string | null;
  status: string | null;
  source: string | null;
}

export interface PatientDetail {
  patientId: string;
  displayName: string;
  mrn: string;
  sex: string | null;
  birthDate: string | null;
  programStartedOn: string | null;
  lastActivityAt: string | null;
  treatment: TreatmentContext | null;
}

// The clinical read model as an interface, so the live routes use the
// supabase-backed implementation while the /__preview harness injects a
// fixture-backed one at this exact boundary (same page components, not
// look-alikes). See pages/preview/PreviewPhysician*.tsx.
export interface ClinicalApi {
  fetchRoster(params: RosterParams): Promise<RosterResult>;
  fetchChipCounts(): Promise<ChipCounts>;
  openPatientDetail(patientId: string): Promise<PatientDetail | null>;
  fetchLatestResults(patientId: string): Promise<LatestResult[]>;
  fetchTrend(patientId: string, analyteKey: string, period: TrendPeriod): Promise<TrendPoint[]>;
}

type Raw = Record<string, unknown>;

export function num(v: unknown): number | null {
  if (v === null || v === undefined || v === '') return null;
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

export function str(v: unknown): string | null {
  return v === null || v === undefined ? null : String(v);
}

export function asStatus(v: unknown): LabStatus {
  const s = String(v);
  switch (s) {
    case 'within_range':
    case 'outside_range':
    case 'needs_review':
    case 'baseline':
    case 'no_range':
      return s;
    default:
      return 'no_range';
  }
}

export function asRangeSource(v: unknown): RangeSource {
  return v === 'approved' || v === 'none' ? v : 'default';
}

function mapFlags(v: unknown): FlagKey[] {
  if (!Array.isArray(v)) return [];
  return v.filter((f): f is FlagKey => typeof f === 'string' && FLAG_KEYS.has(f));
}

function mapRosterRow(r: Raw): RosterPatient {
  return {
    patientId: String(r.patient_id),
    displayName: String(r.display_name ?? ''),
    mrn: String(r.mrn ?? ''),
    sex: str(r.sex),
    birthDate: str(r.birth_date),
    programStartedOn: str(r.program_started_on),
    latestLabAt: str(r.latest_lab_at),
    lastActivityAt: str(r.last_activity_at),
    openQuestions: num(r.open_questions) ?? 0,
    flags: mapFlags(r.flags),
  };
}

function mapLatest(r: Raw): LatestResult {
  return {
    analyteKey: String(r.analyte_key),
    analyteLabel: String(r.analyte_label ?? r.analyte_key),
    value: num(r.value),
    originalValue: num(r.original_value),
    unit: str(r.unit),
    status: asStatus(r.status),
    isUnmapped: r.is_unmapped === true,
    rangeLow: num(r.range_low),
    rangeHigh: num(r.range_high),
    takenAt: str(r.taken_at),
    rangeSource: asRangeSource(r.range_source),
    rangeSetVersion: num(r.range_set_version),
  };
}

function mapTrend(r: Raw): TrendPoint {
  return {
    takenAt: str(r.taken_at),
    value: num(r.value),
    originalValue: num(r.original_value),
    unit: str(r.unit),
    status: asStatus(r.status),
    rangeLow: num(r.range_low),
    rangeHigh: num(r.range_high),
    rangeSource: asRangeSource(r.range_source),
  };
}

function mapTreatment(v: unknown): TreatmentContext | null {
  if (!v || typeof v !== 'object') return null;
  const t = v as Raw;
  return {
    name: String(t.name ?? ''),
    startedOn: str(t.started_on),
    status: str(t.status),
    source: str(t.source),
  };
}

export function mapPatientDetail(v: unknown): PatientDetail | null {
  // A null jsonb payload is the step-A RPC's single "not-found" signal, shared
  // by unknown id / other clinic / read_only - the page renders the same
  // not-found view for all three (never a distinct "forbidden").
  if (!v || typeof v !== 'object') return null;
  const d = v as Raw;
  if (!d.patient_id) return null;
  return {
    patientId: String(d.patient_id),
    displayName: String(d.display_name ?? ''),
    mrn: String(d.mrn ?? ''),
    sex: str(d.sex),
    birthDate: str(d.birth_date),
    programStartedOn: str(d.program_started_on),
    lastActivityAt: str(d.last_activity_at),
    treatment: mapTreatment(d.treatment),
  };
}

const PERIOD_TO_RPC: Record<TrendPeriod, string> = { '3M': '3M', '6M': '6M', '1Y': '1Y', All: 'ALL' };

export async function fetchRoster(params: RosterParams): Promise<RosterResult> {
  const { data, error } = await supabase.rpc('physician_patient_roster', {
    p_search: params.search ?? null,
    p_filter: params.filter ?? 'all',
    p_sort: params.sort ?? 'recent',
    p_limit: params.limit ?? 8,
    p_offset: params.offset ?? 0,
  });
  if (error) throw error;
  const rows = Array.isArray(data) ? (data as Raw[]) : [];
  const totalCount = rows.length > 0 ? num(rows[0].total_count) ?? rows.length : 0;
  return { rows: rows.map(mapRosterRow), totalCount };
}

export async function fetchChipCounts(): Promise<ChipCounts> {
  const { data, error } = await supabase.rpc('physician_roster_chip_counts');
  if (error) throw error;
  const row = (Array.isArray(data) ? (data[0] as Raw | undefined) : (data as Raw | null)) ?? {};
  return {
    all: num(row.all_count) ?? 0,
    flagged: num(row.flagged_count) ?? 0,
    missingLabs: num(row.missing_labs_count) ?? 0,
    questionsWaiting: num(row.questions_waiting_count) ?? 0,
  };
}

export async function openPatientDetail(patientId: string): Promise<PatientDetail | null> {
  const { data, error } = await supabase.rpc('open_patient_detail', { p_patient_id: patientId });
  // An error (incl. RLS refusal) is indistinguishable from not-found by design.
  if (error) return null;
  return mapPatientDetail(data);
}

export async function fetchLatestResults(patientId: string): Promise<LatestResult[]> {
  const { data, error } = await supabase.rpc('patient_latest_results', { p_patient_id: patientId });
  if (error) throw error;
  return Array.isArray(data) ? (data as Raw[]).map(mapLatest) : [];
}

export async function fetchTrend(
  patientId: string,
  analyteKey: string,
  period: TrendPeriod
): Promise<TrendPoint[]> {
  const { data, error } = await supabase.rpc('patient_trend', {
    p_patient_id: patientId,
    p_analyte: analyteKey,
    p_period: PERIOD_TO_RPC[period],
  });
  if (error) throw error;
  return Array.isArray(data) ? (data as Raw[]).map(mapTrend) : [];
}

// The default, supabase-backed implementation the live routes use.
export const supabaseClinicalApi: ClinicalApi = {
  fetchRoster,
  fetchChipCounts,
  openPatientDetail,
  fetchLatestResults,
  fetchTrend,
};
