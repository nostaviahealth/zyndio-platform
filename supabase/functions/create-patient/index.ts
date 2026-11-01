// TC-018 (Henry add-on, Create Patient, moved from TC-024 item 1): the admin
// Create Patient page used to insert into the removed `profiles` table -
// "Failed to create patient" for every allowed role (PR #22 review, L2).
// Points Create Patient at the real patient model instead, with no shadow
// table: mint the auth.users row (same auth.admin.createUser pattern as
// invite-user), then call public.create_patient_record() under the
// CALLER's own JWT (not the service-role admin client) so org_id,
// auth.uid() and the resulting patient_created audit row all resolve to
// the real physician/care_coordinator actor, not service_role. The RPC
// re-checks aal2 + physician/care_coordinator + org isolation server side
// regardless of what this function believes; requireClinicalStaffActor
// gates first only to avoid minting an orphan auth user for a caller who
// was never going to be allowed to use it.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeadersFor, jsonResponse } from '../_shared/cors.ts'
import { AuthError, requireClinicalStaffActor } from '../_shared/requireOrgAdminActor.ts'
import { generatePlaceholderPassword, isValidEmail, normalizeEmail, normalizeFullName } from '../_shared/validation.ts'

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeadersFor(req) })

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const { admin } = await requireClinicalStaffActor(req)

    const body = await req.json().catch(() => ({}))
    const email = normalizeEmail(body.email)
    const displayName = normalizeFullName(body.display_name ?? body.displayName)
    const mrn = typeof body.mrn === 'string' && body.mrn.trim().length > 0 ? body.mrn.trim() : null

    if (!displayName) {
      return jsonResponse(req, { error: 'invalid_request', field: 'display_name' }, 400)
    }
    if (!email || !isValidEmail(email)) {
      return jsonResponse(req, { error: 'invalid_request', field: 'email' }, 400)
    }

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password: generatePlaceholderPassword(),
      email_confirm: true,
    })
    if (createError || !created?.user) {
      // An internal, authenticated staff tool - unlike invite-user, there's
      // no public-facing account-enumeration concern here worth hiding
      // behind a generic response.
      return jsonResponse(req, { error: 'email_already_exists' }, 409)
    }

    // RPC call under the CALLER's own JWT, not the service-role admin
    // client - create_patient_record()'s auth.uid()/current_org_id()/
    // current_role() must resolve to the real actor for the audit row and
    // org scoping to be correct.
    const caller = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )
    const { error: rpcError } = await caller.rpc('create_patient_record', {
      p_user_id: created.user.id,
      p_display_name: displayName,
      p_mrn: mrn,
    })

    if (rpcError) {
      // Don't leave an orphan auth user behind for a patient record that
      // was never created.
      await admin.auth.admin.deleteUser(created.user.id).catch((cleanupErr: unknown) => {
        console.error('create-patient: cleanup of orphaned auth user failed', cleanupErr)
      })
      if (rpcError.code === '42501') return jsonResponse(req, { error: 'not_authorized' }, 403)
      console.error('create-patient: create_patient_record failed', rpcError)
      return jsonResponse(req, { error: 'internal_error' }, 500)
    }

    return jsonResponse(req, { status: 'ok', patient_id: created.user.id })
  } catch (err) {
    if (err instanceof AuthError) return jsonResponse(req, { error: err.message }, err.status)
    console.error('create-patient error', err)
    return jsonResponse(req, { error: 'internal_error' }, 500)
  }
})
