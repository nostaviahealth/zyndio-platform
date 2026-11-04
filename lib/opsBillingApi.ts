import { supabase } from './supabase';

export type QualifyingReason = 'sign_in' | 'data_processed';
export type IncidentSeverity = 'P1' | 'P2' | 'P3';
export type IncidentStatus = 'confirmed' | 'notified' | 'resolved';

export interface ScheduleBTierBreakdown {
  tier_1001_2500_patients: number;
  tier_1001_2500_cents: number;
  tier_2501_10000_patients: number;
  tier_2501_10000_cents: number;
  tier_10001_plus_patients: number;
  tier_10001_plus_cents: number;
}

export interface MonthlyUsageSummary {
  org_id: string;
  month: string;
  active_patients_total: number;
  sign_in_count: number;
  data_processed_count: number;
  included_patients: number;
  billable_overage_patients: number;
  overage_fee_cents: number;
  overage_fee_usd: number;
  tiers: ScheduleBTierBreakdown;
}

export interface TerminationExportPatientItem {
  patient_id: string;
  patient_ref: string;
  profile_count: number;
  lab_report_count: number;
  consent_count: number;
}

export interface TerminationExportDocumentItem {
  report_id: string;
  patient_id: string;
  report_type: string;
  storage_bucket: string;
  storage_path: string;
  created_at: string;
}

export interface TerminationExportManifest {
  schema_version: string;
  clause: string;
  org_id: string;
  patient_count: number;
  lab_report_count: number;
  patients: TerminationExportPatientItem[];
  documents: TerminationExportDocumentItem[];
  sha256_manifest: string;
}

export interface OrgTerminationExport {
  id: string;
  org_id: string;
  requested_by: string;
  requested_at: string;
  due_at: string;
  readonly_until: string;
  status: 'pending' | 'completed';
  manifest: TerminationExportManifest;
}

export interface PatientLegalHold {
  patient_id: string;
  org_id: string;
  reason: string;
  placed_by: string;
  placed_at: string;
}

export interface DeletionSummary {
  deleted_lab_reports: number;
  deleted_profiles: number;
  deleted_consents: number;
  pii_scrubbed: boolean;
}

export interface PatientDeletionConfirmation {
  id: string;
  org_id: string;
  patient_ref: string;
  deleted_by: string;
  deleted_at: string;
  confirmation_code: string;
  certificate_sha256: string;
  summary: DeletionSummary;
}

export interface SecurityIncident {
  id: string;
  org_id: string;
  severity: IncidentSeverity;
  title: string;
  summary: string;
  confirmed_at: string;
  notify_deadline_at: string;
  notified_at: string | null;
  status: IncidentStatus;
  created_by: string;
  within_72h_sla?: boolean;
}

/**
 * Deterministic Schedule B tiered overage pricing calculator (PP-02):
 *  - 1 to 1,000 active patients: Included in base subscription ($0.00)
 *  - 1,001 to 2,500 active patients: $0.50 (50 cents) per active patient
 *  - 2,501 to 10,000 active patients: $0.35 (35 cents) per active patient
 *  - 10,001+ active patients: $0.25 (25 cents) per active patient
 */
export function calculateScheduleBOverage(activePatientsTotal: number): {
  included_patients: number;
  billable_overage_patients: number;
  overage_fee_cents: number;
  overage_fee_usd: number;
  tiers: ScheduleBTierBreakdown;
} {
  const total = Math.max(0, Math.floor(activePatientsTotal));
  const included = 1000;
  const overage = Math.max(0, total - included);

  const tier1Patients = Math.max(0, Math.min(total, 2500) - 1000);
  const tier1Cents = tier1Patients * 50;

  const tier2Patients = Math.max(0, Math.min(total, 10000) - 2500);
  const tier2Cents = tier2Patients * 35;

  const tier3Patients = Math.max(0, total - 10000);
  const tier3Cents = tier3Patients * 25;

  const overageFeeCents = tier1Cents + tier2Cents + tier3Cents;
  const overageFeeUsd = Number((overageFeeCents / 100).toFixed(2));

  return {
    included_patients: included,
    billable_overage_patients: overage,
    overage_fee_cents: overageFeeCents,
    overage_fee_usd: overageFeeUsd,
    tiers: {
      tier_1001_2500_patients: tier1Patients,
      tier_1001_2500_cents: tier1Cents,
      tier_2501_10000_patients: tier2Patients,
      tier_2501_10000_cents: tier2Cents,
      tier_10001_plus_patients: tier3Patients,
      tier_10001_plus_cents: tier3Cents,
    },
  };
}

export async function getOrgMonthlyUsageSummary(month?: string): Promise<MonthlyUsageSummary> {
  const args = month ? { p_month: month } : {};
  const { data, error } = await supabase.rpc('get_org_monthly_usage_summary', args);
  if (error) throw error;
  return data as MonthlyUsageSummary;
}

export async function recordPatientMonthlyActivity(
  patientId: string,
  reason: QualifyingReason,
  occurredAt?: string
): Promise<{
  id: string;
  org_id: string;
  month: string;
  patient_id: string;
  qualifying_reason: QualifyingReason;
  first_qualified_at: string;
}> {
  const { data, error } = await supabase.rpc('record_patient_monthly_activity', {
    p_patient_id: patientId,
    p_reason: reason,
    ...(occurredAt ? { p_occurred_at: occurredAt } : {}),
  });
  if (error) throw error;
  return data;
}

export async function requestOrgTerminationExport(): Promise<OrgTerminationExport> {
  const { data, error } = await supabase.rpc('request_org_termination_export');
  if (error) throw error;
  return data as OrgTerminationExport;
}

export async function listOrgTerminationExports(): Promise<OrgTerminationExport[]> {
  const { data, error } = await supabase
    .from('org_termination_exports')
    .select('*')
    .order('requested_at', { ascending: false });
  if (error) throw error;
  return (data ?? []) as OrgTerminationExport[];
}

export async function setPatientLegalHold(
  patientId: string,
  hold: boolean,
  reason?: string
): Promise<{ patient_id: string; org_id: string; hold: boolean; reason: string | null }> {
  const { data, error } = await supabase.rpc('set_patient_legal_hold', {
    p_patient_id: patientId,
    p_hold: hold,
    p_reason: hold ? reason?.trim() ?? null : null,
  });
  if (error) throw error;
  return data;
}

export async function confirmPatientDataDeletion(
  patientId: string
): Promise<PatientDeletionConfirmation> {
  const { data, error } = await supabase.rpc('confirm_patient_data_deletion', {
    p_patient_id: patientId,
  });
  if (error) throw error;
  return data as PatientDeletionConfirmation;
}

export async function listPatientLegalHolds(): Promise<PatientLegalHold[]> {
  const { data, error } = await supabase
    .from('patient_legal_holds')
    .select('*')
    .order('placed_at', { ascending: false });
  if (error) throw error;
  return (data ?? []) as PatientLegalHold[];
}

export async function listPatientDeletionConfirmations(): Promise<PatientDeletionConfirmation[]> {
  const { data, error } = await supabase
    .from('patient_deletion_confirmations')
    .select('*')
    .order('deleted_at', { ascending: false });
  if (error) throw error;
  return (data ?? []) as PatientDeletionConfirmation[];
}

export async function reportSecurityIncident(
  severity: IncidentSeverity,
  title: string,
  summary: string,
  notifyNow = true
): Promise<SecurityIncident> {
  const { data, error } = await supabase.rpc('report_security_incident', {
    p_severity: severity,
    p_title: title.trim(),
    p_summary: summary.trim(),
    p_notify_now: notifyNow,
  });
  if (error) throw error;
  return data as SecurityIncident;
}

export async function listSecurityIncidents(): Promise<SecurityIncident[]> {
  const { data, error } = await supabase
    .from('security_incidents')
    .select('*')
    .order('confirmed_at', { ascending: false });
  if (error) throw error;
  return (data ?? []) as SecurityIncident[];
}
