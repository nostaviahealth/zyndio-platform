// TC-018 (Henry add-on, Create Patient): create-patient Edge Function,
// exercised end to end against local `supabase functions serve`. Points
// Create Patient at the real patients table via create_patient_record()
// (no shadow table) - mints the auth user, then calls the RPC under the
// caller's own JWT so org/role/audit all resolve to the real actor.
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { integrationEnvReady, SUPABASE_ANON_KEY } from './setup';
import {
  auditRows,
  callFn,
  createOrgAndMember,
  deleteUser,
  enrollAndVerifyTotp,
  restAdmin,
  signIn,
  uniqueSuffix,
} from './helpers';

describe.skipIf(!integrationEnvReady)('create-patient', () => {
  const cleanupUserIds: string[] = [];
  let physician: Awaited<ReturnType<typeof createOrgAndMember>>;
  let physicianAal1Token: string;
  let physicianAal2Token: string;

  beforeAll(async () => {
    physician = await createOrgAndMember('physician');
    cleanupUserIds.push(physician.userId);
    const aal1 = await signIn(physician.email, physician.password);
    physicianAal1Token = aal1.access_token!;
    const { aal2Token } = await enrollAndVerifyTotp(physicianAal1Token);
    physicianAal2Token = aal2Token!;
  });

  afterAll(async () => {
    while (cleanupUserIds.length) await deleteUser(cleanupUserIds.pop()!);
  });

  it('rejects an aal1 physician session with 403', async () => {
    const res = await callFn('create-patient', physicianAal1Token, {
      email: `tc018-aal1-${uniqueSuffix()}@example.test`,
      display_name: 'Fictional Patient',
    });
    expect(res.status).toBe(403);
  });

  it('every allowed role (physician, care_coordinator) succeeds, creates the patient in its own org, and audits it', async () => {
    for (const role of ['physician', 'care_coordinator'] as const) {
      const actor = await createOrgAndMember(role, 'active', physician.orgId);
      cleanupUserIds.push(actor.userId);
      const aal1 = await signIn(actor.email, actor.password);
      const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);

      const email = `tc018-${role}-patient-${uniqueSuffix()}@example.test`;
      const res = await callFn('create-patient', aal2Token!, {
        email,
        display_name: `Fictional Patient (${role})`,
        mrn: `MRN-${uniqueSuffix()}`,
      });
      expect(res.status).toBe(200);
      const body = (await res.json()) as { status: string; patient_id: string };
      expect(body.status).toBe('ok');
      cleanupUserIds.push(body.patient_id);

      const patientRes = await restAdmin(`patients?id=eq.${body.patient_id}`);
      const [patientRow] = (await patientRes.json()) as { org_id: string; display_name: string }[];
      expect(patientRow).toBeTruthy();
      expect(patientRow.org_id).toBe(physician.orgId);
      expect(patientRow.display_name).toBe(`Fictional Patient (${role})`);

      const rows = await auditRows('patient_created', body.patient_id);
      expect(rows.length).toBe(1);
    }
  });

  it('read_only is denied with 403 and creates no patient row', async () => {
    const readOnly = await createOrgAndMember('read_only', 'active', physician.orgId);
    cleanupUserIds.push(readOnly.userId);
    const aal1 = await signIn(readOnly.email, readOnly.password);
    const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);

    const email = `tc018-readonly-denied-${uniqueSuffix()}@example.test`;
    const res = await callFn('create-patient', aal2Token!, { email, display_name: 'Should Not Exist' });
    expect(res.status).toBe(403);

    const patientRes = await restAdmin(`patients?mrn=is.null&display_name=eq.Should Not Exist`);
    expect(((await patientRes.json()) as unknown[]).length).toBe(0);
  });

  it('a cross-org admin is denied with 403 (org_admin is never allowed to create a patient)', async () => {
    const otherOrgAdmin = await createOrgAndMember('org_admin');
    cleanupUserIds.push(otherOrgAdmin.userId);
    const aal1 = await signIn(otherOrgAdmin.email, otherOrgAdmin.password);
    const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);

    const email = `tc018-crossorg-admin-denied-${uniqueSuffix()}@example.test`;
    const res = await callFn('create-patient', aal2Token!, { email, display_name: 'Should Not Exist Either' });
    expect(res.status).toBe(403);
  });

  it('rejects an invalid email with 400 and the field name', async () => {
    const res = await callFn('create-patient', physicianAal2Token, { email: 'not-an-email', display_name: 'X' });
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string; field: string };
    expect(body.field).toBe('email');
  });

  it('rejects an mrn over 64 chars with 400 and the field name, creating no patient row', async () => {
    const email = `tc018-mrn-cap-${uniqueSuffix()}@example.test`;
    const res = await callFn('create-patient', physicianAal2Token, {
      email,
      display_name: 'Fictional Over-MRN Patient',
      mrn: 'M'.repeat(65),
    });
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: string; field: string };
    expect(body.field).toBe('mrn');

    const patientRes = await restAdmin(`patients?display_name=eq.Fictional%20Over-MRN%20Patient`);
    expect(((await patientRes.json()) as unknown[]).length).toBe(0);
  });

  it('accepts an mrn at exactly 64 chars', async () => {
    const email = `tc018-mrn-at-cap-${uniqueSuffix()}@example.test`;
    const res = await callFn('create-patient', physicianAal2Token, {
      email,
      display_name: 'Fictional At-Cap MRN Patient',
      mrn: 'M'.repeat(64),
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { patient_id: string };
    cleanupUserIds.push(body.patient_id);
  });

  it('rejects an oversized request body with 413 before it ever reaches validation', async () => {
    const email = `tc018-oversized-body-${uniqueSuffix()}@example.test`;
    const res = await callFn('create-patient', physicianAal2Token, {
      email,
      display_name: 'Fictional Oversized Body Patient',
      // Clara PR #23 review finding #2: this used to be stored verbatim in
      // patients.mrn (a real 20MB value made it through) - now rejected by
      // the body-size cap before display_name/email/mrn are even read.
      mrn: 'x'.repeat(20_000),
    });
    expect(res.status).toBe(413);

    const patientRes = await restAdmin(`patients?display_name=eq.Fictional%20Oversized%20Body%20Patient`);
    expect(((await patientRes.json()) as unknown[]).length).toBe(0);
  });

  it('refuses an email that already has an account, with no orphan patients row', async () => {
    const existing = await createOrgAndMember('read_only', 'active', physician.orgId);
    cleanupUserIds.push(existing.userId);

    const res = await callFn('create-patient', physicianAal2Token, {
      email: existing.email,
      display_name: 'Duplicate Email Attempt',
    });
    expect(res.status).toBe(409);

    const patientRes = await restAdmin(`patients?id=eq.${existing.userId}`);
    expect(((await patientRes.json()) as unknown[]).length).toBe(0);
  });
});
