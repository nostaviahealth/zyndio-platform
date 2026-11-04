import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  GOLDEN_FIXTURE_INPUT,
  computeOutcomeRecord,
} from '../_shared/outcomesEngine.ts';
import {
  BodyCompositionScanRow,
  OutcomeRecordRow,
  OutcomesSandboxStore,
  PartnerWebhookEvent,
  handleOutcomesSandboxRequest,
} from './handler.ts';

function createInMemorySandboxStore(seed?: {
  patients?: Array<{ id: string; org_id: string; mrn: string }>;
  outcomes?: OutcomeRecordRow[];
}): {
  store: OutcomesSandboxStore;
  scans: BodyCompositionScanRow[];
  outcomes: Map<string, OutcomeRecordRow>;
  events: PartnerWebhookEvent[];
} {
  const patients = seed?.patients ?? [
    {
      id: '00000000-0000-0000-0000-0000000a1001',
      org_id: '00000000-0000-0000-0000-00000000000a',
      mrn: 'ZP-10482',
    },
  ];
  const scans: BodyCompositionScanRow[] = [];
  const outcomes = new Map<string, OutcomeRecordRow>();
  for (const o of seed?.outcomes ?? []) {
    outcomes.set(`${o.org_id}:${o.record_id}`, o);
  }
  const events: PartnerWebhookEvent[] = [];

  const store: OutcomesSandboxStore = {
    async findPatientByZyndioId(orgId, zyndioPatientId) {
      const hit = patients.find(
        (p) => p.org_id === orgId && (p.mrn === zyndioPatientId || p.id === zyndioPatientId)
      );
      return hit ? { id: hit.id, mrn: hit.mrn } : null;
    },
    async findScanByVersion(orgId, partnerScanId, partnerScanVersion) {
      return (
        scans.find(
          (s) =>
            s.org_id === orgId &&
            s.partner_scan_id === partnerScanId &&
            s.partner_scan_version === partnerScanVersion
        ) ?? null
      );
    },
    async insertScan(row) {
      const created: BodyCompositionScanRow = {
        ...row,
        id: `scan_${scans.length + 1}`,
        created_at: '2026-10-28T10:00:00Z',
      };
      scans.push(created);
      return created;
    },
    async findOutcomeRecord(orgId, recordId) {
      return outcomes.get(`${orgId}:${recordId}`) ?? null;
    },
    async listReleasedOutcomeRecords(orgId, updatedSince) {
      const list = Array.from(outcomes.values()).filter(
        (o) =>
          o.org_id === orgId &&
          (o.state === 'approved' || o.state === 'delivered') &&
          !o.clinical_context_flag &&
          (!updatedSince || Date.parse(o.updated_at) >= Date.parse(updatedSince))
      );
      return list;
    },
    async markOutcomeDelivered(orgId, recordId) {
      const hit = outcomes.get(`${orgId}:${recordId}`);
      if (hit && hit.state === 'approved') {
        outcomes.set(`${orgId}:${recordId}`, { ...hit, state: 'delivered' });
      }
    },
    async emitPartnerEvent(event) {
      events.push(event);
    },
  };

  return { store, scans, outcomes, events };
}

function fakeEnv(vars: Record<string, string> = {}) {
  const defaults: Record<string, string> = {
    OUTCOMES_PARTNER_API_KEY: 'dexascan-test-api-key',
    OUTCOMES_PARTNER_SECRET: 'dexascan-partner-hmac-secret-test-only',
    OUTCOMES_PARTNER_ORG_ID: '00000000-0000-0000-0000-00000000000a',
    ...vars,
  };
  return { get: (k: string) => defaults[k] };
}

Deno.test('INT-05: rejects unauthenticated requests with 401', async () => {
  const { store, scans } = createInMemorySandboxStore();
  const req = new Request('https://example.test/v1/measurements/body-composition', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({}),
  });
  const res = await handleOutcomesSandboxRequest(req, { env: fakeEnv(), store });
  assertEquals(res.status, 401);
  assertEquals(scans.length, 0);
});

Deno.test('INT-05: matched zyndio_patient_id binds scan immediately and is idempotent on partner_scan_id + partner_scan_version', async () => {
  const { store, scans, events } = createInMemorySandboxStore();
  const payload = {
    zyndio_patient_id: 'ZP-10482',
    partner_patient_id: 'DEX-PAT-10482',
    partner_scan_id: 'DEXA-SCAN-20261028-01',
    partner_scan_version: 1,
    scan_date: '2026-10-28',
    site_id: 'SITE-SF-01',
    device_vendor: 'Hologic',
    device_model: 'Horizon A',
    software_version: 'APEX 5.6.1',
    measures: {
      weight_lb: 194,
      fat_mass_lb: 55,
      lean_mass_lb: 133,
      visceral_fat: 2.1,
    },
  };

  const makeReq = () =>
    new Request('https://example.test/v1/measurements/body-composition', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        Authorization: 'Bearer dexascan-test-api-key',
      },
      body: JSON.stringify(payload),
    });

  const first = await handleOutcomesSandboxRequest(makeReq(), { env: fakeEnv(), store });
  assertEquals(first.status, 202);
  const firstBody = await first.json();
  assertEquals(firstBody.status, 'received');
  assertEquals(firstBody.ingestion_id.startsWith('ing_'), true);
  assertEquals(firstBody.binding_status, 'bound');
  assertEquals(firstBody.idempotent_replay, false);
  assertEquals(scans.length, 1);
  assertEquals(events.length, 0);

  // Replay with identical partner_scan_id + partner_scan_version
  const replay = await handleOutcomesSandboxRequest(makeReq(), { env: fakeEnv(), store });
  assertEquals(replay.status, 202);
  const replayBody = await replay.json();
  assertEquals(replayBody.ingestion_id, firstBody.ingestion_id);
  assertEquals(replayBody.status, 'received');
  assertEquals(replayBody.idempotent_replay, true);
  assertEquals(scans.length, 1);
});

Deno.test('INT-05: unknown zyndio_patient_id routes to unmatched queue and emits measurement.unmatched event', async () => {
  const { store, scans, events } = createInMemorySandboxStore();
  const req = new Request('https://example.test/v1/measurements/body-composition', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      Authorization: 'Bearer dexascan-test-api-key',
    },
    body: JSON.stringify({
      zyndio_patient_id: 'ZP-UNKNOWN-99999',
      partner_patient_id: 'DEX-PAT-99999',
      partner_scan_id: 'DEXA-SCAN-UNMATCHED-01',
      partner_scan_version: 1,
      scan_date: '2026-10-28',
      device_vendor: 'Hologic',
      device_model: 'Horizon A',
      software_version: 'APEX 5.6.1',
      measures: { weight_lb: 205 },
    }),
  });

  const res = await handleOutcomesSandboxRequest(req, { env: fakeEnv(), store });
  assertEquals(res.status, 202);
  const body = await res.json();
  assertEquals(body.status, 'received');
  assertEquals(body.binding_status, 'unmatched');
  assertEquals(body.unmatched_event_id.startsWith('evt_'), true);
  assertEquals(scans.length, 1);
  assertEquals(scans[0].binding_status, 'unmatched');
  assertEquals(scans[0].patient_id, null);
  assertEquals(events.length, 1);
  assertEquals(events[0].event_type, 'measurement.unmatched');
});

Deno.test('INT-05: POST /v1/measurements/body-composition/documents accepts DEXA PDF metadata', async () => {
  const { store, scans } = createInMemorySandboxStore();
  const req = new Request('https://example.test/v1/measurements/body-composition/documents', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      Authorization: 'Bearer dexascan-test-api-key',
    },
    body: JSON.stringify({
      zyndio_patient_id: 'ZP-10482',
      partner_patient_id: 'DEX-PAT-10482',
      partner_scan_id: 'DEXA-DOC-20261028-01',
      partner_scan_version: 1,
      scan_date: '2026-10-28',
      device_vendor: 'Hologic',
      device_model: 'Horizon A',
      software_version: 'APEX 5.6.1',
      document_sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      content_type: 'application/pdf',
    }),
  });

  const res = await handleOutcomesSandboxRequest(req, { env: fakeEnv(), store });
  assertEquals(res.status, 202);
  const body = await res.json();
  assertEquals(body.status, 'received');
  assertEquals(body.binding_status, 'bound');
  assertEquals(scans.length, 1);
});

Deno.test('INT-06: GET /v1/outcomes/{record_id}, GET /v1/outcomes?updated_since=, and POST /v1/outcomes/{record_id}/redeliver', async () => {
  const computed = computeOutcomeRecord(GOLDEN_FIXTURE_INPUT);
  const approvedRow: OutcomeRecordRow = {
    id: 'out_1',
    record_id: computed.record_id,
    org_id: '00000000-0000-0000-0000-00000000000a',
    patient_id: GOLDEN_FIXTURE_INPUT.platform_patient_id,
    milestone: computed.milestone,
    record_version: computed.record_version,
    rules_version: computed.rules_version,
    state: 'approved',
    lean_mass_flag: computed.lean_mass_flag,
    clinical_context_flag: false,
    clinician_summary: computed.clinician_summary,
    payload: computed.schedule_c_fields as unknown as Record<string, unknown>,
    approved_by: '00000000-0000-0000-0000-0000000a0002',
    approved_at: '2026-10-29T12:00:00Z',
    created_at: '2026-10-28T12:00:00Z',
    updated_at: '2026-10-29T12:00:00Z',
  };

  const inReviewRow: OutcomeRecordRow = {
    ...approvedRow,
    id: 'out_2',
    record_id: 'rec_unapproved_d90_v1',
    state: 'in_review',
    clinical_context_flag: true,
  };

  const { store, outcomes, events } = createInMemorySandboxStore({
    outcomes: [approvedRow, inReviewRow],
  });

  // 1. Unapproved / flagged record is 404 on partner API
  const unapprovedRes = await handleOutcomesSandboxRequest(
    new Request('https://example.test/v1/outcomes/rec_unapproved_d90_v1', {
      method: 'GET',
      headers: { Authorization: 'Bearer dexascan-test-api-key' },
    }),
    { env: fakeEnv(), store }
  );
  assertEquals(unapprovedRes.status, 404);

  // 2. Approved record is returned with clean 35-field Schedule C payload
  const getRes = await handleOutcomesSandboxRequest(
    new Request(`https://example.test/v1/outcomes/${computed.record_id}`, {
      method: 'GET',
      headers: { Authorization: 'Bearer dexascan-test-api-key' },
    }),
    { env: fakeEnv(), store }
  );
  assertEquals(getRes.status, 200);
  const getBody = await getRes.json();
  assertEquals(getBody.record_id, 'rec_golden_d180_v1');
  assertEquals(getBody.payload.partner_patient_id, 'DEX-PAT-10482');
  assertEquals(String(getBody.payload.zyndio_patient_token).startsWith('zpt_'), true);
  assertEquals(JSON.stringify(getBody).includes(GOLDEN_FIXTURE_INPUT.platform_patient_id), false);

  // 3. GET /v1/outcomes?updated_since=
  const listRes = await handleOutcomesSandboxRequest(
    new Request('https://example.test/v1/outcomes?updated_since=2026-10-29T00:00:00Z', {
      method: 'GET',
      headers: { Authorization: 'Bearer dexascan-test-api-key' },
    }),
    { env: fakeEnv(), store }
  );
  assertEquals(listRes.status, 200);
  const listBody = await listRes.json();
  assertEquals(listBody.count, 1);
  assertEquals(listBody.records[0].record_id, 'rec_golden_d180_v1');

  // 4. POST /v1/outcomes/{record_id}/redeliver emits outcomes.milestone.ready and marks delivered
  const redeliverRes = await handleOutcomesSandboxRequest(
    new Request(`https://example.test/v1/outcomes/${computed.record_id}/redeliver`, {
      method: 'POST',
      headers: { Authorization: 'Bearer dexascan-test-api-key' },
    }),
    { env: fakeEnv(), store }
  );
  assertEquals(redeliverRes.status, 202);
  const redeliverBody = await redeliverRes.json();
  assertEquals(redeliverBody.status, 'redelivered');
  assertEquals(redeliverBody.event_id.startsWith('evt_'), true);
  assertEquals(redeliverBody.event_type, 'outcomes.milestone.ready');
  assertEquals(events.length, 1);
  assertEquals(
    outcomes.get(`00000000-0000-0000-0000-00000000000a:${computed.record_id}`)?.state,
    'delivered'
  );
});
