// TC-037 integration: the patient app's lab-report list request, replayed
// byte-for-byte from tests/contracts/patient-lab-reports-query.json against
// the real migrated schema + RLS through PostgREST, signed in as a real
// (fictional) linked patient. The Dart side is pinned to the same contract by
// flutter_app/test/data/health_data_repository_lab_reports_test.dart, so a
// Dart query naming a column that doesn't exist (the pre-TC-037 `profile_id`
// filter / `date` order -> PostgREST 400, 42703) can't pass both suites.
//
// Proves: the request is accepted (200); the owner gets their own reports,
// newest first, with the `data` payload; identity-held reports are left out;
// another patient's id returns nothing (RLS), same clinic or not.
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import contract from '../contracts/patient-lab-reports-query.json';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY } from './setup';
import { createUser, deleteUser, restAdmin, seedPatientHealthDataConsent, signIn, uniqueSuffix } from './helpers';

function contractRequest(patientId: string, token: string) {
  const params = new URLSearchParams();
  for (const [k, v] of Object.entries(contract.query)) params.set(k, v.replace('{patient_id}', patientId));
  return fetch(`${SUPABASE_URL}${contract.path}?${params.toString()}`, {
    method: contract.method,
    headers: { apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${token}` },
  });
}

async function seedLinkedPatient(orgId: string, label: string) {
  const user = await createUser(`tc037-${label}`);
  const p = await restAdmin('patients', {
    method: 'POST',
    body: JSON.stringify({ id: user.userId, org_id: orgId, display_name: `Fictional ${label}`, mrn: `ZP-37-${uniqueSuffix()}` }),
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

async function seedReport(orgId: string, patientId: string, createdAt: string, data: unknown, identityHold = false) {
  const res = await restAdmin('lab_reports', {
    method: 'POST',
    body: JSON.stringify({ org_id: orgId, patient_id: patientId, report_type: 'metabolic_panel', data, created_at: createdAt, identity_hold: identityHold }),
  });
  expect(res.status, await res.clone().text()).toBe(201);
  const [row] = (await res.json()) as { id: string }[];
  return row.id;
}

describe.skipIf(!integrationEnvReady)('patient lab-reports query (TC-037 contract)', () => {
  const cleanupUserIds: string[] = [];
  let owner: { userId: string; email: string; password: string };
  let ownerToken: string;
  let sameClinicOther: { userId: string };
  let otherClinicPatient: { userId: string };
  let olderId: string;
  let newerId: string;
  let heldId: string;

  beforeAll(async () => {
    const orgs = await Promise.all(
      ['A', 'B'].map(async (n) => {
        const r = await restAdmin('organizations', { method: 'POST', body: JSON.stringify({ name: `TC-037 clinic ${n} ${uniqueSuffix()}` }) });
        const [org] = (await r.json()) as { id: string }[];
        return org.id;
      }),
    );
    owner = await seedLinkedPatient(orgs[0], 'owner');
    sameClinicOther = await seedLinkedPatient(orgs[0], 'same-clinic');
    otherClinicPatient = await seedLinkedPatient(orgs[1], 'other-clinic');
    cleanupUserIds.push(owner.userId, sameClinicOther.userId, otherClinicPatient.userId);

    olderId = await seedReport(orgs[0], owner.userId, '2026-01-01T08:00:00Z', { title: 'Fictional baseline', markers: [{ name: 'HbA1c', value: '5.6', unit: '%' }] });
    newerId = await seedReport(orgs[0], owner.userId, '2026-06-01T08:00:00Z', { title: 'Fictional follow-up', markers: [{ name: 'HbA1c', value: '5.2', unit: '%' }] });
    heldId = await seedReport(orgs[0], owner.userId, '2026-07-01T08:00:00Z', { title: 'Fictional held', markers: [] }, true);
    await seedReport(orgs[0], sameClinicOther.userId, '2026-06-02T08:00:00Z', { title: 'Fictional other' });
    await seedReport(orgs[1], otherClinicPatient.userId, '2026-06-03T08:00:00Z', { title: 'Fictional other clinic' });

    const session = await signIn(owner.email, owner.password);
    expect(session.access_token).toBeTruthy();
    ownerToken = session.access_token!;
  });

  afterAll(async () => {
    while (cleanupUserIds.length) await deleteUser(cleanupUserIds.pop()!);
  });

  it('the pinned request is accepted by PostgREST and returns the owner reports, newest first, held left out', async () => {
    const res = await contractRequest(owner.userId, ownerToken);
    const body = await res.text();
    expect(res.status, body).toBe(200);
    const rows = JSON.parse(body) as { id: string; report_type: string; data: { title?: string }; created_at: string }[];
    expect(rows.map((r) => r.id)).toEqual([newerId, olderId]);
    expect(rows.map((r) => r.id)).not.toContain(heldId);
    expect(Object.keys(rows[0]).sort()).toEqual(['created_at', 'data', 'id', 'pdf_path', 'report_type']);
    expect(rows[0].data.title).toBe('Fictional follow-up');
    expect(rows[0].report_type).toBe('metabolic_panel');
  });

  it("another patient's id returns nothing (same clinic and other clinic)", async () => {
    for (const other of [sameClinicOther.userId, otherClinicPatient.userId]) {
      const res = await contractRequest(other, ownerToken);
      expect(res.status).toBe(200);
      expect(await res.json()).toEqual([]);
    }
  });
});
