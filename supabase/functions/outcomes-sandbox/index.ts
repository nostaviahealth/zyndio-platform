import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient, SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0';
import {
  BodyCompositionScanRow,
  OutcomeRecordRow,
  OutcomesSandboxStore,
  PartnerWebhookEvent,
  handleOutcomesSandboxRequest,
} from './handler.ts';

function createSupabaseOutcomesStore(client: SupabaseClient): OutcomesSandboxStore {
  return {
    async findPatientByZyndioId(orgId: string, zyndioPatientId: string) {
      // Match by MRN or UUID within the partner's organization
      const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        zyndioPatientId
      );
      const query = client
        .from('patients')
        .select('id, mrn')
        .eq('org_id', orgId);

      const { data, error } = isUuid
        ? await query.eq('id', zyndioPatientId).maybeSingle()
        : await query.eq('mrn', zyndioPatientId).maybeSingle();

      if (error || !data) return null;
      return { id: String(data.id), mrn: data.mrn ? String(data.mrn) : null };
    },

    async findScanByVersion(orgId: string, partnerScanId: string, partnerScanVersion: number) {
      const { data, error } = await client
        .from('body_composition_scans')
        .select('*')
        .eq('org_id', orgId)
        .eq('partner_scan_id', partnerScanId)
        .eq('partner_scan_version', partnerScanVersion)
        .maybeSingle();

      if (error || !data) return null;
      return data as BodyCompositionScanRow;
    },

    async insertScan(row) {
      const { data, error } = await client
        .from('body_composition_scans')
        .insert(row)
        .select('*')
        .single();
      if (error) throw new Error(`insertScan failed: ${error.message}`);
      return data as BodyCompositionScanRow;
    },

    async findOutcomeRecord(orgId: string, recordId: string) {
      const { data, error } = await client
        .from('outcome_records')
        .select('*')
        .eq('org_id', orgId)
        .eq('record_id', recordId)
        .maybeSingle();
      if (error || !data) return null;
      return data as OutcomeRecordRow;
    },

    async listReleasedOutcomeRecords(orgId: string, updatedSince?: string | null) {
      let q = client
        .from('outcome_records')
        .select('*')
        .eq('org_id', orgId)
        .in('state', ['approved', 'delivered'])
        .eq('clinical_context_flag', false)
        .order('updated_at', { ascending: true });

      if (updatedSince) {
        q = q.gte('updated_at', updatedSince);
      }
      const { data, error } = await q;
      if (error) throw new Error(`listReleasedOutcomeRecords failed: ${error.message}`);
      return (data ?? []) as OutcomeRecordRow[];
    },

    async markOutcomeDelivered(orgId: string, recordId: string) {
      const { error } = await client
        .from('outcome_records')
        .update({ state: 'delivered', updated_at: new Date().toISOString() })
        .eq('org_id', orgId)
        .eq('record_id', recordId)
        .eq('state', 'approved');
      if (error) throw new Error(`markOutcomeDelivered failed: ${error.message}`);
    },

    async emitPartnerEvent(event: PartnerWebhookEvent) {
      const { error } = await client.from('notification_outbox').insert({
        org_id: event.org_id,
        type: event.event_type,
        status: 'pending',
        payload: event.payload,
      });
      if (error) throw new Error(`emitPartnerEvent failed: ${error.message}`);
    },
  };
}

if (import.meta.main) {
  serve((req) => {
    const client = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    return handleOutcomesSandboxRequest(req, {
      env: Deno.env,
      store: createSupabaseOutcomesStore(client),
    });
  });
}
