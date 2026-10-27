// TC-014: invite requires full name + role; grant rules; cancel invalidates
// token; accepted account gets exactly the invited role; cross-clinic refuse.
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import {
  callFn,
  createOrgAndMember,
  deleteUser,
  enrollAndVerifyTotp,
  restAdmin,
  signIn,
} from './helpers';

const SUPABASE_FUNCTIONS_URL = process.env.SUPABASE_FUNCTIONS_URL!;
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY!;

describe('TC-014 invite name / role / cancel', () => {
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
    for (const id of cleanupUserIds) {
      await deleteUser(id).catch(() => undefined);
    }
  });

  it('refuses missing full_name and missing role', async () => {
    const noName = await callFn('invite-user', adminAal2Token, {
      email: `tc014-noname-${Date.now()}@example.test`,
      role: 'physician',
    });
    expect(noName.status).toBe(400);

    const noRole = await callFn('invite-user', adminAal2Token, {
      email: `tc014-norole-${Date.now()}@example.test`,
      full_name: 'No Role',
    });
    expect(noRole.status).toBe(400);
  });

  it('accepted account gets exactly the invited role; audit includes role', async () => {
    const email = `tc014-role-${Date.now()}@example.test`;
    const inviteRes = await callFn('invite-user', adminAal2Token, {
      email,
      role: 'care_coordinator',
      full_name: 'Casey Coordinator',
    });
    expect(inviteRes.status).toBe(200);

    const notifRes = await restAdmin(
      `notification_outbox?type=eq.invite&payload->>email=eq.${encodeURIComponent(email)}&order=created_at.desc&limit=1`
    );
    const [notif] = (await notifRes.json()) as { payload: { token: string } }[];
    expect(notif?.payload?.token).toBeTruthy();

    const goodPassword = 'Zy-Tc014-Accept-Role-99!';
    const acceptRes = await fetch(`${SUPABASE_FUNCTIONS_URL}/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY },
      body: JSON.stringify({ token: notif.payload.token, password: goodPassword }),
    });
    expect(acceptRes.status).toBe(200);

    const session = await signIn(email, goodPassword);
    const sub = JSON.parse(
      Buffer.from(session.access_token!.split('.')[1], 'base64').toString('utf8')
    ).sub as string;
    cleanupUserIds.push(sub);

    const memberRes = await restAdmin(`org_members?user_id=eq.${sub}&select=role,status`);
    const [member] = (await memberRes.json()) as { role: string; status: string }[];
    expect(member.role).toBe('care_coordinator');
    expect(member.status).toBe('active');

    const auditRes = await restAdmin(
      `audit_log?event_type=eq.invite_accepted&target_user_id=eq.${sub}&order=created_at.desc&limit=1`
    );
    const [audit] = (await auditRes.json()) as { metadata: { role?: string } }[];
    expect(audit?.metadata?.role).toBe('care_coordinator');
  });

  it('cancel-invite revokes the token and removes the row; re-accept fails', async () => {
    const email = `tc014-cancel-${Date.now()}@example.test`;
    const inviteRes = await callFn('invite-user', adminAal2Token, {
      email,
      role: 'physician',
      full_name: 'Casey Cancel',
    });
    expect(inviteRes.status).toBe(200);

    const notifRes = await restAdmin(
      `notification_outbox?type=eq.invite&payload->>email=eq.${encodeURIComponent(email)}&order=created_at.desc&limit=1`
    );
    const [notif] = (await notifRes.json()) as { payload: { token: string } }[];
    const memberRes = await restAdmin(
      `org_members?select=user_id&status=eq.invited&user_id=neq.${admin.userId}`
    );
    // Find by email via invites
    const inviteRowRes = await restAdmin(
      `invites?email=eq.${encodeURIComponent(email)}&order=created_at.desc&limit=1&select=user_id,revoked_at`
    );
    const [inviteRow] = (await inviteRowRes.json()) as { user_id: string; revoked_at: string | null }[];
    expect(inviteRow.user_id).toBeTruthy();
    const targetUserId = inviteRow.user_id;

    const cancelRes = await callFn('cancel-invite', adminAal2Token, {
      target_user_id: targetUserId,
    });
    expect(cancelRes.status).toBe(200);

    const afterInvite = await restAdmin(
      `invites?user_id=eq.${targetUserId}&order=created_at.desc&limit=1&select=revoked_at`
    );
    const [revoked] = (await afterInvite.json()) as { revoked_at: string | null }[];
    expect(revoked.revoked_at).not.toBeNull();

    const afterMember = await restAdmin(`org_members?user_id=eq.${targetUserId}`);
    expect(((await afterMember.json()) as unknown[]).length).toBe(0);

    const acceptRes = await fetch(`${SUPABASE_FUNCTIONS_URL}/accept-invite`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: SUPABASE_ANON_KEY },
      body: JSON.stringify({ token: notif.payload.token, password: 'Zy-Tc014-Cancel-Fail-99!' }),
    });
    expect(acceptRes.status).toBe(400);

    const auditRes = await restAdmin(
      `audit_log?event_type=eq.invite_cancelled&target_user_id=eq.${targetUserId}`
    );
    expect(((await auditRes.json()) as unknown[]).length).toBe(1);
  });

  it('cancel-invite from another clinic is refused', async () => {
    const email = `tc014-xorg-${Date.now()}@example.test`;
    await callFn('invite-user', adminAal2Token, {
      email,
      role: 'physician',
      full_name: 'Other Clinic',
    });
    const inviteRowRes = await restAdmin(
      `invites?email=eq.${encodeURIComponent(email)}&order=created_at.desc&limit=1&select=user_id`
    );
    const [inviteRow] = (await inviteRowRes.json()) as { user_id: string }[];
    cleanupUserIds.push(inviteRow.user_id);

    const otherAdmin = await createOrgAndMember('org_admin');
    cleanupUserIds.push(otherAdmin.userId);
    const otherAal1 = await signIn(otherAdmin.email, otherAdmin.password);
    const { aal2Token: otherAal2 } = await enrollAndVerifyTotp(otherAal1.access_token!);

    const cancelRes = await callFn('cancel-invite', otherAal2!, {
      target_user_id: inviteRow.user_id,
    });
    expect(cancelRes.status).toBe(404);

    // Original invite still live
    const still = await restAdmin(
      `invites?user_id=eq.${inviteRow.user_id}&revoked_at=is.null&accepted_at=is.null`
    );
    expect(((await still.json()) as unknown[]).length).toBe(1);
  });
});
