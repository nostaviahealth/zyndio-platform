// TC-039 integration: opening a lab report's file, as the patient app does it
// (flutter_app/lib/services/lab_report_file_opener.dart ->
// HealthDataRepository.signedLabReportUrl): ask Storage for a signed link to
// the stored `pdf_path` with a 300-second lifetime, then fetch it. Real
// migrated schema + storage.objects RLS (TC-036) + real storage-api.
//
// - The owner gets a 5-minute link that serves their file.
// - Another patient (same clinic) is refused a link to it.
// - Each open makes a new link; an old one is never needed.
// Fictional data only.
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY } from './setup';
import { createUser, decodeJwtPayload, deleteUser, restAdmin, signIn, uniqueSuffix } from './helpers';

const LINK_LIFETIME_SECONDS = 300; // HealthDataRepository.labReportLinkLifetime

function asUser(token: string, path: string, init: RequestInit = {}) {
  return fetch(`${SUPABASE_URL}${path}`, {
    ...init,
    headers: { apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${token}`, ...init.headers },
  });
}

function sign(token: string, pdfPath: string) {
  return asUser(token, `/storage/v1/object/sign/lab-reports/${pdfPath}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ expiresIn: LINK_LIFETIME_SECONDS }),
  });
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
  const session = await signIn(user.email, user.password);
  return { ...user, token: session.access_token! };
}

describe.skipIf(!integrationEnvReady)('opening a lab report file through a signed link (TC-039)', () => {
  const cleanup: string[] = [];
  let owner: { userId: string; token: string };
  let other: { userId: string; token: string };
  let pdfPath: string;

  beforeAll(async () => {
    const o = await restAdmin('organizations', { method: 'POST', body: JSON.stringify({ name: `TC-039 files ${uniqueSuffix()}` }) });
    const orgId = ((await o.json()) as { id: string }[])[0].id;
    owner = await seedLinkedPatient(orgId, 'file-owner');
    other = await seedLinkedPatient(orgId, 'file-other');
    cleanup.push(owner.userId, other.userId);

    // Uploaded the way the app uploads it (own folder, uuid name), then filed.
    pdfPath = `${owner.userId}/${crypto.randomUUID()}.pdf`;
    const up = await asUser(owner.token, `/storage/v1/object/lab-reports/${pdfPath}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/pdf', 'x-upsert': 'false' },
      body: '%PDF-1.4 fictional TC-039 file-open report',
    });
    expect(up.status, await up.clone().text()).toBe(200);
    const r = await restAdmin('lab_reports', {
      method: 'POST',
      body: JSON.stringify({ org_id: orgId, patient_id: owner.userId, report_type: 'patient_upload', data: { title: 'Fictional' }, pdf_path: pdfPath }),
    });
    expect(r.status, await r.clone().text()).toBe(201);
  });

  afterAll(async () => {
    if (pdfPath) {
      await fetch(`${SUPABASE_URL}/storage/v1/object/lab-reports`, {
        method: 'DELETE',
        headers: { apikey: SUPABASE_SERVICE_ROLE_KEY!, Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ prefixes: [pdfPath] }),
      });
    }
    while (cleanup.length) await deleteUser(cleanup.pop()!);
  });

  it('the owner gets a 5-minute link that serves their file', async () => {
    const res = await sign(owner.token, pdfPath);
    expect(res.status, await res.clone().text()).toBe(200);
    const { signedURL } = (await res.json()) as { signedURL: string };
    expect(signedURL).toMatch(/^\/object\/sign\/lab-reports\/.+\?token=/);
    const claims = decodeJwtPayload(new URL(signedURL, 'http://x').searchParams.get('token')!);
    expect((claims.exp as number) - (claims.iat as number)).toBe(LINK_LIFETIME_SECONDS);
    const file = await fetch(`${SUPABASE_URL}/storage/v1${signedURL}`);
    expect(file.status).toBe(200);
    expect(await file.text()).toContain('fictional TC-039 file-open report');
  });

  it("another patient is refused a link to the owner's file", async () => {
    const res = await sign(other.token, pdfPath);
    expect(res.status).not.toBe(200);
    expect(JSON.stringify(await res.json().catch(() => ({})))).not.toContain('signedURL');
  });

  it('each open makes a new, independently valid link', async () => {
    const a = (await (await sign(owner.token, pdfPath)).json()) as { signedURL: string };
    await new Promise((r) => setTimeout(r, 1100));
    const b = (await (await sign(owner.token, pdfPath)).json()) as { signedURL: string };
    expect(a.signedURL).not.toBe(b.signedURL);
    for (const l of [a, b]) expect((await fetch(`${SUPABASE_URL}/storage/v1${l.signedURL}`)).status).toBe(200);
  });
});
