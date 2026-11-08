// APP-01: what the patient app's sign-in screen may offer. Public (no
// session) and patient-agnostic: today only whether open self-sign-up is on
// for this deployment's org, so the app shows "Create an account" only
// when patient-signup would actually accept it. Server-side enforcement is
// in patient-signup itself; this is just the UI hint.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { serviceRoleClient } from '../_shared/requireOrgAdminActor.ts'
import { isSelfSignupOpen } from '../_shared/selfSignup.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const selfSignupEnabled = await isSelfSignupOpen(serviceRoleClient(), Deno.env)
    return jsonResponse(req, { status: 'ok', self_signup_enabled: selfSignupEnabled })
  } catch (err) {
    console.error('patient-auth-config error', err instanceof Error ? err.message : 'unknown')
    return jsonResponse(req, { status: 'ok', self_signup_enabled: false })
  }
})
