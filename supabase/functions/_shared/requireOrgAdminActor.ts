import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { decodeJwtPayload, hasAal2Claim, parseBearerToken } from './validation.ts'

export class AuthError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

export interface OrgAdminActor {
  userId: string
  orgId: string
}

// Service role key only ever comes from the function runtime's own env - it
// is never shipped to, or accepted from, a client.
export function serviceRoleClient(): SupabaseClient {
  return createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}

function anonClient(): SupabaseClient {
  return createClient(Deno.env.get('SUPABASE_URL') ?? '', Deno.env.get('SUPABASE_ANON_KEY') ?? '', {
    auth: { autoRefreshToken: false, persistSession: false },
  })
}

// Verifies the caller's JWT against GoTrue itself (never trusts a
// client-asserted role/org), requires aal2, and requires an ACTIVE
// org_admin org_members row - all server side. Returns a service-role
// client for the function's own subsequent writes.
export async function requireOrgAdminActor(
  req: Request
): Promise<{ actor: OrgAdminActor; admin: SupabaseClient }> {
  const token = parseBearerToken(req.headers.get('Authorization'))
  if (!token) throw new AuthError('missing bearer token', 401)

  const { data: userData, error: userError } = await anonClient().auth.getUser(token)
  if (userError || !userData?.user) throw new AuthError('invalid session', 401)

  const payload = decodeJwtPayload(token)
  if (!hasAal2Claim(payload)) throw new AuthError('aal2 required', 403)

  const admin = serviceRoleClient()
  const { data: member, error: memberError } = await admin
    .from('org_members')
    .select('org_id, role, status')
    .eq('user_id', userData.user.id)
    .maybeSingle()

  if (memberError || !member || member.status !== 'active' || member.role !== 'org_admin') {
    throw new AuthError('org_admin required', 403)
  }

  return { actor: { userId: userData.user.id, orgId: member.org_id as string }, admin }
}

// Weaker variant for recovery-reenrol: any signed-in user, acting on
// themselves, aal1 is fine (that is precisely the state a just-consumed
// recovery code leaves them in).
export async function requireAuthenticatedActor(
  req: Request
): Promise<{ userId: string; admin: SupabaseClient }> {
  const token = parseBearerToken(req.headers.get('Authorization'))
  if (!token) throw new AuthError('missing bearer token', 401)

  const { data: userData, error: userError } = await anonClient().auth.getUser(token)
  if (userError || !userData?.user) throw new AuthError('invalid session', 401)

  return { userId: userData.user.id, admin: serviceRoleClient() }
}
