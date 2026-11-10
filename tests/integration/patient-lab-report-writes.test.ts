// TC-036 integration: the patient app's lab-report writes (file an uploaded
// report, file a manual biomarker entry), replayed from
// tests/contracts/patient-lab-report-writes.json against the real migrated
// schema + RLS through PostgREST, signed in as a real (fictional) linked
// patient. The Dart side is pinned to the same contract by
// flutter_app/test/data/health_data_repository_lab_report_writes_test.dart,
// so a Dart write naming a column that doesn't exist (the pre-TC-036
// `profile_id`/`date`/`title`/`pdf_url` insert -> PostgREST 400) can't pass
// both suites.
//
// Also proves the RLS shape the app relies on: the patient reads their own
// org_id; can file only into their own record and clinic; pdf_path can't
// point at another patient's folder or hold a URL; and patients can't UPDATE
// lab_reports (so manual entry is insert-only, by design).
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import contract from '../contracts/patient-lab-report-writes.json';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY } from './setup';
import { createUser, deleteUser, restAdmin, seedPatientHealthDataConsent, signIn, uniqueSuffix } from './helpers';

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

function orgLookup(token: string, patientId: string) {
  const c = contract.org_lookup;
  const params = new URLSearchParams(fill(c.query, { patient_id: patientId }));
  return asPatient(token, `${c.path}?${params.toString()}`, { method: c.method });
}

function insert(token: string, which: 'upload_insert' | 'manual_entry_insert', values: Values, mutate?: (b: Record<string, unknown>) => void) {
  const c = contract[which];
  const body = fill(c.body, values) as Record<string, unknown>;
  mutate?.(body);
  return asPatient(token, c.path, { method: c.method, body: JSON.stringify(body) });
}

async function seedLinkedPatient(orgId: string, label: string) {
  const user = await createUser(`tc036-${label}`);
  const p = await restAdmin('patients', {
    method: 'POST',
    body: JSON.stringify({ id: user.userId, org_id: orgId, display_name: `Fictional ${label}`, mrn: `ZP-36-${uniqueSuffix()}` }),
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
  await seedPatientHealthDataConsent(orgId, user.userId);
  return user;
}

async function rowsFor(patientId: string) {
  const r = await restAdmin(`lab_reports?patient_id=eq.${patientId}&select=org_id,patient_id,report_type,data,pdf_path&order=created_at.asc`, { method: 'GET' });
  expect(r.status).toBe(200);
  return (await r.json()) as { org_id: string; patient_id: string; report_type: string; data: Record<string, unknown>; pdf_path: string | null }[];
}

const today = new Date().toISOString().slice(0, 10);

describe.skipIf(!integrationEnvReady)('patient lab-report writes (TC-036 contract)', () => {
  const cleanupUserIds: string[] = [];
  let orgA: string;
  let orgB: string;
  let owner: { userId: string; email: string; password: string };
  let token: string;
  let sameClinicOther: { userId: string };
  let otherClinicPatient: { userId: string };

  beforeAll(async () => {
    [orgA, orgB] = await Promise.all(
      ['A', 'B'].map(async (n) => {
        const r = await restAdmin('organizations', { method: 'POST', body: JSON.stringify({ name: `TC-036 clinic ${n} ${uniqueSuffix()}` }) });
        const [org] = (await r.json()) as { id: string }[];
        return org.id;
      }),
    );
    owner = await seedLinkedPatient(orgA, 'owner');
    sameClinicOther = await seedLinkedPatient(orgA, 'same-clinic');
    otherClinicPatient = await seedLinkedPatient(orgB, 'other-clinic');
    cleanupUserIds.push(owner.userId, sameClinicOther.userId, otherClinicPatient.userId);
    const session = await signIn(owner.email, owner.password);
    expect(session.access_token).toBeTruthy();
    token = session.access_token!;
  });

  afterAll(async () => {
    while (cleanupUserIds.length) await deleteUser(cleanupUserIds.pop()!);
  });

  it('the pinned org lookup returns the patient their own clinic', async () => {
    const res = await orgLookup(token, owner.userId);
    const body = await res.text();
    expect(res.status, body).toBe(200);
    expect(JSON.parse(body)).toEqual([{ org_id: orgA }]);
    // and nobody else's
    for (const other of [sameClinicOther.userId, otherClinicPatient.userId]) {
      expect(await (await orgLookup(token, other)).json()).toEqual([]);
    }
  });

  it('the pinned upload insert is accepted and stores the object path, not a URL', async () => {
    const object = crypto.randomUUID();
    const res = await insert(token, 'upload_insert', { patient_id: owner.userId, org_id: orgA, object });
    expect(res.status, await res.text()).toBe(201);
    const rows = await rowsFor(owner.userId);
    const filed = rows.find((r) => r.report_type === 'patient_upload');
    expect(filed).toBeDefined();
    expect(filed!.org_id).toBe(orgA);
    expect(filed!.pdf_path).toBe(`${owner.userId}/${object}.pdf`);
    expect(filed!.data).toEqual(contract.upload_insert.body.data);
  });

  it('the pinned manual-entry insert is accepted', async () => {
    const res = await insert(token, 'manual_entry_insert', { patient_id: owner.userId, org_id: orgA, today });
    expect(res.status, await res.text()).toBe(201);
    const manual = (await rowsFor(owner.userId)).filter((r) => r.report_type === 'manual_entry');
    expect(manual).toHaveLength(1);
    expect(manual[0].pdf_path).toBeNull();
    expect(manual[0].data).toEqual(fill(contract.manual_entry_insert.body.data, { today }));
  });

  it('the pre-TC-036 insert (non-existent columns) is rejected by PostgREST', async () => {
    const res = await asPatient(token, '/rest/v1/lab_reports', {
      method: 'POST',
      body: JSON.stringify({ profile_id: owner.userId, date: today, title: 'Manual Entry', summary: 'x', markers: [], published: true, updated_at: new Date().toISOString() }),
    });
    expect(res.status).toBe(400);
  });

  it('a patient cannot file into another patient record or another clinic', async () => {
    const object = crypto.randomUUID();
    for (const [pid, oid] of [
      [sameClinicOther.userId, orgA],
      [otherClinicPatient.userId, orgB],
      [owner.userId, orgB],
    ]) {
      const res = await insert(token, 'upload_insert', { patient_id: pid, org_id: oid, object });
      expect(res.status, `${pid}/${oid}`).toBe(403);
    }
    expect(await rowsFor(sameClinicOther.userId)).toEqual([]);
    expect(await rowsFor(otherClinicPatient.userId)).toEqual([]);
  });

  it("pdf_path can't point at another patient's folder or hold a URL", async () => {
    const object = crypto.randomUUID();
    for (const bad of [
      `${sameClinicOther.userId}/${object}.pdf`,
      `${SUPABASE_URL}/storage/v1/object/public/lab-reports/${owner.userId}/${object}.pdf`,
    ]) {
      const res = await insert(token, 'upload_insert', { patient_id: owner.userId, org_id: orgA, object }, (b) => {
        b.pdf_path = bad;
      });
      expect(res.status, bad).toBe(400);
      expect(((await res.json()) as { code: string }).code).toBe('23514');
    }
  });

  it('patients cannot update their lab reports (why manual entry files a new report)', async () => {
    const res = await asPatient(token, `/rest/v1/lab_reports?patient_id=eq.${owner.userId}`, {
      method: 'PATCH',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify({ data: { title: 'tampered' } }),
    });
    expect([200, 403, 401]).toContain(res.status);
    if (res.status === 200) expect(await res.json()).toEqual([]);
    const titles = (await rowsFor(owner.userId)).map((r) => r.data.title);
    expect(titles).not.toContain('tampered');
  });
});
