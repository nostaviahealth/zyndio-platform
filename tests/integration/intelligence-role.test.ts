// TC-022 item 4 (Clara, PR #11 review): the intelligence function must check
// the caller's role BEFORE it validates the request body, so a caller with
// the wrong role (the bare anon key, or the service-role key, instead of a
// signed-in user's token) gets 403 - never a 400 that reveals the body shape,
// and never a call through to the AI provider.
import { describe, it, expect } from 'vitest';
import { integrationEnvReady, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY } from './setup';
import {
  callFn,
  createOrgAndMember,
  createUser,
  deleteUser,
  restAdmin,
  seedPlatformAdmin,
  seedSelfSignupPatient,
  signIn,
  uniqueSuffix,
} from './helpers';

describe.skipIf(!integrationEnvReady)('intelligence role check (TC-022 #4)', () => {
  it('answers 403 to the anon key with an invalid body (role checked first)', async () => {
    const res = await callFn('intelligence', SUPABASE_ANON_KEY!, {});
    await res.text();
    expect(res.status).toBe(403);
  });

  it('answers 403 to the anon key with a well-formed body too', async () => {
    const res = await callFn('intelligence', SUPABASE_ANON_KEY!, { messages: [{ role: 'user', content: 'hi' }] });
    await res.text();
    expect(res.status).toBe(403);
  });

  it('answers 403 to the service-role key (not a signed-in user)', async () => {
    const res = await callFn('intelligence', SUPABASE_SERVICE_ROLE_KEY!, {});
    await res.text();
    expect(res.status).toBe(403);
  });

  // TC-021 item 9 changed who may call the function: only patients. A
  // signed-in non-patient now gets 403 (see the patients-only suite below),
  // so this TC-022 check - role first, then body - uses a patient account.
  it('still answers 400 to a signed-in patient with an invalid body', async () => {
    const user = await createUser('tc022-intel');
    await seedSelfSignupPatient(user.userId);
    try {
      const session = await signIn(user.email, user.password);
      const res = await callFn('intelligence', session.access_token!, {});
      const body = (await res.json()) as { error?: string };
      expect(res.status).toBe(400);
      expect(body.error).toBe('messages array is required');
    } finally {
      await deleteUser(user.userId);
    }
  });
});

// TC-021 item 9 (Henry ruling): intelligence is for patients only, on their
// own data. Every staff role, the Zyndio admin and any signed-in non-patient
// get 403 - with a WELL-FORMED body, so the 403 is the access rule and not a
// body error. A patient naming another patient's id gets 403 too.
describe.skipIf(!integrationEnvReady)('intelligence is patients-only, own data (TC-021 #9)', () => {
  const goodBody = { messages: [{ role: 'user', content: 'What does my latest result mean?' }] };

  async function asStaff(role: string, withPatientMarker = false) {
    const member = await createOrgAndMember(role);
    if (withPatientMarker) await seedSelfSignupPatient(member.userId);
    try {
      const session = await signIn(member.email, member.password);
      const res = await callFn('intelligence', session.access_token!, goodBody);
      return { status: res.status, body: (await res.json()) as { error?: string } };
    } finally {
      await deleteUser(member.userId);
    }
  }

  for (const role of ['org_admin', 'physician', 'care_coordinator', 'read_only']) {
    it(`answers 403 to staff role ${role}`, async () => {
      const { status, body } = await asStaff(role);
      expect(status).toBe(403);
      expect(body.error).toBe('intelligence_patients_only');
    });
  }

  it('answers 403 to a staff member who also has a patient-app marker', async () => {
    const { status, body } = await asStaff('physician', true);
    expect(status).toBe(403);
    expect(body.error).toBe('intelligence_patients_only');
  });

  it('answers 403 to the Zyndio (platform) admin', async () => {
    const user = await createUser('tc021-intel-zadmin');
    await seedPlatformAdmin(user.userId);
    try {
      const session = await signIn(user.email, user.password);
      const res = await callFn('intelligence', session.access_token!, goodBody);
      const body = (await res.json()) as { error?: string };
      expect(res.status).toBe(403);
      expect(body.error).toBe('intelligence_patients_only');
    } finally {
      await deleteUser(user.userId);
    }
  });

  it('answers 403 to a signed-in user who is not a patient', async () => {
    const user = await createUser('tc021-intel-nobody');
    try {
      const session = await signIn(user.email, user.password);
      const res = await callFn('intelligence', session.access_token!, goodBody);
      const body = (await res.json()) as { error?: string };
      expect(res.status).toBe(403);
      expect(body.error).toBe('intelligence_patients_only');
    } finally {
      await deleteUser(user.userId);
    }
  });

  it("answers 403 to a patient asking about another patient's data", async () => {
    const a = await createUser('tc021-intel-pa');
    const b = await createUser('tc021-intel-pb');
    await seedSelfSignupPatient(a.userId);
    await seedSelfSignupPatient(b.userId);
    try {
      const session = await signIn(a.email, a.password);
      const res = await callFn('intelligence', session.access_token!, { ...goodBody, patient_id: b.userId });
      const body = (await res.json()) as { error?: string };
      expect(res.status).toBe(403);
      expect(body.error).toBe('intelligence_own_data_only');
    } finally {
      await deleteUser(a.userId);
      await deleteUser(b.userId);
    }
  });

  it('lets a self-signup patient through on their own data (past the access check)', async () => {
    const a = await createUser('tc021-intel-own');
    await seedSelfSignupPatient(a.userId);
    try {
      const session = await signIn(a.email, a.password);
      const res = await callFn('intelligence', session.access_token!, { ...goodBody, patient_id: a.userId });
      const body = (await res.json().catch(() => ({}))) as { error?: string };
      // CI has no AI key, so a let-through call ends at the provider step
      // (500 'AI service not configured'); what matters is no access 403.
      expect(res.status).not.toBe(403);
      expect(body.error).not.toBe('intelligence_patients_only');
      expect(body.error).not.toBe('intelligence_own_data_only');
    } finally {
      await deleteUser(a.userId);
    }
  });

  it('lets a clinic patient record (patients.id = auth user) through', async () => {
    const a = await createUser('tc021-intel-clinic');
    const orgRes = await restAdmin('organizations', {
      method: 'POST',
      body: JSON.stringify({ name: `Integration test org ${uniqueSuffix()}` }),
    });
    const [org] = (await orgRes.json()) as { id: string }[];
    await restAdmin('patients', {
      method: 'POST',
      body: JSON.stringify({ id: a.userId, org_id: org.id, display_name: 'Robin Avery' }),
    });
    try {
      const session = await signIn(a.email, a.password);
      const res = await callFn('intelligence', session.access_token!, goodBody);
      await res.text();
      expect(res.status).not.toBe(403);
    } finally {
      await deleteUser(a.userId);
    }
  });
});
