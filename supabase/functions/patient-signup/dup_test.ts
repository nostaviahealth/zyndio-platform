// PSU-DUP-01..05 — patient-signup duplicate / normalisation / concurrency.
// Unit assertions always run. Live Edge hits require SUPABASE_URL +
// SUPABASE_ANON_KEY + SUPABASE_SERVICE_ROLE_KEY (local stack).
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { normalizeEmail, isValidEmail } from '../_shared/validation.ts'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? Deno.env.get('API_URL') ?? ''
const ANON = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('ANON_KEY') ?? ''
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SERVICE_ROLE_KEY') ?? ''
const FN_URL = Deno.env.get('SUPABASE_FUNCTIONS_URL') ??
  (SUPABASE_URL ? `${SUPABASE_URL}/functions/v1` : '')
const LIVE = Boolean(SUPABASE_URL && ANON && SERVICE && FN_URL)
const PW = 'Correct-Horse-Battery-99!'

function suffix(): string {
  return `${Date.now().toString(36)}${Math.random().toString(36).slice(2, 8)}`
}

async function countUsersByEmail(email: string): Promise<number> {
  const res = await fetch(
    `${SUPABASE_URL}/rest/v1/rpc/find_user_id_by_email`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        apikey: SERVICE,
        Authorization: `Bearer ${SERVICE}`,
      },
      body: JSON.stringify({ p_email: email }),
    },
  )
  const body = await res.json()
  // find_user_id_by_email returns uuid | null
  return body ? 1 : 0
}

async function signup(email: string): Promise<Response> {
  return await fetch(`${FN_URL}/patient-signup`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: ANON,
      Authorization: `Bearer ${ANON}`,
    },
    body: JSON.stringify({ email, password: PW }),
  })
}

// ---------------------------------------------------------------------------
// Unit: normalisation (DUP-02, DUP-03) + plus policy (DUP-04)
// ---------------------------------------------------------------------------

Deno.test('PSU-DUP-02: normalizeEmail collapses case variants to one mailbox', () => {
  assertEquals(normalizeEmail('jordan.rivera@example.com'), 'jordan.rivera@example.com')
  assertEquals(normalizeEmail('Jordan.Rivera@example.com'), 'jordan.rivera@example.com')
  assertEquals(normalizeEmail('JORDAN.RIVERA@EXAMPLE.COM'), 'jordan.rivera@example.com')
})

Deno.test('PSU-DUP-03: normalizeEmail trims leading/trailing whitespace', () => {
  assertEquals(normalizeEmail('  jordan.rivera@example.com  '), 'jordan.rivera@example.com')
  assertEquals(normalizeEmail('\tjordan.rivera@example.com\n'), 'jordan.rivera@example.com')
})

Deno.test('PSU-DUP-04: plus-aliases stay distinct (policy b — TO-07 unique link)', () => {
  // Product allows distinct plus-aliases as separate accounts; the active-link
  // unique index (patient_record_links_one_active_th) is what stops two
  // aliases from both holding the same telehealth record (PSU-TO-07).
  const base = normalizeEmail('jordan.rivera@example.com')
  const plus = normalizeEmail('jordan.rivera+app@example.com')
  assertEquals(base, 'jordan.rivera@example.com')
  assertEquals(plus, 'jordan.rivera+app@example.com')
  assert(base !== plus)
  assert(isValidEmail(plus!))
})

// ---------------------------------------------------------------------------
// Live Edge: DUP-01 idempotent retry, DUP-02/03 via Edge, DUP-05 concurrent
// ---------------------------------------------------------------------------

Deno.test({
  name: 'PSU-DUP-01: repeated signup same email creates no second auth.users row',
  ignore: !LIVE,
  fn: async () => {
    const email = `dup01-${suffix()}@example.test`
    const r1 = await signup(email)
    assertEquals(r1.status, 200)
    const b1 = await r1.json()
    assertEquals(b1.status, 'ok')
    assertEquals(await countUsersByEmail(email), 1)

    const r2 = await signup(email)
    assertEquals(r2.status, 200)
    const b2 = await r2.json()
    assertEquals(b2.status, 'ok')
    assertEquals(await countUsersByEmail(email), 1)
  },
})

Deno.test({
  name: 'PSU-DUP-02 live: case-variant signup does not create a second account',
  ignore: !LIVE,
  fn: async () => {
    const base = `dup02-${suffix()}@example.test`
    assertEquals((await signup(base)).status, 200)
    assertEquals(await countUsersByEmail(base), 1)
    const upper = base.toUpperCase()
    assertEquals((await signup(upper)).status, 200)
    assertEquals(await countUsersByEmail(base), 1)
  },
})

Deno.test({
  name: 'PSU-DUP-03 live: whitespace-padded signup does not create a second account',
  ignore: !LIVE,
  fn: async () => {
    const base = `dup03-${suffix()}@example.test`
    assertEquals((await signup(base)).status, 200)
    assertEquals(await countUsersByEmail(base), 1)
    assertEquals((await signup(`  ${base}  `)).status, 200)
    assertEquals(await countUsersByEmail(base), 1)
  },
})

Deno.test({
  name: 'PSU-DUP-04 live: plus-alias is a distinct mailbox (link uniqueness is TO-07)',
  ignore: !LIVE,
  fn: async () => {
    const tag = suffix()
    const base = `dup04-${tag}@example.test`
    const plus = `dup04-${tag}+app@example.test`
    assertEquals((await signup(base)).status, 200)
    assertEquals((await signup(plus)).status, 200)
    assertEquals(await countUsersByEmail(base), 1)
    assertEquals(await countUsersByEmail(plus), 1)
  },
})

Deno.test({
  name: 'PSU-DUP-05: concurrent signup for same email leaves exactly one auth.users row',
  ignore: !LIVE,
  fn: async () => {
    const email = `dup05-${suffix()}@example.test`
    const [a, b] = await Promise.all([signup(email), signup(email)])
    assertEquals(a.status, 200)
    assertEquals(b.status, 200)
    const ba = await a.json()
    const bb = await b.json()
    assertEquals(ba.status, 'ok')
    assertEquals(bb.status, 'ok')
    assertEquals(await countUsersByEmail(email), 1)
  },
})
