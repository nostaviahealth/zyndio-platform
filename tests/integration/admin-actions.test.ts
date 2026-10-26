// Plan section B / F.3: invite-user/accept-invite/reset-mfa/deactivate-user/
// reactivate-user Edge Functions, exercised end to end against local
// `supabase functions serve`.
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_FUNCTIONS_URL } from './setup';
import { callFn, createOrgAndMember, deleteUser, enrollAndVerifyTotp, restAdmin, seedPlatformAdmin, signIn } from './helpers';

describe.skipIf(!integrationEnvReady)('admin-actions', () => {
  const cleanupUserIds: string[] = [];
  let admin: Awaited<ReturnType<typeof createOrgAndMember>>;
  let adminAal1Token: string;
  let adminAal2Token: string;

  beforeAll(async () => {
    admin = await createOrgAndMember('org_admin');
    cleanupUserIds.push(admin.userId);
    const aal1 = await signIn(admin.email, admin.password);
    adminAal1Token = aal1.access_token!;
    const { aal2Token } = await enrollAndVerifyTotp(adminAal1Token);
    adminAal2Token = aal2Token!;
  });

  afterAll(async () => {
    while (cleanupUserIds.length) await deleteUser(cleanupUserIds.pop()!);
  });

  it('rejects an aal1 admin session with 403', async () => {
    const res = await callFn('invite-user', adminAal1Token, { email: `tc005-aal1-${Date.now()}@example.test`, role: 'physician' });
    expect(res.status).toBe(403);
  });

  it('rejects a non-admin caller with 403', async () => {
    const nonAdmin = await createOrgAndMember('physician', 'active', admin.orgId);
    cleanupUserIds.push(nonAdmin.userId);
    const aal1 = await signIn(nonAdmin.email, nonAdmin.password);
    const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);

    const res = await callFn('invite-user', aal2Token!, { email: `tc005-nonadmin-${Date.now()}@example.test`, role: 'physician' });
    expect(res.status).toBe(403);
  });

  it('invite -> accept refuses a blocklisted password and accepts a strong one', async () => {
    const email = `tc005-invite-${Date.now()}@example.test`;
    const inviteRes = await callFn('invite-user', adminAal2Token, { email, role: 'physician' });
    expect(inviteRes.status).toBe(200);

    const notifRes = await restAdmin(
      `notification_outbox?type=eq.invite&payload->>email=eq.${encodeURIComponent(email)}&order=created_at.desc&limit=1`
    );
    const [notif] = (await notifRes.json()) as { payload: { token: string } }[];
    expect(notif).toBeTruthy();

    const badRes = await fetch(`${SUPABASE_FUNCTIONS_URL}/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify({ token: notif.payload.token, password: 'password1234' }),
    });
    expect(badRes.status).toBe(400);

    const goodPassword = 'Zy-Admin-Actions-Strong-77!';
    const goodRes = await fetch(`${SUPABASE_FUNCTIONS_URL}/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify({ token: notif.payload.token, password: goodPassword }),
    });
    expect(goodRes.status).toBe(200);

    const session = await signIn(email, goodPassword);
    expect(session.access_token).toBeTruthy();
    const sub = JSON.parse(Buffer.from(session.access_token!.split('.')[1], 'base64').toString('utf8')).sub as string;
    cleanupUserIds.push(sub);
  });

  // Review group A / Henry ruling 1: reset-mfa is Zyndio-admin-only now, not
  // org-admin - an org admin can only *request* a reset (request_mfa_reset()
  // RPC, covered by supabase/tests/500_review_probes.sql and the schema
  // migration's RPC itself). This test used to call reset-mfa as the org
  // admin and expect 200; that's wrong per Henry and is corrected here
  // (not weakened) to expect 403, plus new coverage for the Zyndio-admin
  // path that actually performs the reset.
  it('reset-mfa: org admin gets 403 (request-only); Zyndio admin can reset, signs out, audits + notifies', async () => {
    const selfReset = await callFn('reset-mfa', adminAal2Token, { target_user_id: admin.userId });
    expect(selfReset.status).toBe(403);

    const target = await createOrgAndMember('care_coordinator', 'active', admin.orgId);
    cleanupUserIds.push(target.userId);
    const targetAal1 = await signIn(target.email, target.password);
    await enrollAndVerifyTotp(targetAal1.access_token!);

    const orgAdminResetRes = await callFn('reset-mfa', adminAal2Token, { target_user_id: target.userId });
    expect(orgAdminResetRes.status).toBe(403);

    const zyndioAdmin = await createOrgAndMember('org_admin');
    cleanupUserIds.push(zyndioAdmin.userId);
    await seedPlatformAdmin(zyndioAdmin.userId);
    const zyndioAal1 = await signIn(zyndioAdmin.email, zyndioAdmin.password);
    const { aal2Token: zyndioAal2Token } = await enrollAndVerifyTotp(zyndioAal1.access_token!);

    const zyndioSelfReset = await callFn('reset-mfa', zyndioAal2Token!, { target_user_id: zyndioAdmin.userId });
    expect(zyndioSelfReset.status).toBe(403);

    const resetRes = await callFn('reset-mfa', zyndioAal2Token!, { target_user_id: target.userId });
    expect(resetRes.status).toBe(200);

    const auditRes = await restAdmin(`audit_log?event_type=eq.mfa_reset&target_user_id=eq.${target.userId}`);
    expect(((await auditRes.json()) as unknown[]).length).toBe(1);

    const outboxRes = await restAdmin(`notification_outbox?type=eq.mfa_reset&user_id=eq.${target.userId}`);
    expect(((await outboxRes.json()) as unknown[]).length).toBe(1);

    const refreshRes = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify({ refresh_token: targetAal1.refresh_token }),
    });
    expect(refreshRes.status).not.toBe(200);
  });

  it('request_mfa_reset: an org admin can request a reset (audited), but it resets nothing', async () => {
    const target = await createOrgAndMember('physician', 'active', admin.orgId);
    cleanupUserIds.push(target.userId);
    const targetAal1 = await signIn(target.email, target.password);
    await enrollAndVerifyTotp(targetAal1.access_token!);

    const rpcRes = await restAdmin('rpc/request_mfa_reset', {
      method: 'POST',
      headers: { Authorization: `Bearer ${adminAal2Token}`, apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify({ p_target_user_id: target.userId }),
    });
    expect(rpcRes.status).toBeLessThan(300);

    const auditRes = await restAdmin(`audit_log?event_type=eq.mfa_reset_requested&target_user_id=eq.${target.userId}`);
    expect(((await auditRes.json()) as unknown[]).length).toBe(1);

    // request_mfa_reset resets nothing - no mandatory-reenrollment flag was
    // set for the target, unlike an actual reset-mfa.
    const reenrolRes = await restAdmin(`mfa_reenrollment_required?user_id=eq.${target.userId}`);
    expect(((await reenrolRes.json()) as unknown[]).length).toBe(0);

    // the target can still sign in and reach aal2 with their existing factor.
    const stillWorks = await signIn(target.email, target.password);
    expect(stillWorks.access_token).toBeTruthy();
  });

  it('deactivate-user then reactivate-user round-trips org_members.status', async () => {
    const target = await createOrgAndMember('read_only', 'active', admin.orgId);
    cleanupUserIds.push(target.userId);

    const deactivateRes = await callFn('deactivate-user', adminAal2Token, { target_user_id: target.userId });
    expect(deactivateRes.status).toBe(200);
    const afterDeactivate = await restAdmin(`org_members?user_id=eq.${target.userId}&select=status`);
    expect(((await afterDeactivate.json()) as { status: string }[])[0].status).toBe('deactivated');

    const reactivateRes = await callFn('reactivate-user', adminAal2Token, { target_user_id: target.userId });
    expect(reactivateRes.status).toBe(200);
    const afterReactivate = await restAdmin(`org_members?user_id=eq.${target.userId}&select=status`);
    expect(((await afterReactivate.json()) as { status: string }[])[0].status).toBe('active');
  });
});
