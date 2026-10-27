// B2 (M3): the only sanctioned self-service password-set path. The client
// must call this function instead of supabase.auth.updateUser({ password })
// directly - that call never runs the blocklist check (config.toml has no
// password_requirements and local GoTrue's leaked-password/HIBP check isn't
// relied on, OVERRIDES #13). Any signed-in user, acting on themselves only -
// aal1 is fine, same as recovery-reenrol.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireAuthenticatedActor } from '../_shared/requireOrgAdminActor.ts'
import { writeAuditLog } from '../_shared/auditAndNotify.ts'
import { isPasswordLongEnough } from '../_shared/validation.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const { userId, admin } = await requireAuthenticatedActor(req)

    const body = await req.json().catch(() => ({}))
    const password = body.password

    if (!isPasswordLongEnough(password)) {
      return jsonResponse(req, { error: 'password_too_short' }, 400)
    }

    const { data: blocked, error: blockedError } = await admin.rpc('password_is_blocked', {
      p_password: password,
    })
    if (blockedError) {
      console.error('change-password: password_is_blocked check failed', blockedError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }
    if (blocked) {
      return jsonResponse(req, { error: 'password_too_common' }, 400)
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(userId, { password })
    if (updateError) {
      console.error('change-password: updateUserById failed', updateError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    const { data: member } = await admin.from('org_members').select('org_id').eq('user_id', userId).maybeSingle()

    await writeAuditLog(admin, {
      eventType: 'password_changed',
      actorUserId: userId,
      targetUserId: userId,
      orgId: member?.org_id ?? null,
    })

    return jsonResponse(req, { status: 'ok' })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse(req, { error: err.message }, err.status)
    console.error('change-password error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
