// INT-01 / INT-02 / INT-03 partner API entrypoint. The routing, auth and
// conventions live in handler.ts; this file only wires the service-role
// Supabase client and GoTrue admin calls into it.
//
// Deploy with gateway JWT verification OFF for this function only
// (supabase/config.toml [functions.partner-api] verify_jwt = false): partners
// authenticate with the API's own OAuth bearer tokens, which handler.ts
// verifies against api_access_tokens on every request.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { generatePlaceholderPassword, generateToken } from '../_shared/validation.ts'
import { createPartnerApiHandler, PartnerApiDeps } from './handler.ts'

// GoTrue answers an already-registered email with 422 / email_exists.
function isEmailTaken(error: unknown): boolean {
  const e = error as { status?: number; code?: string } | null
  return e?.code === 'email_exists' || e?.status === 422
}

export function liveDeps(): PartnerApiDeps {
  const admin = serviceRoleClient()
  return {
    rpc: (fn, args) => admin.rpc(fn, args),
    async createAuthUser(email) {
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password: generatePlaceholderPassword(),
        email_confirm: true,
      })
      if (error || !data?.user) {
        if (isEmailTaken(error)) return { error: 'email_unavailable' }
        console.error('partner-api: auth.admin.createUser failed', error)
        return { error: 'internal' }
      }
      return { userId: data.user.id }
    },
    async deleteAuthUser(userId) {
      const { error } = await admin.auth.admin.deleteUser(userId)
      if (error) throw error
    },
    async updateAuthEmail(userId, email) {
      const { error } = await admin.auth.admin.updateUserById(userId, { email, email_confirm: true })
      if (!error) return 'ok'
      if (isEmailTaken(error)) return 'email_unavailable'
      console.error('partner-api: auth.admin.updateUserById(email) failed', error)
      return 'internal'
    },
    async banAuthUser(userId) {
      // ~100 years: GoTrue refuses sign-in and token refresh while banned.
      const { error } = await admin.auth.admin.updateUserById(userId, { ban_duration: '876000h' })
      if (error) console.error('partner-api: ban after deactivation failed', error)
      return !error
    },
    randomToken: generateToken,
    requestId: () => `req_${generateToken().slice(0, 24)}`,
    log: (message, detail) => console.error(message, detail ?? ''),
  }
}

if (import.meta.main) {
  const handle = createPartnerApiHandler(liveDeps())
  serve(handle)
}
