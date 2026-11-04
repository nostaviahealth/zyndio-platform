import { supabase } from './supabase';

// POR-07 & INT-04: GLP-1 Treatment Context & Chronological Events API.
// Clause 9.1 (No-Dose-Suggestion Rule): Zyndio records clinician- or partner-
// entered treatment history as decision-support context only and never
// computes or recommends a medication dose.

export type TreatmentEventType =
  | 'medication_start'
  | 'dose_change'
  | 'status_change'
  | 'tolerability_note'
  | 'clinician_change';

export type TreatmentCourseStatus = 'active' | 'paused' | 'discontinued' | 'completed';

export interface TreatmentCourse {
  id: string;
  orgId: string;
  patientId: string;
  medication: string;
  formulation: string;
  currentDoseValue: number | null;
  currentDoseUnit: string | null;
  startDate: string;
  status: TreatmentCourseStatus;
  updatedAt: string;
}

export interface TreatmentEvent {
  id: string;
  courseId: string;
  patientId: string;
  eventType: TreatmentEventType;
  doseValue: number | null;
  doseUnit: string | null;
  statusValue: TreatmentCourseStatus | null;
  note: string | null;
  effectiveAt: string;
  enteredBy: string | null;
  source: 'portal' | 'api';
  idempotencyKey: string | null;
  createdAt: string;
}

export interface PatientTreatmentContext {
  patientId: string;
  course: TreatmentCourse | null;
  events: TreatmentEvent[];
}

export interface RecordTreatmentEventInput {
  patientId: string;
  eventType: TreatmentEventType;
  medication?: string | null;
  formulation?: string | null;
  doseValue?: number | null;
  doseUnit?: string | null;
  statusValue?: TreatmentCourseStatus | null;
  note?: string | null;
  effectiveAt?: string | null;
  idempotencyKey?: string | null;
}

export interface RecordTreatmentEventResult {
  replayed: boolean;
  course: TreatmentCourse;
  event: TreatmentEvent;
}

export interface TreatmentApi {
  fetchTreatmentContext(patientId: string): Promise<PatientTreatmentContext | null>;
  recordTreatmentEvent(input: RecordTreatmentEventInput): Promise<RecordTreatmentEventResult>;
}

type Raw = Record<string, unknown>;

function num(v: unknown): number | null {
  if (v === null || v === undefined || v === '') return null;
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

function str(v: unknown): string | null {
  return v === null || v === undefined ? null : String(v);
}

function asCourseStatus(v: unknown): TreatmentCourseStatus {
  const s = String(v);
  if (s === 'active' || s === 'paused' || s === 'discontinued' || s === 'completed') {
    return s;
  }
  return 'active';
}

function asEventType(v: unknown): TreatmentEventType {
  const s = String(v);
  if (
    s === 'medication_start' ||
    s === 'dose_change' ||
    s === 'status_change' ||
    s === 'tolerability_note' ||
    s === 'clinician_change'
  ) {
    return s;
  }
  return 'tolerability_note';
}

export function mapTreatmentCourse(v: unknown): TreatmentCourse | null {
  if (!v || typeof v !== 'object') return null;
  const r = v as Raw;
  if (!r.id) return null;
  return {
    id: String(r.id),
    orgId: String(r.org_id ?? ''),
    patientId: String(r.patient_id ?? ''),
    medication: String(r.medication ?? ''),
    formulation: String(r.formulation ?? ''),
    currentDoseValue: num(r.current_dose_value),
    currentDoseUnit: str(r.current_dose_unit),
    startDate: String(r.start_date ?? ''),
    status: asCourseStatus(r.status),
    updatedAt: String(r.updated_at ?? ''),
  };
}

export function mapTreatmentEvent(v: unknown): TreatmentEvent {
  const r = (v ?? {}) as Raw;
  return {
    id: String(r.id ?? ''),
    courseId: String(r.course_id ?? ''),
    patientId: String(r.patient_id ?? ''),
    eventType: asEventType(r.event_type),
    doseValue: num(r.dose_value),
    doseUnit: str(r.dose_unit),
    statusValue: r.status_value ? asCourseStatus(r.status_value) : null,
    note: str(r.note),
    effectiveAt: String(r.effective_at ?? ''),
    enteredBy: str(r.entered_by),
    source: r.source === 'api' ? 'api' : 'portal',
    idempotencyKey: str(r.idempotency_key),
    createdAt: String(r.created_at ?? ''),
  };
}

export async function fetchTreatmentContext(
  patientId: string
): Promise<PatientTreatmentContext | null> {
  const { data, error } = await supabase.rpc('get_patient_treatment_context', {
    p_patient_id: patientId,
  });
  if (error || !data || typeof data !== 'object') return null;
  const raw = data as Raw;
  if (!raw.patient_id) return null;
  const eventsRaw = Array.isArray(raw.events) ? raw.events : [];
  return {
    patientId: String(raw.patient_id),
    course: mapTreatmentCourse(raw.course),
    events: eventsRaw.map(mapTreatmentEvent),
  };
}

export async function recordTreatmentEvent(
  input: RecordTreatmentEventInput
): Promise<RecordTreatmentEventResult> {
  const { data, error } = await supabase.rpc('record_patient_treatment_event', {
    p_patient_id: input.patientId,
    p_event_type: input.eventType,
    p_medication: input.medication ?? null,
    p_formulation: input.formulation ?? '',
    p_dose_value: input.doseValue ?? null,
    p_dose_unit: input.doseUnit ?? null,
    p_status_value: input.statusValue ?? null,
    p_note: input.note ?? null,
    p_effective_at: input.effectiveAt ?? new Date().toISOString(),
    p_idempotency_key: input.idempotencyKey ?? null,
  });
  if (error) throw error;
  const raw = (data ?? {}) as Raw;
  const course = mapTreatmentCourse(raw.course);
  if (!course) {
    throw new Error('Invalid course payload returned from record_patient_treatment_event');
  }
  return {
    replayed: raw.replayed === true,
    course,
    event: mapTreatmentEvent(raw.event),
  };
}

export const supabaseTreatmentApi: TreatmentApi = {
  fetchTreatmentContext,
  recordTreatmentEvent,
};
