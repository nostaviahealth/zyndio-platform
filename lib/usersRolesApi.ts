import { supabase } from './supabase';

export type AppRole = 'org_admin' | 'physician' | 'care_coordinator' | 'read_only';
export type MemberStatus = 'invited' | 'active' | 'deactivated';

export interface OrgMember {
  user_id: string;
  email: string;
  full_name: string | null;
  role: AppRole;
  status: MemberStatus;
  created_at: string;
  updated_at: string;
}

export interface ApiResult {
  ok: boolean;
  error?: string;
}

// list_org_members()/change_member_role() are plain RPCs (org_admin + aal2
// re-checked server side); invite/deactivate/reactivate/request-reset go
// through the step-3/step-8 Edge Functions and RPC the same way the rest of
// the admin app calls them (see contexts/PortalAuthContext.tsx).
export async function listOrgMembers(): Promise<OrgMember[]> {
  const { data, error } = await supabase.rpc('list_org_members');
  if (error) throw error;
  return (data ?? []) as OrgMember[];
}

export async function inviteUser(
  email: string,
  role: AppRole,
  fullName: string
): Promise<ApiResult> {
  const { data, error } = await supabase.functions.invoke('invite-user', {
    body: { email, role, full_name: fullName },
  });
  if (error) return { ok: false, error: 'internal_error' };
  if (data?.error) return { ok: false, error: data.error as string };
  return { ok: true };
}

export async function cancelInvite(targetUserId: string): Promise<ApiResult & { email?: string }> {
  const { data, error } = await supabase.functions.invoke('cancel-invite', {
    body: { target_user_id: targetUserId },
  });
  if (error) return { ok: false, error: 'internal_error' };
  if (data?.error) return { ok: false, error: data.error as string };
  return { ok: true, email: (data?.email as string | undefined) ?? undefined };
}

export async function changeMemberRole(targetUserId: string, newRole: AppRole): Promise<ApiResult> {
  const { error } = await supabase.rpc('change_member_role', {
    p_target_user_id: targetUserId,
    p_new_role: newRole,
  });
  if (error) return { ok: false, error: error.message };
  return { ok: true };
}

export async function deactivateUser(targetUserId: string): Promise<ApiResult> {
  const { data, error } = await supabase.functions.invoke('deactivate-user', {
    body: { target_user_id: targetUserId },
  });
  if (error) return { ok: false, error: 'internal_error' };
  if (data?.error) return { ok: false, error: data.error as string };
  return { ok: true };
}

export async function reactivateUser(targetUserId: string): Promise<ApiResult> {
  const { data, error } = await supabase.functions.invoke('reactivate-user', {
    body: { target_user_id: targetUserId },
  });
  if (error) return { ok: false, error: 'internal_error' };
  if (data?.error) return { ok: false, error: data.error as string };
  return { ok: true };
}

// Requesting a 2FA reset (not performing one - Henry's round-2 ruling: only
// a Zyndio admin can actually reset someone's 2FA; an org admin can only
// ask). The RPC itself refuses a self-target with a Postgres 42501, which
// surfaces here as `error.code`.
export async function requestMfaReset(targetUserId: string, reason?: string): Promise<ApiResult> {
  const { error } = await supabase.rpc('request_mfa_reset', {
    p_target_user_id: targetUserId,
    p_reason: reason?.trim() || null,
  });
  if (error) return { ok: false, error: error.code === '42501' ? 'forbidden' : error.message };
  return { ok: true };
}

// Performing an actual 2FA reset - Zyndio (platform) admin only, enforced
// server-side by requireZyndioAdminActor (supabase/functions/reset-mfa).
export async function resetMfa(targetUserId: string): Promise<ApiResult> {
  const { data, error } = await supabase.functions.invoke('reset-mfa', {
    body: { target_user_id: targetUserId },
  });
  if (error) return { ok: false, error: 'internal_error' };
  if (data?.error) return { ok: false, error: data.error as string };
  return { ok: true };
}

// Platform ("Zyndio") admin vs org admin - drives which 2FA-reset dialog an
// actor sees (reset-2fa vs request-2fa-reset). is_zyndio_admin() has no
// explicit grant/revoke (Postgres default: EXECUTE to PUBLIC), so it's
// callable by any authenticated session; it only ever reports the caller's
// own membership in platform_admins.
export async function checkIsPlatformAdmin(): Promise<boolean> {
  const { data, error } = await supabase.rpc('is_zyndio_admin');
  if (error) return false;
  return data === true;
}
