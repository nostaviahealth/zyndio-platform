import { supabase } from './supabase';

export interface LatestLabReport {
  id: string;
  report_type: string;
  needs_review: boolean;
  flagged_at: string | null;
  created_at: string;
}

// Flag-only review path (TC-011 M2): a care_coordinator has no UPDATE grant
// on lab_reports at all, so this is the only way they can raise "Needs
// review" - it can never touch `data` or confirm a value, which stays
// physician-only (see 20261027110000_tc011_lab_review_flag.sql).
export async function flagLabReportNeedsReview(labReportId: string): Promise<{ ok: boolean; error?: string }> {
  const { error } = await supabase.rpc('flag_lab_report_needs_review', { p_lab_report_id: labReportId });
  if (error) return { ok: false, error: error.code === '42501' ? 'forbidden' : error.message };
  return { ok: true };
}

export async function getLatestLabReport(patientId: string): Promise<LatestLabReport | null> {
  const { data, error } = await supabase
    .from('lab_reports')
    .select('id, report_type, needs_review, flagged_at, created_at')
    .eq('patient_id', patientId)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  if (error || !data) return null;
  return data as LatestLabReport;
}
