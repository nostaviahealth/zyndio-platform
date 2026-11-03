// TC-039 integration: the analyze-lab-report Edge Function against the real
// migrated schema, real Storage (lab-reports bucket) and the real function
// runtime (`supabase functions serve`, see scripts/integration-local.sh).
//
// Before TC-039 the function read `record.pdf_url` / `record.profile_id` /
// `record.title` and wrote `markers` / `title` / `summary` / `updated_at` -
// none of which are lab_reports columns - accepted any caller and answered
// with the raw exception text. This suite fails on that code (no 401/403,
// 500 with error text where a clean 4xx/501 is expected).
//
// It also replays tests/contracts/analyze-lab-report.json (the requests the
// handler makes, pinned on the Deno side by
// supabase/functions/_shared/analyzeLabReport_test.ts) against real
// PostgREST + Storage, so a column/path drift fails here too.
// Fictional data only.
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import contract from '../contracts/analyze-lab-report.json';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY } from './setup';
import { callFn, createUser, deleteUser, restAdmin, signIn, uniqueSuffix } from './helpers';

const FN = 'analyze-lab-report';
const LEAK = [/pdf_url/i, /profile_id/i, /cannot read/i, /undefined/i, /column/i, /does not exist/i, /stack/i, /error:/i];

function service(path: string, init: RequestInit = {}) {
  return fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: { apikey: SUPABASE_SERVICE_ROLE_KEY!, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, ...init.headers },
  });
}

function fill(q: Record<string, string>, values: Record<string, string>): Record<string, string> {
  return Object.fromEntries(Object.entries(q).map(([k, v]) => [k, Object.entries(values).reduce((s, [n, x]) => s.split(`{${n}}`).join(x), v)]));
}

async function seedLinkedPatient(orgId: string, label: string) {
  const user = await createUser(`tc039-${label}`);
  const p = await restAdmin('patients', {
    method: 'POST',
    body: JSON.stringify({ id: user.userId, org_id: orgId, display_name: `Fictional ${label}`, mrn: `ZP-39-${uniqueSuffix()}` }),
  });
  expect(p.status, await p.clone().text()).toBe(201);
  const l = await restAdmin('patient_record_links', {
    method: 'POST',
    body: JSON.stringify({
      app_user_id: user.userId,
      org_id: orgId,
      telehealth_patient_id: `clinic:${user.userId}`,
      status: 'active',
      linked_at: new Date().toISOString(),
      proof_method: 'clinic_provisioned',
    }),
  });
  expect(l.status, await l.clone().text()).toBe(201);
  return user;
}

async function seedReport(orgId: string, patientId: string, pdfPath: string | null, data: Record<string, unknown>) {
  const r = await restAdmin('lab_reports', {
    method: 'POST',
    body: JSON.stringify({ org_id: orgId, patient_id: patientId, report_type: 'patient_upload', data, pdf_path: pdfPath }),
  });
  expect(r.status, await r.clone().text()).toBe(201);
  const [row] = (await r.json()) as { id: string }[];
  return row.id;
}

async function row(id: string) {
  const r = await restAdmin(`lab_reports?id=eq.${id}&select=org_id,patient_id,report_type,data,pdf_path`, { method: 'GET' });
  expect(r.status).toBe(200);
  return ((await r.json()) as Record<string, unknown>[])[0];
}

function expectNoLeak(text: string) {
  for (const re of LEAK) expect(text, `response leaks ${re}`).not.toMatch(re);
}

describe.skipIf(!integrationEnvReady)('analyze-lab-report Edge Function (TC-039)', () => {
  const cleanup: string[] = [];
  let orgId: string;
  let patient: { userId: string; email: string; password: string };
  let patientToken: string;
  let pdfPath: string;
  let withFile: string;
  let withMissingFile: string;
  let withoutFile: string;
  const data = { title: 'Fictional CBC', date: '2026-11-01', summary: 'Uploaded from mobile app.', markers: [] };

  beforeAll(async () => {
    const o = await restAdmin('organizations', { method: 'POST', body: JSON.stringify({ name: `TC-039 clinic ${uniqueSuffix()}` }) });
    orgId = ((await o.json()) as { id: string }[])[0].id;
    patient = await seedLinkedPatient(orgId, 'analyze');
    cleanup.push(patient.userId);
    patientToken = (await signIn(patient.email, patient.password)).access_token!;

    pdfPath = `${patient.userId}/${crypto.randomUUID()}.pdf`;
    const up = await service(`/storage/v1/object/lab-reports/${pdfPath}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/pdf' },
      body: '%PDF-1.4 fictional TC-039 report',
    });
    expect(up.status, await up.clone().text()).toBe(200);
    withFile = await seedReport(orgId, patient.userId, pdfPath, data);
    withMissingFile = await seedReport(orgId, patient.userId, `${patient.userId}/${crypto.randomUUID()}.pdf`, data);
    withoutFile = await seedReport(orgId, patient.userId, null, data);
  });

  afterAll(async () => {
    if (pdfPath) await service('/storage/v1/object/lab-reports', { method: 'DELETE', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ prefixes: [pdfPath] }) });
    while (cleanup.length) await deleteUser(cleanup.pop()!);
  });

  const payload = (id: string) => ({ type: 'INSERT', table: 'lab_reports', record: { id } });

  it('rejects a caller without a token (401) and a signed-in patient (403)', async () => {
    const anon = await callFn(FN, SUPABASE_ANON_KEY!, payload(withFile));
    const anonText = await anon.text();
    // 403 for a legacy anon JWT (valid signature, wrong role); 401 for a
    // non-JWT publishable key.
    expect([401, 403], anonText).toContain(anon.status);
    expectNoLeak(anonText);
    const noToken = await fetch(`${SUPABASE_URL}/functions/v1/${FN}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify(payload(withFile)),
    });
    expect(noToken.status, await noToken.text()).toBe(401);
    const asPatient = await callFn(FN, patientToken, payload(withFile));
    const t = await asPatient.text();
    expect(asPatient.status, t).toBe(403);
    expectNoLeak(t);
    expect(await row(withFile)).toMatchObject({ data, pdf_path: pdfPath });
  });

  it('a bad payload is 400 and an unknown report 404, without error text', async () => {
    const bad = await callFn(FN, SUPABASE_SERVICE_ROLE_KEY!, { record: { id: 'not-a-uuid', pdf_url: 'x' } });
    const badText = await bad.text();
    expect(bad.status, badText).toBe(400);
    expectNoLeak(badText);
    const unknown = await callFn(FN, SUPABASE_SERVICE_ROLE_KEY!, payload(crypto.randomUUID()));
    const unknownText = await unknown.text();
    expect(unknown.status, unknownText).toBe(404);
    expectNoLeak(unknownText);
  });

  it('a report with no file is skipped (422) and left unchanged', async () => {
    const r = await callFn(FN, SUPABASE_SERVICE_ROLE_KEY!, payload(withoutFile));
    const text = await r.text();
    expect(r.status, text).toBe(422);
    expect(JSON.parse(text)).toEqual({ status: 'skipped', reason: 'no_file' });
    expect(await row(withoutFile)).toMatchObject({ data, pdf_path: null });
  });

  it('a missing file is a generic 500 (no storage error text) and changes nothing', async () => {
    const r = await callFn(FN, SUPABASE_SERVICE_ROLE_KEY!, payload(withMissingFile));
    const text = await r.text();
    expect(r.status, text).toBe(500);
    expect(JSON.parse(text)).toEqual({ error: 'internal_error' });
    expect((await row(withMissingFile)).data).toEqual(data);
  });

  it('a real stored file: no server-side text extractor, so 501 and nothing invented or written', async () => {
    const r = await callFn(FN, SUPABASE_SERVICE_ROLE_KEY!, payload(withFile));
    const text = await r.text();
    expect(r.status, text).toBe(501);
    expect(JSON.parse(text)).toEqual({ error: 'analysis_unavailable' });
    expect(await row(withFile)).toMatchObject({ org_id: orgId, patient_id: patient.userId, report_type: 'patient_upload', data, pdf_path: pdfPath });
  });

  it('the pinned requests (contract) are accepted by real PostgREST + Storage', async () => {
    const values = { report_id: withFile, patient_id: patient.userId, pdf_path: pdfPath };
    const lookup = await service(`${contract.row_lookup.path}?${new URLSearchParams(fill(contract.row_lookup.query, values))}`, {
      method: contract.row_lookup.method,
    });
    expect(lookup.status, await lookup.clone().text()).toBe(200);
    const [r] = (await lookup.json()) as Record<string, unknown>[];
    expect(Object.keys(r).sort()).toEqual(contract.row_lookup.query.select.split(',').sort());
    expect(r).toMatchObject({ id: withFile, patient_id: patient.userId, pdf_path: pdfPath, data });

    const file = await service(contract.file_download.path.replace('{pdf_path}', pdfPath), { method: contract.file_download.method });
    expect(file.status).toBe(200);
    expect(await file.text()).toContain('fictional TC-039 report');

    // The update shape, on a throwaway report (so the other cases keep theirs).
    const scratch = await seedReport(orgId, patient.userId, null, data);
    const merged = { ...data, markers: [{ name: 'Fictional marker', value: '1' }], summary: 'Fictional analysis', analyzed_at: '2026-11-04T00:00:00.000Z' };
    const upd = await service(`${contract.analysis_update.path}?${new URLSearchParams(fill(contract.analysis_update.query, { ...values, report_id: scratch }))}`, {
      method: contract.analysis_update.method,
      headers: { 'Content-Type': 'application/json', Prefer: 'return=representation' },
      body: JSON.stringify({ data: merged }),
    });
    expect(upd.status, await upd.clone().text()).toBe(200);
    expect(await upd.json()).toEqual([{ id: scratch }]);
    expect((await row(scratch)).data).toEqual(merged);
  });
});
