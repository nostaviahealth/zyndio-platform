/// <reference lib="deno.ns" />
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import {
  handleTreatmentEventsRequest,
  PatientRecord,
  TreatmentCourseRecord,
  TreatmentEventRecord,
  TreatmentStore,
} from './handler.ts'

function createSupabaseTreatmentStore(admin: SupabaseClient): TreatmentStore {
  return {
    async findPatient(patientId: string): Promise<PatientRecord | null> {
      const { data, error } = await admin
        .from('patients')
        .select('id, org_id')
        .eq('id', patientId)
        .maybeSingle()
      if (error || !data) return null
      return { id: String(data.id), org_id: String(data.org_id) }
    },

    async findEventByIdempotencyKey(
      orgId: string,
      idempotencyKey: string,
    ): Promise<TreatmentEventRecord | null> {
      const { data, error } = await admin
        .from('treatment_events')
        .select('*')
        .eq('org_id', orgId)
        .eq('idempotency_key', idempotencyKey)
        .maybeSingle()
      if (error || !data) return null
      return data as TreatmentEventRecord
    },

    async findLatestCourse(
      orgId: string,
      patientId: string,
    ): Promise<TreatmentCourseRecord | null> {
      const { data, error } = await admin
        .from('treatment_courses')
        .select('*')
        .eq('org_id', orgId)
        .eq('patient_id', patientId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (error || !data) return null
      return data as TreatmentCourseRecord
    },

    async findCourseById(courseId: string): Promise<TreatmentCourseRecord | null> {
      const { data, error } = await admin
        .from('treatment_courses')
        .select('*')
        .eq('id', courseId)
        .maybeSingle()
      if (error || !data) return null
      return data as TreatmentCourseRecord
    },

    async createCourse(
      input: Omit<TreatmentCourseRecord, 'id' | 'created_at' | 'updated_at'>,
    ): Promise<TreatmentCourseRecord> {
      const { data, error } = await admin
        .from('treatment_courses')
        .insert(input)
        .select('*')
        .single()
      if (error || !data) throw error ?? new Error('failed to create treatment_course')
      return data as TreatmentCourseRecord
    },

    async updateCourse(
      courseId: string,
      patch: Partial<
        Pick<
          TreatmentCourseRecord,
          'medication' | 'formulation' | 'current_dose_value' | 'current_dose_unit' | 'status'
        >
      >,
    ): Promise<TreatmentCourseRecord> {
      const { data, error } = await admin
        .from('treatment_courses')
        .update({ ...patch, updated_at: new Date().toISOString() })
        .eq('id', courseId)
        .select('*')
        .single()
      if (error || !data) throw error ?? new Error('failed to update treatment_course')
      return data as TreatmentCourseRecord
    },

    async createEvent(
      input: Omit<TreatmentEventRecord, 'id' | 'created_at'>,
    ): Promise<TreatmentEventRecord> {
      const { data, error } = await admin
        .from('treatment_events')
        .insert(input)
        .select('*')
        .single()
      if (error || !data) throw error ?? new Error('failed to create treatment_event')
      return data as TreatmentEventRecord
    },

    async listEvents(orgId: string, patientId: string): Promise<TreatmentEventRecord[]> {
      const { data, error } = await admin
        .from('treatment_events')
        .select('*')
        .eq('org_id', orgId)
        .eq('patient_id', patientId)
        .order('effective_at', { ascending: false })
        .order('created_at', { ascending: false })
      if (error || !data) return []
      return data as TreatmentEventRecord[]
    },

    async writeAuditLog(entry: {
      event_type: string
      actor_user_id: string | null
      target_user_id: string
      org_id: string
      metadata: Record<string, unknown>
    }): Promise<void> {
      await admin.rpc('write_audit_log', {
        p_event_type: entry.event_type,
        p_actor_user_id: entry.actor_user_id,
        p_target_user_id: entry.target_user_id,
        p_org_id: entry.org_id,
        p_metadata: entry.metadata,
      })
    },
  }
}

if (import.meta.main) {
  serve((req) => {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } },
    )
    return handleTreatmentEventsRequest(req, {
      store: createSupabaseTreatmentStore(admin),
      expectedBearerToken: Deno.env.get('PARTNER_API_TOKEN') ?? '',
    })
  })
}
