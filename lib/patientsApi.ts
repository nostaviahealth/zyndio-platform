import { supabase } from './supabase';
import { mapFunctionsInvokeError } from './functionsInvokeError';

export interface CreatePatientResult {
  ok: boolean;
  error?: string;
  field?: string;
  patientId?: string;
}

// TC-018 (Henry add-on, Create Patient): points the admin Create Patient
// page at the real patient model (create-patient Edge Function mints the
// auth user, then calls create_patient_record() under the caller's own
// JWT) instead of the removed profiles table. See
// supabase/functions/create-patient.
export async function createPatient(email: string, displayName: string, mrn?: string): Promise<CreatePatientResult> {
  const { data, error } = await supabase.functions.invoke('create-patient', {
    body: { email, display_name: displayName, mrn: mrn || undefined },
  });
  if (error) return { ok: false, ...(await mapFunctionsInvokeError(error)) };
  if (data?.error) return { ok: false, error: data.error as string, field: data.field as string | undefined };
  return { ok: true, patientId: data?.patient_id as string | undefined };
}
