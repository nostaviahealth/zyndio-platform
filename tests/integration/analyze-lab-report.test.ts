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
// APP-05: the report's own patient may now call it (the app's upload flow);
// another patient gets 404 (same as a missing report). The CI stack runs with
// the AI extractor OFF (LAB_AI_EXTRACTION_ENABLED unset), so a real file
// still answers 501 and nothing is filed; filing itself is replayed through
// lab_pipeline_file_results below.
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
  let otherPatientToken: string;
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
    const other = await seedLinkedPatient(orgId, 'analyze-other');
    cleanup.push(other.userId);
    otherPatientToken = (await signIn(other.email, other.password)).access_token!;

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

  it('rejects a caller without a token (401); the owner patient gets 501 (extractor off), another patient 404; nothing changes', async () => {
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
    const asPatient = await callFn(FN, patientToken, { report_id: withFile });
    const t = await asPatient.text();
    expect(asPatient.status, t).toBe(501);
    expect(JSON.parse(t)).toEqual({ error: 'analysis_unavailable' });
    expectNoLeak(t);
    const asOther = await callFn(FN, otherPatientToken, { report_id: withFile });
    const o = await asOther.text();
    expect(asOther.status, o).toBe(404);
    expect(JSON.parse(o)).toEqual({ error: 'not_found' });
    expectNoLeak(o);
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

    for (const key of ['analyte_map', 'account_name', 'account_dob'] as const) {
      const c = contract[key];
      const res = await service(`${c.path}?${new URLSearchParams(fill(c.query, values))}`, { method: c.method });
      expect(res.status, `${key}: ${await res.clone().text()}`).toBe(200);
    }

    // Filing, on a throwaway report (so the other cases keep theirs).
    const scratch = await seedReport(orgId, patient.userId, null, data);
    const sha = 'a'.repeat(64);
    const report = {
      file_sha256: sha, extraction_status: 'extracted', identity_hold: false, collected_on: '2026-10-14', lab_name: 'Fictional Reference Lab',
      data: { markers: [{ name: 'HbA1c', value: '5.5' }], summary: 'Fictional analysis', analyzed_at: '2026-11-04T00:00:00.000Z', extraction: { extractor: 'fictional' } },
    };
    const result = {
      analyte_key: 'hba1c', analyte_label: 'HbA1c', loinc: '4548-4', is_unmapped: false, value: 5.5, value_comparator: null, unit: '%',
      status: 'within_range', range_low: null, range_high: 5.7, reported_name: 'Hemoglobin A1c', reported_value: '37', reported_unit: 'mmol/mol',
      conversion_kind: 'hba1c', conversion_factor: 10.929, reference_range_text: '<39', field_confidence: { analyte: 0.97, value: 0.97 },
      confidence: 0.97, review_reasons: [],
    };
    expect(Object.keys(report).sort()).toEqual(contract.analysis_file.report_keys);
    expect(Object.keys(result).sort()).toEqual(contract.analysis_file.result_keys);
    const fileIt = (id: string, p_report: unknown) => service(contract.analysis_file.path, {
      method: contract.analysis_file.method,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_report_id: id, p_report, p_results: [result] }),
    });
    const f = await fileIt(scratch, report);
    expect(f.status, await f.clone().text()).toBe(200);
    expect(await f.json()).toBe(1);
    const filed = await restAdmin(`lab_reports?id=eq.${scratch}&select=data,file_sha256,extraction_status,identity_hold,collected_on,lab_name`, { method: 'GET' });
    const [fr] = (await filed.json()) as Record<string, any>[];
    expect(fr).toMatchObject({ file_sha256: sha, extraction_status: 'extracted', identity_hold: false, collected_on: '2026-10-14', lab_name: 'Fictional Reference Lab' });
    expect(fr.data).toMatchObject({ ...data, ...report.data });
    const results = await restAdmin(`lab_results?lab_report_id=eq.${scratch}&select=analyte_key,loinc,value,reported_value,reported_unit,conversion_kind,conversion_factor,taken_at`, { method: 'GET' });
    expect(await results.json()).toEqual([{ analyte_key: 'hba1c', loinc: '4548-4', value: 5.5, reported_value: '37', reported_unit: 'mmol/mol', conversion_kind: 'hba1c', conversion_factor: 10.929, taken_at: '2026-10-14T12:00:00+00:00' }]);

    // The same file filed for a second report of the same patient: 23505.
    const scratch2 = await seedReport(orgId, patient.userId, null, data);
    const dup = await fileIt(scratch2, report);
    expect(dup.status, await dup.clone().text()).toBe(409);
    expect(((await dup.json()) as { code: string }).code).toBe('23505');
    expect(await (await restAdmin(`lab_results?lab_report_id=eq.${scratch2}&select=id`, { method: 'GET' })).json()).toEqual([]);

    // A patient can't call it.
    const asPatient = await fetch(`${SUPABASE_URL}${contract.analysis_file.path}`, {
      method: 'POST',
      headers: { apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${patientToken}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_report_id: scratch, p_report: report, p_results: [] }),
    });
    expect([401, 403, 404]).toContain(asPatient.status);
  });
});
