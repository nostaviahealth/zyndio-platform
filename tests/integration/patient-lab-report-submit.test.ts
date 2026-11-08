// APP-05 integration: the patient app's lab submit path, replayed from
// tests/contracts/patient-lab-report-submit.json against the real migrated
// schema + RLS + Storage + the analyze-lab-report function, signed in as a
// real (fictional) linked patient. The Dart side is pinned to the same
// contract by flutter_app/test/data/health_data_repository_lab_submit_test.dart.
//
// The CI stack runs with the AI extractor OFF, so the function answers 501
// (saved, results after review) and files nothing - which is exactly what
// production does until the flag is switched on. Fictional data only.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import contract from '../contracts/patient-lab-report-submit.json';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY } from './setup';
import { callFn, createUser, deleteUser, restAdmin, signIn, uniqueSuffix } from './helpers';

type Values = Record<string, string>;
function fill<T>(v: T, values: Values): T {
  if (typeof v === 'string') return Object.entries(values).reduce((s, [k, x]) => s.split(`{${k}}`).join(x), v as string) as T;
  if (Array.isArray(v)) return v.map((e) => fill(e, values)) as T;
  if (v && typeof v === 'object') return Object.fromEntries(Object.entries(v).map(([k, e]) => [k, fill(e, values)])) as T;
  return v;
}

function asPatient(token: string, path: string, init: RequestInit = {}) {
  return fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: { apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${token}`, 'Content-Type': 'application/json', ...init.headers },
  });
}

async function seedLinkedPatient(orgId: string, label: string) {
  const user = await createUser(`app05-${label}`);
  const p = await restAdmin('patients', {
    method: 'POST',
    body: JSON.stringify({ id: user.userId, org_id: orgId, display_name: 'Jordan Rivera', mrn: `ZP-05-${uniqueSuffix()}` }),
  });
  expect(p.status, await p.clone().text()).toBe(201);
  const l = await restAdmin('patient_record_links', {
    method: 'POST',
    body: JSON.stringify({
      app_user_id: user.userId, org_id: orgId, telehealth_patient_id: `clinic:${user.userId}`,
      status: 'active', linked_at: new Date().toISOString(), proof_method: 'clinic_provisioned',
    }),
  });
  expect(l.status, await l.clone().text()).toBe(201);
  return user;
}

const today = new Date().toISOString().slice(0, 10);
const PDF = readFileSync(new URL('../fixtures/labs/jordan-rivera-2026-10-14-us.pdf', import.meta.url));
const SHA = createHash('sha256').update(PDF).digest('hex');

describe.skipIf(!integrationEnvReady)('patient lab-report submit (APP-05 contract)', () => {
  const cleanup: string[] = [];
  const objects: string[] = [];
  let orgId: string;
  let patient: { userId: string; email: string; password: string };
  let token: string;

  beforeAll(async () => {
    const o = await restAdmin('organizations', { method: 'POST', body: JSON.stringify({ name: `APP-05 clinic ${uniqueSuffix()}` }) });
    orgId = ((await o.json()) as { id: string }[])[0].id;
    patient = await seedLinkedPatient(orgId, 'submit');
    cleanup.push(patient.userId);
    token = (await signIn(patient.email, patient.password)).access_token!;
  });

  afterAll(async () => {
    if (objects.length) {
      await fetch(`${SUPABASE_URL}/storage/v1/object/lab-reports`, {
        method: 'DELETE',
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY!, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ prefixes: objects }),
      });
    }
    while (cleanup.length) await deleteUser(cleanup.pop()!);
  });

  it('dedupe lookup -> upload -> insert with file_sha256 -> analyze (501, saved, row untouched) -> same file again is refused', async () => {
    const values = { patient_id: patient.userId, org_id: orgId, sha256: SHA, today };

    const look = contract.dedupe_lookup;
    const l1 = await asPatient(token, `${look.path}?${new URLSearchParams(fill(look.query, values))}`, { method: look.method });
    expect(l1.status, await l1.clone().text()).toBe(200);
    expect(await l1.json()).toEqual([]);

    const object = crypto.randomUUID();
    const pdfPath = `${patient.userId}/${object}.pdf`;
    const up = await asPatient(token, `/storage/v1/object/lab-reports/${pdfPath}`, {
      method: 'POST', headers: { 'Content-Type': 'application/pdf' }, body: PDF,
    });
    expect(up.status, await up.clone().text()).toBe(200);
    objects.push(pdfPath);

    const ins = contract.submit_insert;
    const res = await asPatient(token, `${ins.path}?${new URLSearchParams(ins.query)}`, {
      method: ins.method,
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify(fill(ins.body, { ...values, object })),
    });
    expect(res.status, await res.clone().text()).toBe(201);
    const [{ id }] = (await res.json()) as { id: string }[];

    const l2 = await asPatient(token, `${look.path}?${new URLSearchParams(fill(look.query, values))}`, { method: look.method });
    expect(await l2.json()).toEqual([{ id, extraction_status: 'pending' }]);

    const an = await callFn('analyze-lab-report', token, fill(contract.analyze_call.body, { report_id: id }));
    const text = await an.text();
    expect(an.status, text).toBe(501);
    expect(JSON.parse(text)).toEqual({ error: 'analysis_unavailable' });
    const row = await restAdmin(`lab_reports?id=eq.${id}&select=file_sha256,extraction_status,identity_hold`, { method: 'GET' });
    expect(await row.json()).toEqual([{ file_sha256: SHA, extraction_status: 'pending', identity_hold: false }]);

    // Same file, same patient: the unique index refuses it.
    const again = await asPatient(token, `${ins.path}?${new URLSearchParams(ins.query)}`, {
      method: ins.method,
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify(fill(ins.body, { ...values, object: crypto.randomUUID() })),
    });
    expect(again.status).toBe(409);
    expect(((await again.json()) as { code: string }).code).toBe('23505');
  });
});
