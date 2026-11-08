import {
  assertCleanOutboundOutcomeRecord,
  formatEventId,
  hmacSha256Hex,
} from '../_shared/outcomesEngine.ts';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-partner-org-id',
};

export interface PartnerWebhookEvent {
  event_id: string;
  event_type: 'measurement.unmatched' | 'outcomes.milestone.ready' | 'outcomes.milestone.corrected';
  org_id: string;
  created_at: string;
  payload: Record<string, unknown>;
}

export interface BodyCompositionScanRow {
  id: string;
  org_id: string;
  patient_id: string | null;
  zyndio_patient_id: string | null;
  partner_patient_id: string;
  partner_scan_id: string;
  partner_scan_version: number;
  scan_date: string;
  site_id: string | null;
  device_vendor: string;
  device_model: string;
  software_version: string;
  measures: Record<string, unknown>;
  binding_status: 'bound' | 'unmatched' | 'rejected';
  created_at: string;
}

export interface OutcomeRecordRow {
  id: string;
  record_id: string;
  org_id: string;
  patient_id: string;
  milestone: string;
  record_version: number;
  rules_version: string;
  state: 'computed' | 'in_review' | 'approved' | 'held' | 'sent_back' | 'delivered' | 'withdrawn';
  lean_mass_flag: 'none' | 'watch' | 'flagged';
  clinical_context_flag: boolean;
  clinician_summary: string;
  payload: Record<string, unknown>;
  approved_by: string | null;
  approved_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface OutcomesSandboxStore {
  findPatientByZyndioId(orgId: string, zyndioPatientId: string): Promise<{ id: string; mrn: string | null } | null>;
  findScanByVersion(
    orgId: string,
    partnerScanId: string,
    partnerScanVersion: number
  ): Promise<BodyCompositionScanRow | null>;
  insertScan(
    row: Omit<BodyCompositionScanRow, 'id' | 'created_at'>
  ): Promise<BodyCompositionScanRow>;
  findOutcomeRecord(orgId: string, recordId: string): Promise<OutcomeRecordRow | null>;
  listReleasedOutcomeRecords(orgId: string, updatedSince?: string | null): Promise<OutcomeRecordRow[]>;
  markOutcomeDelivered(orgId: string, recordId: string): Promise<void>;
  emitPartnerEvent(event: PartnerWebhookEvent): Promise<void>;
}

export interface OutcomesSandboxDeps {
  env: { get(key: string): string | undefined };
  store: OutcomesSandboxStore;
  now?: () => Date;
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function constantTimeEquals(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const aBytes = enc.encode(a);
  const bBytes = enc.encode(b);
  if (aBytes.length !== bBytes.length) return false;
  let diff = 0;
  for (let i = 0; i < aBytes.length; i++) {
    diff |= aBytes[i] ^ bBytes[i];
  }
  return diff === 0;
}

function authenticatePartnerRequest(
  req: Request,
  env: { get(key: string): string | undefined }
): { authorized: boolean; orgId: string; partnerSecret: string } {
  const expectedKey = env.get('OUTCOMES_PARTNER_API_KEY') ?? '';
  const partnerSecret = env.get('OUTCOMES_PARTNER_SECRET') ?? expectedKey;
  const defaultOrgId = env.get('OUTCOMES_PARTNER_ORG_ID') ?? '00000000-0000-0000-0000-00000000000a';

  if (!expectedKey) {
    return { authorized: false, orgId: defaultOrgId, partnerSecret: '' };
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7).trim() : authHeader.trim();
  if (!token || !constantTimeEquals(token, expectedKey)) {
    return { authorized: false, orgId: defaultOrgId, partnerSecret: '' };
  }

  const headerOrgId = req.headers.get('X-Partner-Org-Id')?.trim();
  return {
    authorized: true,
    orgId: headerOrgId || defaultOrgId,
    partnerSecret,
  };
}

function deriveIngestionId(
  partnerSecret: string,
  orgId: string,
  partnerScanId: string,
  partnerScanVersion: number
): string {
  const digest = hmacSha256Hex(partnerSecret, `ing:${orgId}:${partnerScanId}:v${partnerScanVersion}`).slice(0, 24);
  return `ing_${digest}`;
}

function deriveEventId(partnerSecret: string, seed: string): string {
  const digest = hmacSha256Hex(partnerSecret, `evt:${seed}`).slice(0, 24);
  return formatEventId(digest);
}

/**
 * Handles INT-05 and INT-06 routes for the Phase 2 (C2) Outcomes & DEXASCAN Sandbox:
 * - POST /v1/measurements/body-composition
 * - POST /v1/measurements/body-composition/documents
 * - GET  /v1/outcomes/{record_id}
 * - GET  /v1/outcomes?updated_since=
 * - POST /v1/outcomes/{record_id}/redeliver
 */
export async function handleOutcomesSandboxRequest(
  req: Request,
  deps: OutcomesSandboxDeps
): Promise<Response> {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const auth = authenticatePartnerRequest(req, deps.env);
  if (!auth.authorized) {
    return jsonResponse({ error: 'unauthorized' }, 401);
  }

  const url = new URL(req.url);
  // Normalize path to allow either /v1/... or /outcomes-sandbox/v1/...
  const path = url.pathname.replace(/^\/outcomes-sandbox(?=\/)/, '');
  const nowIso = (deps.now ? deps.now() : new Date()).toISOString();

  // -------------------------------------------------------------------------
  // INT-05: POST /v1/measurements/body-composition & /documents
  // -------------------------------------------------------------------------
  if (
    req.method === 'POST' &&
    (path === '/v1/measurements/body-composition' ||
      path === '/v1/measurements/body-composition/documents')
  ) {
    const isDocumentRoute = path.endsWith('/documents');
    let body: Record<string, unknown>;
    try {
      body = (await req.json()) as Record<string, unknown>;
    } catch {
      return jsonResponse({ error: 'invalid_json' }, 400);
    }

    const partner_patient_id = typeof body.partner_patient_id === 'string' ? body.partner_patient_id.trim() : '';
    const partner_scan_id = typeof body.partner_scan_id === 'string' ? body.partner_scan_id.trim() : '';
    const partner_scan_version =
      typeof body.partner_scan_version === 'number' && Number.isInteger(body.partner_scan_version) && body.partner_scan_version >= 1
        ? body.partner_scan_version
        : 1;
    const scan_date = typeof body.scan_date === 'string' ? body.scan_date.trim() : '';
    const site_id = typeof body.site_id === 'string' ? body.site_id.trim() : null;
    const zyndio_patient_id =
      typeof body.zyndio_patient_id === 'string' && body.zyndio_patient_id.trim().length > 0
        ? body.zyndio_patient_id.trim()
        : null;

    const scannerObj =
      body.scanner && typeof body.scanner === 'object'
        ? (body.scanner as Record<string, unknown>)
        : body;

    const device_vendor =
      typeof scannerObj.device_vendor === 'string'
        ? scannerObj.device_vendor.trim()
        : typeof scannerObj.vendor === 'string'
        ? scannerObj.vendor.trim()
        : '';
    const device_model =
      typeof scannerObj.device_model === 'string'
        ? scannerObj.device_model.trim()
        : typeof scannerObj.model === 'string'
        ? scannerObj.model.trim()
        : '';
    const software_version =
      typeof scannerObj.software_version === 'string' ? scannerObj.software_version.trim() : '';

    if (!partner_patient_id || !partner_scan_id || !/^\d{4}-\d{2}-\d{2}$/.test(scan_date)) {
      return jsonResponse(
        {
          error: 'validation_error',
          message: 'partner_patient_id, partner_scan_id, and scan_date (YYYY-MM-DD) are required',
        },
        400
      );
    }

    if (!device_vendor || !device_model || !software_version) {
      return jsonResponse(
        {
          error: 'validation_error',
          message: 'device_vendor, device_model, and software_version are required',
        },
        400
      );
    }

    let measures: Record<string, unknown>;
    if (isDocumentRoute) {
      const document_sha256 = typeof body.document_sha256 === 'string' ? body.document_sha256.trim() : '';
      const document_url = typeof body.document_url === 'string' ? body.document_url.trim() : '';
      const content_type = typeof body.content_type === 'string' ? body.content_type.trim() : 'application/pdf';
      if (!document_sha256 && !document_url) {
        return jsonResponse(
          {
            error: 'validation_error',
            message: 'document_sha256 or document_url is required for document ingestion',
          },
          400
        );
      }
      const rawMeasures =
        body.measures && typeof body.measures === 'object' && !Array.isArray(body.measures)
          ? (body.measures as Record<string, unknown>)
          : {};
      measures = {
        ...rawMeasures,
        document: {
          document_sha256: document_sha256 || null,
          document_url: document_url || null,
          content_type,
        },
      };
    } else {
      if (!body.measures || typeof body.measures !== 'object' || Array.isArray(body.measures)) {
        return jsonResponse(
          {
            error: 'validation_error',
            message: 'measures object is required',
          },
          400
        );
      }
      measures = body.measures as Record<string, unknown>;
    }

    const ingestion_id = deriveIngestionId(
      auth.partnerSecret,
      auth.orgId,
      partner_scan_id,
      partner_scan_version
    );

    // Idempotency check on (org_id, partner_scan_id, partner_scan_version)
    const existing = await deps.store.findScanByVersion(
      auth.orgId,
      partner_scan_id,
      partner_scan_version
    );
    if (existing) {
      return jsonResponse(
        {
          ingestion_id,
          status: 'received',
          binding_status: existing.binding_status,
          partner_scan_id,
          partner_scan_version,
          idempotent_replay: true,
        },
        202
      );
    }

    // Match zyndio_patient_id to known clinic patient in org
    let matchedPatient: { id: string; mrn: string | null } | null = null;
    if (zyndio_patient_id) {
      matchedPatient = await deps.store.findPatientByZyndioId(auth.orgId, zyndio_patient_id);
    }

    const binding_status: 'bound' | 'unmatched' = matchedPatient ? 'bound' : 'unmatched';

    await deps.store.insertScan({
      org_id: auth.orgId,
      patient_id: matchedPatient ? matchedPatient.id : null,
      zyndio_patient_id,
      partner_patient_id,
      partner_scan_id,
      partner_scan_version,
      scan_date,
      site_id,
      device_vendor,
      device_model,
      software_version,
      measures,
      binding_status,
    });

    if (binding_status === 'unmatched') {
      const event_id = deriveEventId(
        auth.partnerSecret,
        `unmatched:${auth.orgId}:${partner_scan_id}:v${partner_scan_version}`
      );
      await deps.store.emitPartnerEvent({
        event_id,
        event_type: 'measurement.unmatched',
        org_id: auth.orgId,
        created_at: nowIso,
        payload: {
          event_id,
          event_type: 'measurement.unmatched',
          ingestion_id,
          partner_patient_id,
          zyndio_patient_id,
          partner_scan_id,
          partner_scan_version,
          scan_date,
          reason: zyndio_patient_id ? 'unknown_zyndio_patient_id' : 'missing_zyndio_patient_id',
        },
      });

      return jsonResponse(
        {
          ingestion_id,
          status: 'received',
          binding_status: 'unmatched',
          unmatched_event_id: event_id,
          partner_scan_id,
          partner_scan_version,
          idempotent_replay: false,
        },
        202
      );
    }

    return jsonResponse(
      {
        ingestion_id,
        status: 'received',
        binding_status: 'bound',
        partner_scan_id,
        partner_scan_version,
        idempotent_replay: false,
      },
      202
    );
  }

  // -------------------------------------------------------------------------
  // INT-06: GET /v1/outcomes?updated_since=
  // -------------------------------------------------------------------------
  if (req.method === 'GET' && path === '/v1/outcomes') {
    const updatedSince = url.searchParams.get('updated_since');
    if (updatedSince && Number.isNaN(Date.parse(updatedSince))) {
      return jsonResponse({ error: 'invalid_updated_since' }, 400);
    }

    const rows = await deps.store.listReleasedOutcomeRecords(auth.orgId, updatedSince);
    const records = [];
    for (const r of rows) {
      if (r.state !== 'approved' && r.state !== 'delivered') continue;
      if (r.clinical_context_flag) continue;
      const check = assertCleanOutboundOutcomeRecord(r.payload, r.patient_id);
      if (!check.valid) {
        return jsonResponse({ error: 'outbound_policy_violation', violations: check.violations }, 500);
      }
      records.push({
        record_id: r.record_id,
        record_version: r.record_version,
        rules_version: r.rules_version,
        milestone: r.milestone,
        state: r.state,
        lean_mass_flag: r.lean_mass_flag,
        clinical_context_flag: r.clinical_context_flag,
        clinician_summary: r.clinician_summary,
        updated_at: r.updated_at,
        payload: r.payload,
      });
    }

    return jsonResponse({
      records,
      count: records.length,
      updated_since: updatedSince ?? null,
    });
  }

  // -------------------------------------------------------------------------
  // INT-06: GET /v1/outcomes/{record_id}
  // -------------------------------------------------------------------------
  const getRecordMatch = path.match(/^\/v1\/outcomes\/([^/]+)$/);
  if (req.method === 'GET' && getRecordMatch) {
    const recordId = decodeURIComponent(getRecordMatch[1]);
    const rec = await deps.store.findOutcomeRecord(auth.orgId, recordId);

    // Only approved or delivered records with cleared clinical_context_flag are visible to partner
    if (!rec || (rec.state !== 'approved' && rec.state !== 'delivered') || rec.clinical_context_flag) {
      return jsonResponse({ error: 'not_found' }, 404);
    }

    const check = assertCleanOutboundOutcomeRecord(rec.payload, rec.patient_id);
    if (!check.valid) {
      return jsonResponse({ error: 'outbound_policy_violation', violations: check.violations }, 500);
    }

    return jsonResponse({
      record_id: rec.record_id,
      record_version: rec.record_version,
      rules_version: rec.rules_version,
      milestone: rec.milestone,
      state: rec.state,
      lean_mass_flag: rec.lean_mass_flag,
      clinical_context_flag: rec.clinical_context_flag,
      clinician_summary: rec.clinician_summary,
      updated_at: rec.updated_at,
      payload: rec.payload,
    });
  }

  // -------------------------------------------------------------------------
  // INT-06: POST /v1/outcomes/{record_id}/redeliver
  // -------------------------------------------------------------------------
  const redeliverMatch = path.match(/^\/v1\/outcomes\/([^/]+)\/redeliver$/);
  if (req.method === 'POST' && redeliverMatch) {
    const recordId = decodeURIComponent(redeliverMatch[1]);
    const rec = await deps.store.findOutcomeRecord(auth.orgId, recordId);

    if (!rec) {
      return jsonResponse({ error: 'not_found' }, 404);
    }
    if ((rec.state !== 'approved' && rec.state !== 'delivered') || rec.clinical_context_flag) {
      return jsonResponse(
        {
          error: 'record_not_releasable',
          message: 'Outcome record must be clinician-approved with all clinical context flags cleared before delivery',
        },
        409
      );
    }

    const check = assertCleanOutboundOutcomeRecord(rec.payload, rec.patient_id);
    if (!check.valid) {
      return jsonResponse({ error: 'outbound_policy_violation', violations: check.violations }, 500);
    }

    const event_type =
      rec.record_version > 1 ? 'outcomes.milestone.corrected' : 'outcomes.milestone.ready';
    const event_id = deriveEventId(
      auth.partnerSecret,
      `redeliver:${auth.orgId}:${rec.record_id}:v${rec.record_version}:${nowIso}`
    );

    if (rec.state === 'approved') {
      await deps.store.markOutcomeDelivered(auth.orgId, rec.record_id);
    }

    await deps.store.emitPartnerEvent({
      event_id,
      event_type,
      org_id: auth.orgId,
      created_at: nowIso,
      payload: {
        event_id,
        event_type,
        record_id: rec.record_id,
        record_version: rec.record_version,
        milestone: rec.milestone,
        clinician_summary: rec.clinician_summary,
        outcome: rec.payload,
      },
    });

    return jsonResponse(
      {
        record_id: rec.record_id,
        record_version: rec.record_version,
        event_id,
        event_type,
        status: 'redelivered',
      },
      202
    );
  }

  return jsonResponse({ error: 'not_found' }, 404);
}
