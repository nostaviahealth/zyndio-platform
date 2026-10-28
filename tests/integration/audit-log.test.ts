// Plan section E: one block per audit event type, each asserting exactly one
// row is written for the triggering action.
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_FUNCTIONS_URL } from './setup';
import {
  anonSignIn,
  auditRows,
  callFn,
  createOrgAndMember,
  createUser,
  deleteUser,
  enrollAndVerifyTotp,
  mfaChallenge,
  mfaVerify,
  restAdmin,
  seedPlatformAdmin,
  signIn,
} from './helpers';

describe.skipIf(!integrationEnvReady)('audit-log', () => {
  const cleanupUserIds: string[] = [];
  let admin: Awaited<ReturnType<typeof createOrgAndMember>>;
  let adminAal2Token: string;

  beforeAll(async () => {
    admin = await createOrgAndMember('org_admin');
    cleanupUserIds.push(admin.userId);
    const aal1 = await signIn(admin.email, admin.password);
    const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);
    adminAal2Token = aal2Token!;
  });

  afterAll(async () => {
    while (cleanupUserIds.length) await deleteUser(cleanupUserIds.pop()!);
  });

  it('invite_sent: exactly one row per invite-user call', async () => {
    const email = `tc005-audit-invite-${Date.now()}@example.test`;
    const res = await callFn('invite-user', adminAal2Token, { email, role: 'physician' });
    expect(res.status).toBe(200);
    const inviteRow = await restAdmin(`audit_log?event_type=eq.invite_sent&metadata->>email=eq.${encodeURIComponent(email)}`);
    expect(((await inviteRow.json()) as unknown[]).length).toBe(1);
  });

  it('invite_accepted: exactly one row when the invitee accepts', async () => {
    const email = `tc005-audit-accept-${Date.now()}@example.test`;
    await callFn('invite-user', adminAal2Token, { email, role: 'physician' });
    const notifRes = await restAdmin(
      `notification_outbox?type=eq.invite&payload->>email=eq.${encodeURIComponent(email)}&order=created_at.desc&limit=1`
    );
    const [notif] = (await notifRes.json()) as { payload: { token: string } }[];

    const acceptRes = await fetch(`${SUPABASE_FUNCTIONS_URL}/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify({ token: notif.payload.token, password: 'Zy-Audit-Strong-Pw-77!' }),
    });
    expect(acceptRes.status).toBe(200);

    const accepted = await signIn(email, 'Zy-Audit-Strong-Pw-77!');
    const sub = JSON.parse(Buffer.from(accepted.access_token!.split('.')[1], 'base64').toString('utf8')).sub as string;
    cleanupUserIds.push(sub);

    const rows = await auditRows('invite_accepted', sub);
    expect(rows.length).toBe(1);
  });

  // Review group A / Henry ruling 1: reset-mfa is Zyndio-admin-only now - an
  // org_admin calling it is 403 (see tests/integration/admin-actions.test.ts
  // for that coverage). This test used to drive the reset with the org_admin
  // token and expect 200; corrected (not weakened) to use a seeded Zyndio
  // admin instead, which is the only actor that can actually produce an
  // mfa_reset audit row.
  it('mfa_reset: exactly one row when a Zyndio admin resets another member', async () => {
    const target = await createOrgAndMember('care_coordinator', 'active', admin.orgId);
    cleanupUserIds.push(target.userId);
    const targetAal1 = await signIn(target.email, target.password);
    await enrollAndVerifyTotp(targetAal1.access_token!);

    const zyndioAdmin = await createOrgAndMember('org_admin');
    cleanupUserIds.push(zyndioAdmin.userId);
    await seedPlatformAdmin(zyndioAdmin.userId);
    const zyndioAal1 = await signIn(zyndioAdmin.email, zyndioAdmin.password);
    const { aal2Token: zyndioAal2Token } = await enrollAndVerifyTotp(zyndioAal1.access_token!);

    const res = await callFn('reset-mfa', zyndioAal2Token!, { target_user_id: target.userId });
    expect(res.status).toBe(200);
    const rows = await auditRows('mfa_reset', target.userId);
    expect(rows.length).toBe(1);
  });

  it('user_deactivated / user_reactivated: exactly one row each', async () => {
    const target = await createOrgAndMember('read_only', 'active', admin.orgId);
    cleanupUserIds.push(target.userId);

    const deactivateRes = await callFn('deactivate-user', adminAal2Token, { target_user_id: target.userId });
    expect(deactivateRes.status).toBe(200);
    expect((await auditRows('user_deactivated', target.userId)).length).toBe(1);

    const reactivateRes = await callFn('reactivate-user', adminAal2Token, { target_user_id: target.userId });
    expect(reactivateRes.status).toBe(200);
    expect((await auditRows('user_reactivated', target.userId)).length).toBe(1);
  });

  it('re_enrolment_started: exactly one row when recovery-reenrol removes a factor', async () => {
    const user = await createUser('tc005-audit-reenrol');
    cleanupUserIds.push(user.userId);
    const aal1 = await signIn(user.email, user.password);
    const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);

    const codesRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/generate_recovery_codes`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${aal2Token}` },
      body: '{}',
    });
    const codes = (await codesRes.json()) as string[];
    const freshAal1 = await signIn(user.email, user.password);
    await fetch(`${SUPABASE_URL}/rest/v1/rpc/consume_recovery_code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${freshAal1.access_token}` },
      body: JSON.stringify({ p_code: codes[0] }),
    });

    const reenrolRes = await fetch(`${SUPABASE_FUNCTIONS_URL}/recovery-reenrol`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${freshAal1.access_token}` },
    });
    expect(reenrolRes.status).toBe(200);
    expect((await auditRows('re_enrolment_started', user.userId)).length).toBe(1);
  });

  it('password_lockout: exactly one row for the strike that crosses the threshold', async () => {
    const user = await createUser('tc005-audit-pwlock');
    cleanupUserIds.push(user.userId);
    for (let i = 0; i < 5; i++) await anonSignIn(user.email, 'definitely-wrong-password');
    expect((await auditRows('password_lockout', user.userId)).length).toBe(1);
  });

  it('mfa_lockout: exactly one row for the strike that crosses the threshold', async () => {
    const user = await createUser('tc005-audit-mfalock');
    cleanupUserIds.push(user.userId);
    const aal1 = await signIn(user.email, user.password);
    const { factorId } = await enrollAndVerifyTotp(aal1.access_token!);
    const freshAal1 = await signIn(user.email, user.password);
    for (let i = 0; i < 5; i++) {
      const challenge = (await (await mfaChallenge(factorId, freshAal1.access_token!)).json()) as { id: string };
      await mfaVerify(factorId, challenge.id, '000000', freshAal1.access_token!);
    }
    expect((await auditRows('mfa_lockout', user.userId)).length).toBe(1);
  });

  it('recovery_codes_regenerated / recovery_code_used: exactly one row each', async () => {
    const user = await createUser('tc005-audit-recovery');
    cleanupUserIds.push(user.userId);
    const aal1 = await signIn(user.email, user.password);
    const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);
    const codesRes = await fetch(`${SUPABASE_URL}/rest/v1/rpc/generate_recovery_codes`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${aal2Token}` },
      body: '{}',
    });
    const codes = (await codesRes.json()) as string[];
    expect((await auditRows('recovery_codes_regenerated', user.userId)).length).toBe(1);

    const freshAal1 = await signIn(user.email, user.password);
    await fetch(`${SUPABASE_URL}/rest/v1/rpc/consume_recovery_code`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY!, Authorization: `Bearer ${freshAal1.access_token}` },
      body: JSON.stringify({ p_code: codes[0] }),
    });
    expect((await auditRows('recovery_code_used', user.userId)).length).toBe(1);
  });
});
