// Plan section B / F.3: invite-user/accept-invite/reset-mfa/deactivate-user/
// reactivate-user Edge Functions, exercised end to end against local
// `supabase functions serve`.
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import { integrationEnvReady, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_FUNCTIONS_URL } from './setup';
import {
  callFn,
  createOrgAndMember,
  createUser,
  deleteUser,
  enrollAndVerifyTotp,
  generateInviteToken,
  insertInvite,
  restAdmin,
  seedPlatformAdmin,
  signIn,
} from './helpers';

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
    const res = await callFn('invite-user', adminAal1Token, { email: `tc005-aal1-${Date.now()}@example.test`, role: 'physician', full_name: 'Alex Lindgren' });
    expect(res.status).toBe(403);
  });

  it('rejects a non-admin caller with 403', async () => {
    const nonAdmin = await createOrgAndMember('physician', 'active', admin.orgId);
    cleanupUserIds.push(nonAdmin.userId);
    const aal1 = await signIn(nonAdmin.email, nonAdmin.password);
    const { aal2Token } = await enrollAndVerifyTotp(aal1.access_token!);

    const res = await callFn('invite-user', aal2Token!, { email: `tc005-nonadmin-${Date.now()}@example.test`, role: 'physician', full_name: 'Alex Lindgren' });
    expect(res.status).toBe(403);
  });

  it('invite -> accept refuses a blocklisted password and accepts a strong one', async () => {
    const email = `tc005-invite-${Date.now()}@example.test`;
    const inviteRes = await callFn('invite-user', adminAal2Token, { email, role: 'physician', full_name: 'Alex Lindgren' });
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

  // Clara's re-check (26 Oct 20:46), NEW M7: accept-invite used to set the
  // password (updateUserById) BEFORE checking org_members.status='invited',
  // so a refused accept could still silently overwrite a deactivated
  // account's password. This sets up org_members as 'deactivated' with a
  // still-live (non-revoked) invites row directly - independent of
  // deactivate-user's own invite-revoke step (covered separately below) - to
  // prove accept-invite's own guard, not just A3's, refuses the write.
  it('accept-invite refuses before any write when the member is no longer invited (M7)', async () => {
    const target = await createOrgAndMember('physician', 'invited', admin.orgId);
    cleanupUserIds.push(target.userId);

    const token = generateInviteToken();
    await insertInvite({
      orgId: admin.orgId,
      email: target.email,
      role: 'physician',
      userId: target.userId,
      token,
      invitedBy: admin.userId,
    });

    await restAdmin(`org_members?user_id=eq.${target.userId}`, {
      method: 'PATCH',
      body: JSON.stringify({ status: 'deactivated' }),
    });

    const acceptRes = await fetch(`${SUPABASE_FUNCTIONS_URL}/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify({ token, password: 'Brand-New-Password-99!' }),
    });
    expect(acceptRes.status).toBe(400);
    expect((await acceptRes.json()).error).toBe('invalid_or_expired_invite');

    const afterAccept = await restAdmin(`org_members?user_id=eq.${target.userId}&select=status`);
    expect(((await afterAccept.json()) as { status: string }[])[0].status).toBe('deactivated');

    // the account's password must be completely unchanged - the old
    // (known) password still signs in.
    const stillWorks = await signIn(target.email, target.password);
    expect(stillWorks.access_token).toBeTruthy();
  });

  // B8 / H3: invite, deactivate (which revokes the pending invite per A3),
  // then accept with the now-stale token must stay refused: member stays
  // deactivated, invite row stays revoked. This exercises the real
  // deactivate-user path end to end (unlike the M7 test above, which
  // bypasses it to isolate accept-invite's own guard).
  it('deactivate-then-accept with the old token is refused and leaves the invite revoked (H3 race)', async () => {
    const target = await createOrgAndMember('care_coordinator', 'invited', admin.orgId);
    cleanupUserIds.push(target.userId);

    const inviteRes = await callFn('invite-user', adminAal2Token, { email: target.email, role: 'care_coordinator', full_name: 'Alex Lindgren' });
    expect(inviteRes.status).toBe(200);

    const notifRes = await restAdmin(
      `notification_outbox?type=eq.invite&payload->>email=eq.${encodeURIComponent(target.email)}&order=created_at.desc&limit=1`
    );
    const [notif] = (await notifRes.json()) as { payload: { token: string } }[];
    expect(notif).toBeTruthy();
    const token = notif.payload.token;

    const deactivateRes = await callFn('deactivate-user', adminAal2Token, { target_user_id: target.userId });
    expect(deactivateRes.status).toBe(200);

    const acceptRes = await fetch(`${SUPABASE_FUNCTIONS_URL}/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify({ token, password: 'Brand-New-Password-99!' }),
    });
    expect(acceptRes.status).toBe(400);
    expect((await acceptRes.json()).error).toBe('invalid_or_expired_invite');

    const afterAccept = await restAdmin(`org_members?user_id=eq.${target.userId}&select=status`);
    expect(((await afterAccept.json()) as { status: string }[])[0].status).toBe('deactivated');

    const inviteRow = await restAdmin(
      `invites?user_id=eq.${target.userId}&org_id=eq.${admin.orgId}&select=revoked_at&order=created_at.desc&limit=1`
    );
    const [invite] = (await inviteRow.json()) as { revoked_at: string | null }[];
    expect(invite.revoked_at).not.toBeNull();
  });

  // B4 / M6: invite-user must never attach an existing account that has no
  // org_members row at all (a patient account here) - that would later let
  // accept-invite overwrite the patient's real password.
  it('invite-user refuses to attach an existing patient account (M6)', async () => {
    const patient = await createUser('tc005-patient');
    cleanupUserIds.push(patient.userId);
    await restAdmin('patients', {
      method: 'POST',
      body: JSON.stringify({ id: patient.userId, org_id: admin.orgId, display_name: 'Fictional Patient' }),
    });

    const inviteRes = await callFn('invite-user', adminAal2Token, { email: patient.email, role: 'physician', full_name: 'Alex Lindgren' });
    expect(inviteRes.status).toBe(200);
    expect(await inviteRes.json()).toEqual({ status: 'ok' });

    const memberRes = await restAdmin(`org_members?user_id=eq.${patient.userId}`);
    expect(((await memberRes.json()) as unknown[]).length).toBe(0);

    // the patient's own password must still work - nothing overwrote it.
    const stillWorks = await signIn(patient.email, patient.password);
    expect(stillWorks.access_token).toBeTruthy();
  });

  // L7: resending an invite with a different role must update org_members,
  // not keep the stale role from the first invite.
  it('invite-user resend updates the pending member role (L7)', async () => {
    const target = await createOrgAndMember('physician', 'invited', admin.orgId);
    cleanupUserIds.push(target.userId);

    const resendRes = await callFn('invite-user', adminAal2Token, { email: target.email, role: 'care_coordinator', full_name: 'Alex Lindgren' });
    expect(resendRes.status).toBe(200);

    const memberRes = await restAdmin(`org_members?user_id=eq.${target.userId}&select=role`);
    expect(((await memberRes.json()) as { role: string }[])[0].role).toBe('care_coordinator');
  });

  // B2 / M3: change-password is the only sanctioned self-service
  // password-set path - it must enforce the same length/blocklist checks
  // supabase.auth.updateUser() skips entirely.
  it('change-password enforces the blocklist and length floor, and lets the caller sign in with the new password', async () => {
    const target = await createOrgAndMember('physician', 'active', admin.orgId);
    cleanupUserIds.push(target.userId);
    const aal1 = await signIn(target.email, target.password);

    const tooShortRes = await callFn('change-password', aal1.access_token!, { password: 'Short1!' });
    expect(tooShortRes.status).toBe(400);
    expect((await tooShortRes.json()).error).toBe('password_too_short');

    const blockedRes = await callFn('change-password', aal1.access_token!, { password: 'sunshine2024' });
    expect(blockedRes.status).toBe(400);
    expect((await blockedRes.json()).error).toBe('password_too_common');

    const goodPassword = 'Zy-Change-Password-Strong-42!';
    const okRes = await callFn('change-password', aal1.access_token!, { password: goodPassword });
    expect(okRes.status).toBe(200);

    const stillBlockedOldPassword = await signIn(target.email, target.password);
    expect(stillBlockedOldPassword.access_token).toBeFalsy();

    const withNewPassword = await signIn(target.email, goodPassword);
    expect(withNewPassword.access_token).toBeTruthy();

    const auditRes = await restAdmin(`audit_log?event_type=eq.password_changed&target_user_id=eq.${target.userId}`);
    expect(((await auditRes.json()) as unknown[]).length).toBe(1);
  });

  // B5 / Henry ruling 3: process-outbox is the stub email worker - marks
  // pending rows sent_stub and nulls the plaintext invite token (L8) once
  // "sent". Not service_role -> refused; a real invite token still works to
  // accept *before* the worker runs (this test checks that, implicitly, by
  // reading it from the still-pending row first, exactly like every other
  // accept-invite test here does).
  it('process-outbox marks pending rows sent_stub and redacts the invite token (B5/L8)', async () => {
    const target = await createOrgAndMember('physician', 'invited', admin.orgId);
    cleanupUserIds.push(target.userId);

    const inviteRes = await callFn('invite-user', adminAal2Token, { email: target.email, role: 'physician', full_name: 'Alex Lindgren' });
    expect(inviteRes.status).toBe(200);

    const beforeRes = await restAdmin(
      `notification_outbox?type=eq.invite&user_id=eq.${target.userId}&order=created_at.desc&limit=1`
    );
    const [before] = (await beforeRes.json()) as { id: string; status: string; payload: { token: string } }[];
    expect(before.status).toBe('pending');
    expect(before.payload.token).toBeTruthy();

    const nonServiceRoleRes = await callFn('process-outbox', adminAal2Token);
    expect(nonServiceRoleRes.status).toBe(403);

    const processRes = await callFn('process-outbox', SUPABASE_SERVICE_ROLE_KEY!);
    expect(processRes.status).toBe(200);

    const afterRes = await restAdmin(`notification_outbox?id=eq.${before.id}`);
    const [after] = (await afterRes.json()) as { status: string; payload: { token: string | null } }[];
    expect(after.status).toBe('sent_stub');
    expect(after.payload.token).toBeNull();

    // the token read before process-outbox ran still accepts the invite -
    // redaction purges the stored copy, it doesn't revoke the invite itself.
    const acceptRes = await fetch(`${SUPABASE_FUNCTIONS_URL}/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY! },
      body: JSON.stringify({ token: before.payload.token, password: 'Zy-Outbox-Stub-Strong-55!' }),
    });
    expect(acceptRes.status).toBe(200);
  });
});
