#!/usr/bin/env tsx
/**
 * Zyndio admin bootstrap (TC-005 step 3).
 *
 * One-time local/dev bootstrap for the FIRST org admin. There is no default
 * or env-seeded password beyond what the operator supplies: ADMIN_EMAIL and
 * ADMIN_PASSWORD must both be set, and ADMIN_PASSWORD is validated with the
 * same rules an invited user's own password-set goes through (>= 12 chars,
 * an uppercase and a lowercase letter, a number, a symbol, and not on the
 * server-side common-password blocklist - M8, Henry's 27 Oct ruling). No
 * MFA is pre-enrolled here - the
 * bootstrap admin goes through the normal 02-2fa-setup flow on first login,
 * exactly like any invited user. Idempotent: re-running against an admin
 * that already exists and is already an active org_admin is a no-op.
 *
 * Usage: npm run admin:setup
 * Env:   ADMIN_EMAIL, ADMIN_PASSWORD (required), ORG_NAME (optional),
 *        ZYNDIO_PLATFORM_ADMIN=true (optional)
 *
 * ZYNDIO_PLATFORM_ADMIN=true additionally seeds this email into
 * public.platform_admins - the platform-level ("Zyndio admin") role that
 * reset-mfa requires (org_admin alone is not enough; an org admin can only
 * *request* a reset via request_mfa_reset()). There is no in-app action
 * that grants this and no default seed - it is this script, and only this
 * script, on purpose.
 */

import * as dotenv from 'dotenv'
import { createClient } from '@supabase/supabase-js'
import { isPasswordLongEnough, MIN_PASSWORD_LENGTH } from '../supabase/functions/_shared/validation'

dotenv.config()

const ADMIN_EMAIL = process.env.ADMIN_EMAIL
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD
const ORG_NAME = process.env.ORG_NAME?.trim() || 'Zyndio'
const ZYNDIO_PLATFORM_ADMIN = process.env.ZYNDIO_PLATFORM_ADMIN === 'true'

const SUPABASE_URL = process.env.VITE_SUPABASE_URL
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_KEY

// Uses the find_user_id_by_email() SQL function (see
// supabase/migrations/20261026140200_tc005_find_user_by_email.sql), not
// GoTrue's admin listUsers endpoint - listUsers() 500s ("Database error
// finding users") the moment any account in the instance has a NULL
// confirmation_token, which a plain admin.createUser() call already leaves
// behind. A SQL lookup against auth.users sidesteps that entirely.
async function findUserIdByEmail(admin: ReturnType<typeof createClient>, email: string): Promise<string | null> {
  const { data, error } = await admin.rpc('find_user_id_by_email', { p_email: email })
  if (error) throw error
  return (data as string | null) ?? null
}

async function main() {
  if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
    console.error('Missing required environment variables: ADMIN_EMAIL and ADMIN_PASSWORD must both be set.')
    process.exit(1)
  }
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
    console.error('Missing required environment variables: VITE_SUPABASE_URL and SUPABASE_SERVICE_KEY must both be set.')
    process.exit(1)
  }

  const email = ADMIN_EMAIL.trim().toLowerCase()

  if (!isPasswordLongEnough(ADMIN_PASSWORD)) {
    console.error(`ADMIN_PASSWORD is too short - it must be at least ${MIN_PASSWORD_LENGTH} characters.`)
    process.exit(1)
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const { data: blocked, error: blockedError } = await admin.rpc('password_is_blocked', {
    p_password: ADMIN_PASSWORD,
  })
  if (blockedError) {
    console.error('Could not check ADMIN_PASSWORD against the blocklist:', blockedError.message)
    process.exit(1)
  }
  if (blocked) {
    console.error('ADMIN_PASSWORD is too common (on the server-side blocklist) and is refused. Choose a different one.')
    process.exit(1)
  }

  console.log('Zyndio admin bootstrap\n')

  let userId = await findUserIdByEmail(admin, email)
  if (userId) {
    console.log(`Auth user for ${email} already exists (${userId}).`)
  } else {
    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email,
      password: ADMIN_PASSWORD,
      email_confirm: true,
    })
    if (createError || !created?.user) {
      console.error('Failed to create admin auth user:', createError?.message)
      process.exit(1)
    }
    userId = created.user.id
    console.log(`Created auth user for ${email} (${userId}).`)
  }

  const { data: existingMember, error: memberLookupError } = await admin
    .from('org_members')
    .select('org_id, role, status')
    .eq('user_id', userId)
    .maybeSingle()
  if (memberLookupError) {
    console.error('Failed to look up org_members row:', memberLookupError.message)
    process.exit(1)
  }

  if (existingMember) {
    console.log(
      `${email} is already a member of org ${existingMember.org_id} as ${existingMember.role} (${existingMember.status}). Nothing to do.`
    )
    await seedPlatformAdminIfRequested(admin, userId, email)
    console.log('\nSetup complete (no change). Sign in and, if prompted, complete authenticator setup.')
    return
  }

  const { data: existingOrgs, error: orgLookupError } = await admin
    .from('organizations')
    .select('id, name')
    .order('created_at', { ascending: true })
    .limit(1)
  if (orgLookupError) {
    console.error('Failed to look up organizations:', orgLookupError.message)
    process.exit(1)
  }

  let orgId: string
  if (existingOrgs && existingOrgs.length > 0) {
    orgId = existingOrgs[0].id
    console.log(`Using existing organization "${existingOrgs[0].name}" (${orgId}).`)
  } else {
    const { data: createdOrg, error: orgError } = await admin
      .from('organizations')
      .insert({ name: ORG_NAME })
      .select('id')
      .single()
    if (orgError || !createdOrg) {
      console.error('Failed to create organization:', orgError?.message)
      process.exit(1)
    }
    orgId = createdOrg.id
    console.log(`Created organization "${ORG_NAME}" (${orgId}).`)
  }

  const { error: insertMemberError } = await admin.from('org_members').insert({
    user_id: userId,
    org_id: orgId,
    role: 'org_admin',
    status: 'active',
  })
  if (insertMemberError) {
    console.error('Failed to create org_members row:', insertMemberError.message)
    process.exit(1)
  }

  await seedPlatformAdminIfRequested(admin, userId, email)

  console.log(`\nSetup complete. ${email} is an active org_admin of "${ORG_NAME}".`)
  console.log('No two-factor authenticator is pre-enrolled - sign in and complete the authenticator')
  console.log('setup flow (scan -> verify -> recovery codes) like any invited user would.')
}

async function seedPlatformAdminIfRequested(
  admin: ReturnType<typeof createClient>,
  userId: string,
  email: string
): Promise<void> {
  if (!ZYNDIO_PLATFORM_ADMIN) return
  const { error } = await admin.from('platform_admins').upsert({ user_id: userId })
  if (error) {
    console.error('Failed to seed platform_admins row:', error.message)
    process.exit(1)
  }
  console.log(`${email} is now a Zyndio (platform) admin - can perform reset-mfa on any org's staff.`)
}

main().catch((err) => {
  console.error(err)
  process.exit(1)
})
