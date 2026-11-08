import { supabase } from './supabase';
import { LabStatus, RangeSource, asRangeSource, asStatus, num, str } from './clinicalApi';

// POR-03 / POR-04 / POR-06 read model: patient_timeline, patient_previsit_brief,
// record_patient_visit, export_patient_record. Same rules as clinicalApi.ts:
// every payload goes through an explicit whitelist mapper, so a field the
// server should never send (a dose above all) cannot reach the UI or a file.

export type ExportFormat = 'json' | 'csv';

export interface TimelineResult {
  analyteKey: string;
  analyteLabel: string;
  value: number | null;
  originalValue: number | null;
  unit: string | null;
  status: LabStatus;
  rangeLow: number | null;
  rangeHigh: number | null;
  rangeSource: RangeSource;
}

export interface TimelineEvent {
  occurredAt: string;
  source: string;
  eventType: string;
  title: string;
  status: string | null;
  refId: string | null;
  // Known keys only (see mapTimelineDetail); never the raw server object.
  detail: {
    reportType?: string;
    resultCount?: number;
    outsideCount?: number;
    needsReviewCount?: number;
    results?: TimelineResult[];
    treatmentStatus?: string | null;
    treatmentSource?: string | null;
    visitOn?: string | null;
  };
}

export interface BriefMarker {
  analyteKey: string;
  analyteLabel: string;
  value: number | null;
  unit: string | null;
  takenAt: string | null;
  rangeLow: number | null;
  rangeHigh: number | null;
  rangeSource: RangeSource;
}

export interface BriefChange {
  analyteKey: string;
  analyteLabel: string;
  unit: string | null;
  baselineValue: number | null;
  baselineAt: string | null;
  latestValue: number | null;
  latestAt: string | null;
  delta: number | null;
  latestStatus: LabStatus;
}

export type MissingItem =
  | { code: 'no_labs' }
  | { code: 'no_labs_since_visit'; since: string | null }
  | { code: 'labs_stale'; latestAt: string | null; days: number | null }
  | { code: 'marker_not_rechecked'; analyteKey: string; analyteLabel: string; lastAt: string | null }
  | { code: 'no_treatment' };

export type SinceBasis = 'last_visit' | 'program_start' | 'first_result' | 'none';

export interface PrevisitBrief {
  patientId: string;
  generatedAt: string | null;
  since: { date: string | null; basis: SinceBasis };
  lastVisitOn: string | null;
  treatment: { name: string; status: string | null; startedOn: string | null } | null;
  counts: { resultsSince: number; markersSince: number };
  outOfRange: BriefMarker[];
  changes: BriefChange[];
  flags: { needsReview: number; identityHold: boolean; openQuestions: number };
  missing: MissingItem[];
}

export interface ExportLabRow {
  takenAt: string | null;
  analyteKey: string;
  analyteLabel: string;
  value: number | null;
  originalValue: number | null;
  unit: string | null;
  status: LabStatus;
  rangeLow: number | null;
  rangeHigh: number | null;
  rangeSource: RangeSource;
  rangeSetVersion: number | null;
  labReportId: string | null;
}

export interface PatientExport {
  schemaVersion: number;
  exportedAt: string | null;
  patient: {
    patientId: string;
    displayName: string;
    mrn: string;
    sex: string | null;
    birthDate: string | null;
    programStartedOn: string | null;
  };
  treatments: { name: string; startedOn: string | null; status: string | null; source: string | null }[];
  visits: { visitOn: string | null }[];
  labResults: ExportLabRow[];
}

export interface TimelineCursor {
  occurredAt: string;
  source: string;
  refId: string | null;
}

export interface PatientRecordApi {
  fetchTimeline(patientId: string, before?: string | TimelineCursor | null, limit?: number): Promise<TimelineEvent[]>;
  fetchBrief(patientId: string): Promise<PrevisitBrief | null>;
  recordVisit(patientId: string, visitOn?: string | null): Promise<void>;
  exportRecord(patientId: string, format: ExportFormat): Promise<PatientExport | null>;
}

type Raw = Record<string, unknown>;

const arr = (v: unknown): Raw[] => (Array.isArray(v) ? (v as Raw[]) : []);
const obj = (v: unknown): Raw => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Raw) : {});

function mapTimelineResult(r: Raw): TimelineResult {
  return {
    analyteKey: String(r.analyte_key ?? ''),
    analyteLabel: String(r.analyte_label ?? r.analyte_key ?? ''),
    value: num(r.value),
    originalValue: num(r.original_value),
    unit: str(r.unit),
    status: asStatus(r.status),
    rangeLow: num(r.range_low),
    rangeHigh: num(r.range_high),
    rangeSource: asRangeSource(r.range_source),
  };
}

function mapTimelineDetail(source: string, v: unknown): TimelineEvent['detail'] {
  const d = obj(v);
  if (source === 'labs') {
    return {
      reportType: str(d.report_type) ?? undefined,
      resultCount: num(d.result_count) ?? 0,
      outsideCount: num(d.outside_count) ?? 0,
      needsReviewCount: num(d.needs_review_count) ?? 0,
      results: arr(d.results).map(mapTimelineResult),
    };
  }
  if (source === 'treatment') {
    return { treatmentStatus: str(d.status), treatmentSource: str(d.source) };
  }
  if (source === 'visits') {
    return { visitOn: str(d.visit_on) };
  }
  return {};
}

export function mapTimelineEvent(r: Raw): TimelineEvent {
  const source = String(r.source ?? '');
  return {
    occurredAt: String(r.occurred_at ?? ''),
    source,
    eventType: String(r.event_type ?? ''),
    title: String(r.title ?? ''),
    status: str(r.status),
    refId: str(r.ref_id),
    detail: mapTimelineDetail(source, r.detail),
  };
}

function mapBriefMarker(r: Raw): BriefMarker {
  return {
    analyteKey: String(r.analyte_key ?? ''),
    analyteLabel: String(r.analyte_label ?? r.analyte_key ?? ''),
    value: num(r.value),
    unit: str(r.unit),
    takenAt: str(r.taken_at),
    rangeLow: num(r.range_low),
    rangeHigh: num(r.range_high),
    rangeSource: asRangeSource(r.range_source),
  };
}

function mapMissing(r: Raw): MissingItem | null {
  switch (r.code) {
    case 'no_labs':
      return { code: 'no_labs' };
    case 'no_labs_since_visit':
      return { code: 'no_labs_since_visit', since: str(r.since) };
    case 'labs_stale':
      return { code: 'labs_stale', latestAt: str(r.latest_at), days: num(r.days) };
    case 'marker_not_rechecked':
      return {
        code: 'marker_not_rechecked',
        analyteKey: String(r.analyte_key ?? ''),
        analyteLabel: String(r.analyte_label ?? r.analyte_key ?? ''),
        lastAt: str(r.last_at),
      };
    case 'no_treatment':
      return { code: 'no_treatment' };
    default:
      // Unknown codes are dropped: the brief only ever shows fixed wording.
      return null;
  }
}

function asBasis(v: unknown): SinceBasis {
  return v === 'last_visit' || v === 'program_start' || v === 'first_result' ? v : 'none';
}

export function mapBrief(v: unknown): PrevisitBrief | null {
  if (!v || typeof v !== 'object') return null;
  const d = v as Raw;
  if (!d.patient_id) return null;
  const since = obj(d.since);
  const counts = obj(d.counts);
  const flags = obj(d.flags);
  const t = d.treatment ? obj(d.treatment) : null;
  return {
    patientId: String(d.patient_id),
    generatedAt: str(d.generated_at),
    since: { date: str(since.date), basis: asBasis(since.basis) },
    lastVisitOn: str(d.last_visit_on),
    treatment: t ? { name: String(t.name ?? ''), status: str(t.status), startedOn: str(t.started_on) } : null,
    counts: { resultsSince: num(counts.results_since) ?? 0, markersSince: num(counts.markers_since) ?? 0 },
    outOfRange: arr(d.out_of_range).map(mapBriefMarker),
    changes: arr(d.changes).map((c) => ({
      analyteKey: String(c.analyte_key ?? ''),
      analyteLabel: String(c.analyte_label ?? c.analyte_key ?? ''),
      unit: str(c.unit),
      baselineValue: num(c.baseline_value),
      baselineAt: str(c.baseline_at),
      latestValue: num(c.latest_value),
      latestAt: str(c.latest_at),
      delta: num(c.delta),
      latestStatus: asStatus(c.latest_status),
    })),
    flags: {
      needsReview: num(flags.needs_review) ?? 0,
      identityHold: flags.identity_hold === true,
      openQuestions: num(flags.open_questions) ?? 0,
    },
    missing: arr(d.missing)
      .map(mapMissing)
      .filter((m): m is MissingItem => m !== null),
  };
}

export function mapExport(v: unknown): PatientExport | null {
  if (!v || typeof v !== 'object') return null;
  const d = v as Raw;
  const p = obj(d.patient);
  if (!p.patient_id) return null;
  return {
    schemaVersion: num(d.schema_version) ?? 1,
    exportedAt: str(d.exported_at),
    patient: {
      patientId: String(p.patient_id),
      displayName: String(p.display_name ?? ''),
      mrn: String(p.mrn ?? ''),
      sex: str(p.sex),
      birthDate: str(p.birth_date),
      programStartedOn: str(p.program_started_on),
    },
    // name / started_on / status / source only - never a dose.
    treatments: arr(d.treatments).map((t) => ({
      name: String(t.name ?? ''),
      startedOn: str(t.started_on),
      status: str(t.status),
      source: str(t.source),
    })),
    visits: arr(d.visits).map((x) => ({ visitOn: str(x.visit_on) })),
    labResults: arr(d.lab_results).map((r) => ({
      takenAt: str(r.taken_at),
      analyteKey: String(r.analyte_key ?? ''),
      analyteLabel: String(r.analyte_label ?? r.analyte_key ?? ''),
      value: num(r.value),
      originalValue: num(r.original_value),
      unit: str(r.unit),
      status: asStatus(r.status),
      rangeLow: num(r.range_low),
      rangeHigh: num(r.range_high),
      rangeSource: asRangeSource(r.range_source),
      rangeSetVersion: num(r.range_set_version),
      labReportId: str(r.lab_report_id),
    })),
  };
}

export async function fetchTimeline(
  patientId: string,
  before: string | TimelineCursor | null = null,
  limit = 200,
): Promise<TimelineEvent[]> {
  const cursor = typeof before === 'object' && before !== null ? before : null;
  const { data, error } = await supabase.rpc('patient_timeline', {
    p_patient_id: patientId,
    p_before: cursor ? cursor.occurredAt : before,
    p_before_source: cursor?.source ?? null,
    p_before_ref: cursor?.refId ?? null,
    p_limit: limit,
  });
  if (error) throw error;
  return arr(data).map(mapTimelineEvent);
}

export async function fetchBrief(patientId: string): Promise<PrevisitBrief | null> {
  const { data, error } = await supabase.rpc('patient_previsit_brief', { p_patient_id: patientId });
  if (error) throw error;
  return mapBrief(data);
}

export async function recordVisit(patientId: string, visitOn: string | null = null): Promise<void> {
  const { error } = await supabase.rpc('record_patient_visit', { p_patient_id: patientId, p_visit_on: visitOn });
  if (error) throw error;
}

export async function exportRecord(patientId: string, format: ExportFormat): Promise<PatientExport | null> {
  const { data, error } = await supabase.rpc('export_patient_record', { p_patient_id: patientId, p_format: format });
  if (error) throw error;
  return mapExport(data);
}

export const supabasePatientRecordApi: PatientRecordApi = {
  fetchTimeline,
  fetchBrief,
  recordVisit,
  exportRecord,
};
