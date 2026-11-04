// APP-01: invite-based patient sign-in with an emailed one-time code, end to
// end against local `supabase functions serve`:
//   create-patient (care coordinator) -> patient_invite email queued ->
//   patient-request-login-code -> patient_login_code email queued ->
//   patient-verify-login-code -> real session (the invite is accepted) ->
//   the session reads the patient's own row and onboarding status.
// Plus: enumeration-safe request, staff can't use patient codes, wrong code
// / lockout shapes, self-sign-up closed by default, delete-account re-auth
// by code.
//
// Each case sends its own x-forwarded-for so the per-IP throttles of one
// case never leak into another.
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { integrationEnvReady, SUPABASE_ANON_KEY, SUPABASE_FUNCTIONS_URL, SUPABASE_URL } from './setup';
import {
  callFn,
  createOrgAndMember,
  deleteUser,
  enrollAndVerifyTotp,
  restAdmin,
  signIn,
  uniqueSuffix,
} from './helpers';

function fakeIp(): string {
  const n = () => Math.floor(Math.random() * 250) + 1;
  return `10.${n()}.${n()}.${n()}`;
}

function publicFn(name: string, body: unknown, ip: string) {
  return fetch(`${SUPABASE_FUNCTIONS_URL}/${name}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_ANON_KEY!,
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      'x-forwarded-for': ip,
    },
    body: JSON.stringify(body),
  });
}

async function latestOutbox(userId: string, type: string) {
  const res = await restAdmin(
    `notification_outbox?user_id=eq.${userId}&type=eq.${type}&order=created_at.desc&limit=1`,
  );
  const rows = (await res.json()) as { payload: Record<string, unknown> }[];
  return rows[0];
}

async function emailedCode(userId: string): Promise<string> {
  const row = await latestOutbox(userId, 'patient_login_code');
  expect(row, 'a patient_login_code email was queued').toBeTruthy();
  return String(row.payload.token);
}

describe.skipIf(!integrationEnvReady)('patient code sign-in (APP-01)', () => {
  const cleanupUserIds: string[] = [];
  let coordinatorToken: string;
  let orgId: string;

  async function createInvitedPatient(label: string) {
    const email = `app01-${label}-${uniqueSuffix()}@example.test`;
    const res = await callFn('create-patient', coordinatorToken, {
      email,
      display_name: `Fictional Patient ${label}`,
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { patient_id: string; invite_sent: boolean };
    cleanupUserIds.push(body.patient_id);
    return { email, patientId: body.patient_id, inviteSent: body.invite_sent };
  }

  beforeAll(async () => {
    const coordinator = await createOrgAndMember('care_coordinator');
    cleanupUserIds.push(coordinator.userId);
    orgId = coordinator.orgId;
    const aal1 = await signIn(coordinator.email, coordinator.password);
    coordinatorToken = (await enrollAndVerifyTotp(aal1.access_token!)).aal2Token!;
  });

  afterAll(async () => {
    while (cleanupUserIds.length) await deleteUser(cleanupUserIds.pop()!);
  });

  it('create-patient sends a credential-free invite; the code signs the patient in and accepts it', async () => {
    const patient = await createInvitedPatient('happy');
    expect(patient.inviteSent).toBe(true);

    const invite = await latestOutbox(patient.patientId, 'patient_invite');
    expect(invite.payload.email).toBe(patient.email);
    expect(invite.payload).not.toHaveProperty('token');

    const inviteRows = (await (await restAdmin(`patient_invites?patient_id=eq.${patient.patientId}`)).json()) as {
      org_id: string;
      source: string;
      accepted_at: string | null;
    }[];
    expect(inviteRows).toHaveLength(1);
    expect(inviteRows[0].org_id).toBe(orgId);
    expect(inviteRows[0].source).toBe('staff');
    expect(inviteRows[0].accepted_at).toBeNull();

    const ip = fakeIp();
    const req = await publicFn('patient-request-login-code', { email: patient.email.toUpperCase() }, ip);
    expect(req.status).toBe(200);
    expect(await req.json()).toEqual({ status: 'ok' });

    const code = await emailedCode(patient.patientId);
    expect(code).toMatch(/^\d{6}$/);

    const verify = await publicFn('patient-verify-login-code', { email: patient.email, code }, ip);
    expect(verify.status).toBe(200);
    const session = (await verify.json()) as { access_token: string; refresh_token: string; user: { id: string } };
    expect(session.access_token).toBeTruthy();
    expect(session.refresh_token).toBeTruthy();
    expect(session.user.id).toBe(patient.patientId);

    const accepted = (await (await restAdmin(`patient_invites?patient_id=eq.${patient.patientId}`)).json()) as {
      accepted_at: string | null;
    }[];
    expect(accepted[0].accepted_at).not.toBeNull();

    // The session is a real patient session: it reads its own record and
    // the onboarding gate (consents + profile still to do).
    const own = await fetch(`${SUPABASE_URL}/rest/v1/patients?select=id`, {
      headers: { apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${session.access_token}` },
    });
    expect(((await own.json()) as { id: string }[]).map((r) => r.id)).toEqual([patient.patientId]);
    const status = await fetch(`${SUPABASE_URL}/rest/v1/rpc/patient_onboarding_status`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SUPABASE_ANON_KEY!,
        Authorization: `Bearer ${session.access_token}`,
      },
      body: '{}',
    });
    const gate = (await status.json()) as { linked: boolean; missing_consents: unknown[]; profile_complete: boolean };
    expect(gate.linked).toBe(true);
    expect(gate.missing_consents).toHaveLength(3);
    expect(gate.profile_complete).toBe(false);

    const reuse = await publicFn('patient-verify-login-code', { email: patient.email, code }, ip);
    expect(reuse.status).toBe(401);
    expect(((await reuse.json()) as { error: string }).error).toBe('code_expired');
  });

  it('request is enumeration-safe: unknown and staff emails get the same ok, and no email', async () => {
    const ip = fakeIp();
    const unknown = await publicFn('patient-request-login-code', { email: `app01-nobody-${uniqueSuffix()}@example.test` }, ip);
    expect(unknown.status).toBe(200);
    expect(await unknown.json()).toEqual({ status: 'ok' });

    const staff = await createOrgAndMember('physician', 'active', orgId);
    cleanupUserIds.push(staff.userId);
    const staffReq = await publicFn('patient-request-login-code', { email: staff.email }, ip);
    expect(staffReq.status).toBe(200);
    expect(await staffReq.json()).toEqual({ status: 'ok' });
    expect(await latestOutbox(staff.userId, 'patient_login_code')).toBeUndefined();

    const staffVerify = await publicFn('patient-verify-login-code', { email: staff.email, code: '123456' }, ip);
    expect(staffVerify.status).toBe(401);
    expect(((await staffVerify.json()) as { error: string }).error).toBe('invalid_code');
  });

  it('a malformed code is refused without spending a try', async () => {
    const patient = await createInvitedPatient('malformed');
    const ip = fakeIp();
    await publicFn('patient-request-login-code', { email: patient.email }, ip);
    for (const bad of ['12345', 'abcdef', '']) {
      const res = await publicFn('patient-verify-login-code', { email: patient.email, code: bad }, ip);
      expect(res.status).toBe(400);
    }
    const code = await emailedCode(patient.patientId);
    const ok = await publicFn('patient-verify-login-code', { email: patient.email, code }, ip);
    expect(ok.status).toBe(200);
  });

  it('five wrong codes lock the email; the right code is then refused with the time left', async () => {
    const patient = await createInvitedPatient('lockout');
    const ip = fakeIp();
    await publicFn('patient-request-login-code', { email: patient.email }, ip);
    const code = await emailedCode(patient.patientId);
    const wrong = code === '000000' ? '111111' : '000000';

    for (let i = 1; i <= 4; i++) {
      const res = await publicFn('patient-verify-login-code', { email: patient.email, code: wrong }, ip);
      expect(res.status).toBe(401);
      expect(((await res.json()) as { error: string }).error).toBe('invalid_code');
    }
    const fifth = await publicFn('patient-verify-login-code', { email: patient.email, code: wrong }, ip);
    expect(fifth.status).toBe(429);
    const locked = (await fifth.json()) as { error: string; retry_after_seconds: number };
    expect(locked.error).toBe('locked');
    expect(locked.retry_after_seconds).toBeGreaterThan(0);

    const right = await publicFn('patient-verify-login-code', { email: patient.email, code }, ip);
    expect(right.status).toBe(429);
  });

  it('self sign-up is closed by default (signup_disabled), and the app is told so', async () => {
    const ip = fakeIp();
    const res = await publicFn(
      'patient-signup',
      { email: `app01-selfsignup-${uniqueSuffix()}@example.test`, password: 'Correct-Horse-Battery-99!' },
      ip,
    );
    // Closed unless ZYNDIO_DEFAULT_ORG_ID's org has patient_self_signup_enabled.
    expect(res.status).toBe(403);
    expect(((await res.json()) as { error: string }).error).toBe('signup_disabled');

    const config = await publicFn('patient-auth-config', {}, ip);
    expect(config.status).toBe(200);
    expect(((await config.json()) as { self_signup_enabled: boolean }).self_signup_enabled).toBe(false);
  });

  it('an invited (passwordless) patient can delete their account with a fresh code', async () => {
    const patient = await createInvitedPatient('delete');
    const ip = fakeIp();
    await publicFn('patient-request-login-code', { email: patient.email }, ip);
    const signInRes = await publicFn(
      'patient-verify-login-code',
      { email: patient.email, code: await emailedCode(patient.patientId) },
      ip,
    );
    const session = (await signInRes.json()) as { access_token: string };

    const wrong = await callFn('patient-delete-account', session.access_token, { code: '000000' });
    expect([401, 429]).toContain(wrong.status);

    await publicFn('patient-request-login-code', { email: patient.email }, ip);
    const code = await emailedCode(patient.patientId);
    const res = await callFn('patient-delete-account', session.access_token, { code });
    expect(res.status).toBe(200);

    const gone = (await (await restAdmin(`patients?id=eq.${patient.patientId}`)).json()) as unknown[];
    expect(gone).toHaveLength(0);
    cleanupUserIds.splice(cleanupUserIds.indexOf(patient.patientId), 1);
  });
});
