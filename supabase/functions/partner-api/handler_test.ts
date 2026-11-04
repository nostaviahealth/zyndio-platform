// Unit tests for the /v1 partner API HTTP layer: OAuth, scopes, idempotency,
// error shape, validation, pagination and the "no internal uuid" rule. The
// partner_* RPCs are replaced by a small in-memory fake; their real SQL is
// covered by supabase/tests/760_int01_partner_api.sql. Fictional data only.
import { assert, assertEquals, assertFalse, assertMatch } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { createPartnerApiHandler, PartnerApiDeps, RpcResult } from './handler.ts'
import { sha256Hex } from '../_shared/webhookSignature.ts'

const SANDBOX_SECRET = 'zys_0000000000000000000000000000000000000000000000000000000000000001'
const INTERNAL_UUID_PREFIX = '00000000-0000-4000-8000-'

interface FakePatient {
  zpid: string
  userId: string
  email: string
  given_name: string | null
  family_name: string | null
  phone: string | null
  activated: boolean
  deactivated: boolean
  enrolledAt: string
  invites: number
}

class Fake {
  calls: { fn: string; args: Record<string, unknown> }[] = []
  clients = new Map([
    ['zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', { id: 'client-1', scopes: ['patients:read', 'patients:write', 'webhooks:manage'] }],
    ['zyc_test_readonlyreadonlyreadonly', { id: 'client-2', scopes: ['patients:read'] }],
  ])
  secretHashes = new Map<string, string>()
  tokens = new Map<string, { api_client_id: string; client_id: string; environment: string; scopes: string[] }>()
  idem = new Map<string, { hash: string; status?: number; body?: unknown }>()
  patients = new Map<string, FakePatient>()
  endpoints: { id: string; url: string; created: string; disabled: boolean; secret: string }[] = []
  authUsers = new Map<string, string>()
  deletedUsers: string[] = []
  banned: string[] = []
  emailUpdates: string[] = []
  takenEmails = new Set(['taken@example.test'])
  failNext: string | null = null
  enrolError: string | null = null
  inviteError: string | null = null
  seq = 0

  async init() {
    this.secretHashes.set('zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', await sha256Hex(SANDBOX_SECRET))
    this.secretHashes.set('zyc_test_readonlyreadonlyreadonly', await sha256Hex(SANDBOX_SECRET))
    return this
  }

  patientJson(p: FakePatient) {
    return {
      object: 'patient',
      zyndio_patient_id: p.zpid,
      environment: 'sandbox',
      status: p.deactivated ? 'deactivated' : p.activated ? 'active' : 'invited',
      email: p.email,
      given_name: p.given_name,
      family_name: p.family_name,
      phone: p.phone,
      enrolled_at: p.enrolledAt,
      consents: [],
      connected_sources: [],
    }
  }

  rpc(fn: string, args: Record<string, unknown>): Promise<RpcResult> {
    this.calls.push({ fn, args })
    if (this.failNext === fn) {
      this.failNext = null
      return Promise.resolve({ data: null, error: { code: 'XX000', message: 'boom' } })
    }
    const ok = (data: unknown) => Promise.resolve({ data, error: null })
    switch (fn) {
      case 'partner_issue_token': {
        const client = this.clients.get(args.p_client_id as string)
        if (!client || this.secretHashes.get(args.p_client_id as string) !== args.p_secret_hash) {
          return ok({ error: 'invalid_client' })
        }
        const requested = args.p_requested_scopes as string[] | null
        if (requested && !requested.every((s) => client.scopes.includes(s))) return ok({ error: 'invalid_scope' })
        const scopes = (requested ?? client.scopes).slice().sort()
        this.tokens.set(args.p_token_hash as string, {
          api_client_id: client.id,
          client_id: args.p_client_id as string,
          environment: 'sandbox',
          scopes,
        })
        return ok({ scopes, expires_in: 900, environment: 'sandbox' })
      }
      case 'partner_authenticate':
        return ok(this.tokens.get(args.p_token_hash as string) ?? null)
      case 'partner_idempotency_begin': {
        const k = `${args.p_api_client_id}|${args.p_key}`
        const hash = `${args.p_method}|${args.p_path}|${args.p_request_hash}`
        const row = this.idem.get(k)
        if (!row) {
          this.idem.set(k, { hash })
          return ok({ state: 'new' })
        }
        if (row.hash !== hash) return ok({ state: 'mismatch' })
        if (row.status === undefined) return ok({ state: 'in_progress' })
        return ok({ state: 'replay', response_status: row.status, response_body: row.body })
      }
      case 'partner_idempotency_complete': {
        const row = this.idem.get(`${args.p_api_client_id}|${args.p_key}`)!
        row.status = args.p_response_status as number
        row.body = JSON.parse(JSON.stringify(args.p_response_body))
        return ok(null)
      }
      case 'partner_idempotency_abandon':
        this.idem.delete(`${args.p_api_client_id}|${args.p_key}`)
        return ok(null)
      case 'partner_resolve_patient': {
        const p = this.patients.get(args.p_zyndio_patient_id as string)
        return ok(p ? { user_id: p.userId, activated: p.activated, deactivated: p.deactivated } : null)
      }
      case 'partner_get_patient': {
        const p = this.patients.get(args.p_zyndio_patient_id as string)
        return ok(p ? this.patientJson(p) : null)
      }
      case 'partner_enrol_patient': {
        if (this.enrolError) return ok({ error: this.enrolError })
        const p: FakePatient = {
          zpid: args.p_zyndio_patient_id as string,
          userId: args.p_user_id as string,
          email: this.authUsers.get(args.p_user_id as string)!,
          given_name: args.p_given_name as string | null,
          family_name: args.p_family_name as string | null,
          phone: args.p_phone as string | null,
          activated: false,
          deactivated: false,
          enrolledAt: `2026-11-04 10:00:0${this.patients.size}.123456+00`,
          invites: 1,
        }
        this.patients.set(p.zpid, p)
        return ok(this.patientJson(p))
      }
      case 'partner_list_patients': {
        const all = [...this.patients.values()].sort((a, b) =>
          a.enrolledAt === b.enrolledAt ? a.zpid.localeCompare(b.zpid) : a.enrolledAt.localeCompare(b.enrolledAt)
        )
        const after = args.p_after_sort as string | null
        const rows = all
          .filter((p) => !after || p.enrolledAt > after || (p.enrolledAt === after && p.zpid > (args.p_after_id as string)))
          .slice(0, args.p_limit as number)
        return ok(rows.map((p) => ({ ...this.patientJson(p), _sort: p.enrolledAt })))
      }
      case 'partner_send_invite': {
        if (this.inviteError) return ok({ error: this.inviteError })
        const p = this.patients.get(args.p_zyndio_patient_id as string)
        if (!p) return ok({ error: 'not_found' })
        p.invites++
        return ok({ object: 'invite', zyndio_patient_id: p.zpid, sent_at: '2026-11-04T10:00:00.000Z', expires_at: '2026-11-11T10:00:00.000Z' })
      }
      case 'partner_update_patient': {
        const p = this.patients.get(args.p_zyndio_patient_id as string)
        if (!p) return ok({ error: 'not_found' })
        const patch = args.p_patch as Record<string, unknown>
        if ('given_name' in patch) p.given_name = patch.given_name as string | null
        if ('family_name' in patch) p.family_name = patch.family_name as string | null
        if ('phone' in patch) p.phone = patch.phone as string | null
        if (patch.status === 'deactivated') p.deactivated = true
        return ok(this.patientJson(p))
      }
      case 'partner_patient_summary': {
        const p = this.patients.get(args.p_zyndio_patient_id as string)
        if (!p) return ok({ error: 'not_found' })
        return ok({ object: 'patient_summary', zyndio_patient_id: p.zpid, biomarkers: [], wearables: { sources: [], daily: [] }, open_flags: [] })
      }
      case 'partner_create_webhook_endpoint': {
        const url = args.p_url as string
        if (!url.startsWith('https://')) return ok({ error: 'https_required' })
        if (this.endpoints.length >= 10) return ok({ error: 'endpoint_limit_reached' })
        const id = `whe_${String(++this.seq).padStart(24, '0')}`
        const ep = { id, url, created: `2026-11-04 10:00:00.00000${this.seq}+00`, disabled: false, secret: `whsec_${'0'.repeat(47)}${this.seq}` }
        this.endpoints.push(ep)
        return ok({ object: 'webhook_endpoint', id, url, status: 'enabled', secret: ep.secret })
      }
      case 'partner_list_webhook_endpoints': {
        const after = args.p_after_sort as string | null
        const rows = this.endpoints
          .filter((e) => !e.disabled && (!after || e.created > after))
          .slice(0, args.p_limit as number)
        return ok(rows.map((e) => ({ object: 'webhook_endpoint', id: e.id, url: e.url, status: 'enabled', _sort: e.created })))
      }
      case 'partner_delete_webhook_endpoint': {
        const ep = this.endpoints.find((e) => e.id === args.p_endpoint_public_id && !e.disabled)
        if (!ep) return ok({ error: 'not_found' })
        ep.disabled = true
        return ok({ object: 'webhook_endpoint', id: ep.id, status: 'disabled' })
      }
      case 'partner_rotate_webhook_secret': {
        const ep = this.endpoints.find((e) => e.id === args.p_endpoint_public_id && !e.disabled)
        if (!ep) return ok({ error: 'not_found' })
        ep.secret = `whsec_${'1'.repeat(48)}`
        return ok({ object: 'webhook_endpoint', id: ep.id, secret: ep.secret })
      }
      default:
        throw new Error(`unexpected rpc ${fn}`)
    }
  }

  deps(): PartnerApiDeps {
    let n = 0
    return {
      rpc: (fn, args) => this.rpc(fn, args),
      createAuthUser: (email) => {
        if (this.takenEmails.has(email)) return Promise.resolve({ error: 'email_unavailable' as const })
        const userId = `${INTERNAL_UUID_PREFIX}${String(this.authUsers.size + 1).padStart(12, '0')}`
        this.authUsers.set(userId, email)
        return Promise.resolve({ userId })
      },
      deleteAuthUser: (userId) => {
        this.deletedUsers.push(userId)
        return Promise.resolve()
      },
      updateAuthEmail: (userId, email) => {
        if (this.takenEmails.has(email)) return Promise.resolve('email_unavailable' as const)
        this.emailUpdates.push(`${userId}:${email}`)
        return Promise.resolve('ok' as const)
      },
      banAuthUser: (userId) => {
        this.banned.push(userId)
        return Promise.resolve(true)
      },
      randomToken: () => (++n).toString(16).padStart(64, 'a'),
      requestId: () => `req_${String(++n).padStart(24, '0')}`,
      log: () => {},
    }
  }
}

const BASE = 'https://platform.example.test/v1'

async function setup() {
  const fake = await new Fake().init()
  const handle = createPartnerApiHandler(fake.deps())
  return { fake, handle }
}

function basic(id: string, secret: string) {
  return `Basic ${btoa(`${id}:${secret}`)}`
}

async function tokenFor(handle: (r: Request) => Promise<Response>, clientId = 'zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', scope?: string) {
  const res = await handle(
    new Request(`${BASE}/oauth/token`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded', authorization: basic(clientId, SANDBOX_SECRET) },
      body: `grant_type=client_credentials${scope ? `&scope=${encodeURIComponent(scope)}` : ''}`,
    })
  )
  const body = await res.json()
  return body.access_token as string
}

function call(
  method: string,
  path: string,
  token: string | null,
  opts: { body?: unknown; key?: string | null; contentType?: string } = {}
) {
  const headers: Record<string, string> = {}
  if (token) headers.authorization = `Bearer ${token}`
  if (opts.body !== undefined) headers['content-type'] = opts.contentType ?? 'application/json'
  if (opts.key !== null && method === 'POST') headers['idempotency-key'] = opts.key ?? crypto.randomUUID()
  return new Request(`${BASE}${path}`, {
    method,
    headers,
    body: opts.body === undefined ? undefined : typeof opts.body === 'string' ? opts.body : JSON.stringify(opts.body),
  })
}

async function assertError(res: Response, status: number, code: string) {
  assertEquals(res.status, status)
  const body = await res.json()
  assertEquals(Object.keys(body), ['error'])
  assertEquals(Object.keys(body.error).sort(), ['code', 'message', 'request_id'])
  assertEquals(body.error.code, code)
  assertEquals(body.error.request_id, res.headers.get('x-request-id'))
  assertMatch(body.error.request_id, /^req_/)
}

const NEW_PATIENT = { zyndio_patient_id: 'zp-fictional-001', email: 'Fictional.One@Example.test', given_name: 'Fictional', phone: '+15555550101' }

// ---------------------------------------------------------------------------
// OAuth
// ---------------------------------------------------------------------------

Deno.test('token: client credentials via Basic auth -> 15-minute bearer token with scopes', async () => {
  const { handle } = await setup()
  const res = await handle(
    new Request(`${BASE}/oauth/token`, {
      method: 'POST',
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
        authorization: basic('zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', SANDBOX_SECRET),
      },
      body: 'grant_type=client_credentials&scope=patients%3Aread',
    })
  )
  assertEquals(res.status, 200)
  assertEquals(res.headers.get('cache-control'), 'no-store')
  const body = await res.json()
  assertMatch(body.access_token, /^zyat_[0-9a-f]{64}$/)
  assertEquals(body.token_type, 'Bearer')
  assertEquals(body.expires_in, 900)
  assertEquals(body.scope, 'patients:read')
})

Deno.test('token: credentials in a JSON body work too; the stored value is a hash, never the token', async () => {
  const { handle, fake } = await setup()
  const res = await handle(
    new Request(`${BASE}/oauth/token`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ grant_type: 'client_credentials', client_id: 'zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', client_secret: SANDBOX_SECRET }),
    })
  )
  const body = await res.json()
  assertEquals(body.scope, 'patients:read patients:write webhooks:manage')
  const issued = fake.calls.find((c) => c.fn === 'partner_issue_token')!
  assertEquals(issued.args.p_token_hash, await sha256Hex(body.access_token))
  assertFalse(JSON.stringify(issued.args).includes(body.access_token))
  assertFalse(JSON.stringify(issued.args).includes(SANDBOX_SECRET))
})

Deno.test('token: wrong secret, bad grant type, unknown scope, missing credentials', async () => {
  const { handle } = await setup()
  const post = (body: string, auth?: string) =>
    handle(
      new Request(`${BASE}/oauth/token`, {
        method: 'POST',
        headers: { 'content-type': 'application/x-www-form-urlencoded', ...(auth ? { authorization: auth } : {}) },
        body,
      })
    )
  await assertError(await post('grant_type=client_credentials', basic('zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', 'nope')), 401, 'invalid_client')
  await assertError(await post('grant_type=password', basic('zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', SANDBOX_SECRET)), 400, 'unsupported_grant_type')
  await assertError(
    await post('grant_type=client_credentials&scope=admin', basic('zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', SANDBOX_SECRET)),
    400,
    'invalid_scope'
  )
  await assertError(
    await post('grant_type=client_credentials&scope=patients:write', basic('zyc_test_readonlyreadonlyreadonly', SANDBOX_SECRET)),
    400,
    'invalid_scope'
  )
  await assertError(await post('grant_type=client_credentials'), 401, 'invalid_client')
  const get = await handle(new Request(`${BASE}/oauth/token`))
  await assertError(get, 405, 'method_not_allowed')
})

// ---------------------------------------------------------------------------
// Auth, scopes, routing
// ---------------------------------------------------------------------------

Deno.test('a missing or unknown bearer token is 401 with WWW-Authenticate', async () => {
  const { handle } = await setup()
  const res = await handle(call('GET', '/patients/zp-1', null))
  assertEquals(res.headers.get('www-authenticate'), 'Bearer')
  await assertError(res, 401, 'unauthorized')
  await assertError(await handle(call('GET', '/patients/zp-1', `zyat_${'0'.repeat(64)}`)), 401, 'unauthorized')
})

Deno.test('scopes are enforced per route', async () => {
  const { handle } = await setup()
  const readOnly = await tokenFor(handle, 'zyc_test_readonlyreadonlyreadonly')
  await assertError(await handle(call('POST', '/patients', readOnly, { body: NEW_PATIENT })), 403, 'insufficient_scope')
  await assertError(await handle(call('GET', '/webhook-endpoints', readOnly)), 403, 'insufficient_scope')
  await assertError(await handle(call('GET', '/patients/zp-unknown', readOnly)), 404, 'not_found')
})

Deno.test('unknown paths are 404, wrong methods 405 with Allow; the /functions/v1/partner-api prefix routes too', async () => {
  const { handle } = await setup()
  const token = await tokenFor(handle)
  await assertError(await handle(call('GET', '/nope', token)), 404, 'not_found')
  const res = await handle(call('DELETE', '/patients', token))
  assertEquals(res.headers.get('allow'), 'GET, POST')
  await assertError(res, 405, 'method_not_allowed')
  const prefixed = await handle(
    new Request('https://ref.example.test/functions/v1/partner-api/v1/patients', { headers: { authorization: `Bearer ${token}` } })
  )
  assertEquals(prefixed.status, 200)
  // a zyndio_patient_id of "v1" is just an id, not a second prefix
  await assertError(await handle(call('GET', '/patients/v1', token)), 404, 'not_found')
  await assertError(await handle(new Request('https://platform.example.test/v2/patients')), 404, 'not_found')
})

// ---------------------------------------------------------------------------
// INT-01 patients
// ---------------------------------------------------------------------------

Deno.test('POST /patients enrols, sends the invite, and never returns the internal uuid', async () => {
  const { handle, fake } = await setup()
  const token = await tokenFor(handle)
  const res = await handle(call('POST', '/patients', token, { body: NEW_PATIENT, key: 'enrol-1' }))
  assertEquals(res.status, 201)
  const text = await res.text()
  assertFalse(text.includes(INTERNAL_UUID_PREFIX))
  const body = JSON.parse(text)
  assertEquals(body.zyndio_patient_id, 'zp-fictional-001')
  assertEquals(body.email, 'fictional.one@example.test')
  assertEquals(body.status, 'invited')

  const enrol = fake.calls.find((c) => c.fn === 'partner_enrol_patient')!
  assertEquals(enrol.args.p_invite_token_hash, await sha256Hex(enrol.args.p_invite_token as string))
  assertEquals(enrol.args.p_phone, '+15555550101')
})

Deno.test('Idempotency-Key: required on POST, replay returns the original, different body is 422', async () => {
  const { handle, fake } = await setup()
  const token = await tokenFor(handle)
  await assertError(await handle(call('POST', '/patients', token, { body: NEW_PATIENT, key: null })), 400, 'idempotency_key_required')
  await assertError(await handle(call('POST', '/patients', token, { body: NEW_PATIENT, key: 'bad key with spaces' })), 400, 'invalid_request')

  const first = await handle(call('POST', '/patients', token, { body: NEW_PATIENT, key: 'enrol-1' }))
  const firstBody = await first.json()
  const replay = await handle(call('POST', '/patients', token, { body: NEW_PATIENT, key: 'enrol-1' }))
  assertEquals(replay.status, 201)
  assertEquals(replay.headers.get('idempotent-replayed'), 'true')
  assertEquals(await replay.json(), firstBody)
  assertEquals(fake.authUsers.size, 1, 'the replay did not create a second account')

  await assertError(
    await handle(call('POST', '/patients', token, { body: { ...NEW_PATIENT, given_name: 'Other' }, key: 'enrol-1' })),
    422,
    'idempotency_key_reused'
  )
})

Deno.test('4xx results are replayed too; 5xx results are not stored so a retry can succeed', async () => {
  const { handle, fake } = await setup()
  const token = await tokenFor(handle)
  fake.takenEmails.add('fictional.one@example.test')
  await assertError(await handle(call('POST', '/patients', token, { body: NEW_PATIENT, key: 'k-409' })), 409, 'email_unavailable')
  const again = await handle(call('POST', '/patients', token, { body: NEW_PATIENT, key: 'k-409' }))
  assertEquals(again.headers.get('idempotent-replayed'), 'true')
  assertEquals(again.status, 409)
  // the original body, including the original request_id
  assertEquals((await again.json()).error.code, 'email_unavailable')

  fake.takenEmails.clear()
  fake.failNext = 'partner_enrol_patient'
  await assertError(await handle(call('POST', '/patients', token, { body: NEW_PATIENT, key: 'k-500' })), 500, 'internal_error')
  assert(fake.calls.some((c) => c.fn === 'partner_idempotency_abandon'))
  assertEquals(fake.deletedUsers.length, 1, 'the orphan auth account was cleaned up')
  const retry = await handle(call('POST', '/patients', token, { body: NEW_PATIENT, key: 'k-500' }))
  assertEquals(retry.status, 201)
})

Deno.test('duplicate zyndio_patient_id is 409 before any account is created', async () => {
  const { handle, fake } = await setup()
  const token = await tokenFor(handle)
  await handle(call('POST', '/patients', token, { body: NEW_PATIENT }))
  await assertError(
    await handle(call('POST', '/patients', token, { body: { ...NEW_PATIENT, email: 'someone.else@example.test' } })),
    409,
    'patient_already_exists'
  )
  assertEquals(fake.authUsers.size, 1)
})

Deno.test('enrol RPC refusal removes the freshly minted account', async () => {
  const { handle, fake } = await setup()
  const token = await tokenFor(handle)
  fake.enrolError = 'email_unavailable'
  await assertError(await handle(call('POST', '/patients', token, { body: NEW_PATIENT })), 409, 'email_unavailable')
  assertEquals(fake.deletedUsers.length, 1)
})

Deno.test('input validation: ids, unknown fields, phone, JSON, content type, size', async () => {
  const { handle } = await setup()
  const token = await tokenFor(handle)
  const bad = async (body: unknown, code: string, status = 400, contentType?: string) =>
    await assertError(await handle(call('POST', '/patients', token, { body, contentType })), status, code)
  await bad({ ...NEW_PATIENT, zyndio_patient_id: 'has spaces' }, 'invalid_request')
  await bad({ ...NEW_PATIENT, zyndio_patient_id: 'x'.repeat(129) }, 'invalid_request')
  await bad({ ...NEW_PATIENT, ssn: '000-00-0000' }, 'invalid_request')
  await bad({ ...NEW_PATIENT, phone: '555-0101' }, 'invalid_request')
  await bad({ ...NEW_PATIENT, email: 'not-an-email' }, 'invalid_request')
  await bad('{not json', 'invalid_request')
  await bad('[]', 'invalid_request')
  await bad(NEW_PATIENT, 'unsupported_media_type', 415, 'text/plain')
  await bad({ ...NEW_PATIENT, given_name: 'x'.repeat(20000) }, 'payload_too_large', 413)
})

Deno.test('GET /patients/{id} returns the patient; unknown is 404', async () => {
  const { handle } = await setup()
  const token = await tokenFor(handle)
  await handle(call('POST', '/patients', token, { body: NEW_PATIENT }))
  const res = await handle(call('GET', '/patients/zp-fictional-001', token))
  assertEquals(res.status, 200)
  assertEquals((await res.json()).status, 'invited')
  await assertError(await handle(call('GET', '/patients/zp-other', token)), 404, 'not_found')
})

Deno.test('GET /patients paginates with an opaque cursor', async () => {
  const { handle } = await setup()
  const token = await tokenFor(handle)
  for (const n of [1, 2, 3]) {
    await handle(call('POST', '/patients', token, { body: { zyndio_patient_id: `zp-${n}`, email: `p${n}@example.test` } }))
  }
  const first = await (await handle(call('GET', '/patients?limit=2', token))).json()
  assertEquals(first.object, 'list')
  assertEquals(first.data.map((p: { zyndio_patient_id: string }) => p.zyndio_patient_id), ['zp-1', 'zp-2'])
  assertEquals(first.has_more, true)
  assertFalse('_sort' in first.data[0])
  const second = await (await handle(call('GET', `/patients?limit=2&cursor=${first.next_cursor}`, token))).json()
  assertEquals(second.data.map((p: { zyndio_patient_id: string }) => p.zyndio_patient_id), ['zp-3'])
  assertEquals(second.has_more, false)
  assertEquals(second.next_cursor, null)
  await assertError(await handle(call('GET', '/patients?cursor=garbage!', token)), 400, 'invalid_request')
  await assertError(await handle(call('GET', '/patients?limit=0', token)), 400, 'invalid_request')
  await assertError(await handle(call('GET', '/patients?limit=101', token)), 400, 'invalid_request')
})

Deno.test('PATCH updates contact details; deactivation bans the account', async () => {
  const { handle, fake } = await setup()
  const token = await tokenFor(handle)
  await handle(call('POST', '/patients', token, { body: NEW_PATIENT }))
  const res = await handle(call('PATCH', '/patients/zp-fictional-001', token, { body: { family_name: 'Example', phone: null } }))
  assertEquals(res.status, 200)
  const body = await res.json()
  assertEquals(body.family_name, 'Example')
  assertEquals(body.phone, null)

  const off = await handle(call('PATCH', '/patients/zp-fictional-001', token, { body: { status: 'deactivated' } }))
  assertEquals((await off.json()).status, 'deactivated')
  assertEquals(fake.banned.length, 1)

  await assertError(await handle(call('PATCH', '/patients/zp-fictional-001', token, { body: { status: 'active' } })), 400, 'invalid_request')
  await assertError(await handle(call('PATCH', '/patients/zp-fictional-001', token, { body: {} })), 400, 'invalid_request')
  await assertError(await handle(call('PATCH', '/patients/zp-none', token, { body: { phone: null } })), 404, 'not_found')
})

Deno.test('PATCH email: allowed before first sign-in (with a fresh invite), refused after', async () => {
  const { handle, fake } = await setup()
  const token = await tokenFor(handle)
  await handle(call('POST', '/patients', token, { body: NEW_PATIENT }))
  const res = await handle(call('PATCH', '/patients/zp-fictional-001', token, { body: { email: 'new.address@example.test' } }))
  assertEquals(res.status, 200)
  assertEquals(fake.emailUpdates.length, 1)
  const reinvite = fake.calls.filter((c) => c.fn === 'partner_send_invite')
  assertEquals(reinvite.length, 1)
  assertEquals(reinvite[0].args.p_bypass_throttle, true)

  fake.patients.get('zp-fictional-001')!.activated = true
  await assertError(
    await handle(call('PATCH', '/patients/zp-fictional-001', token, { body: { email: 'third@example.test' } })),
    409,
    'email_change_not_allowed'
  )
})

Deno.test('POST /patients/{id}/invites resends; RPC refusals map to stable codes', async () => {
  const { handle, fake } = await setup()
  const token = await tokenFor(handle)
  await handle(call('POST', '/patients', token, { body: NEW_PATIENT }))
  const res = await handle(call('POST', '/patients/zp-fictional-001/invites', token))
  assertEquals(res.status, 202)
  assertEquals((await res.json()).object, 'invite')
  for (const [rpcCode, status, code] of [
    ['rate_limited', 429, 'rate_limited'],
    ['patient_already_active', 409, 'patient_already_active'],
    ['patient_deactivated', 409, 'patient_deactivated'],
  ] as const) {
    fake.inviteError = rpcCode
    await assertError(await handle(call('POST', '/patients/zp-fictional-001/invites', token)), status, code)
  }
})

Deno.test('GET /patients/{id}/summary (INT-03)', async () => {
  const { handle } = await setup()
  const token = await tokenFor(handle)
  await handle(call('POST', '/patients', token, { body: NEW_PATIENT }))
  const res = await handle(call('GET', '/patients/zp-fictional-001/summary', token))
  assertEquals(res.status, 200)
  const body = await res.json()
  assertEquals(body.object, 'patient_summary')
  assertEquals(body.wearables, { sources: [], daily: [] })
  await assertError(await handle(call('GET', '/patients/zp-none/summary', token)), 404, 'not_found')
})

// ---------------------------------------------------------------------------
// INT-02 webhook endpoints
// ---------------------------------------------------------------------------

Deno.test('webhook endpoints: create shows the secret once, list never does, rotate, delete', async () => {
  const { handle } = await setup()
  const token = await tokenFor(handle)
  const created = await handle(call('POST', '/webhook-endpoints', token, { body: { url: 'https://hooks.example.test/in' } }))
  assertEquals(created.status, 201)
  const ep = await created.json()
  assertMatch(ep.secret, /^whsec_/)

  const list = await (await handle(call('GET', '/webhook-endpoints', token))).json()
  assertEquals(list.data.length, 1)
  assertFalse('secret' in list.data[0])

  const rotated = await handle(call('POST', `/webhook-endpoints/${ep.id}/rotate-secret`, token))
  assertEquals(rotated.status, 200)
  assert((await rotated.json()).secret !== ep.secret)

  const deleted = await handle(call('DELETE', `/webhook-endpoints/${ep.id}`, token))
  assertEquals((await deleted.json()).status, 'disabled')
  await assertError(await handle(call('DELETE', `/webhook-endpoints/${ep.id}`, token)), 404, 'not_found')
  await assertError(await handle(call('DELETE', '/webhook-endpoints/not-an-id', token)), 404, 'not_found')
})

Deno.test('webhook endpoints: URL and event type validation', async () => {
  const { handle } = await setup()
  const token = await tokenFor(handle)
  await assertError(
    await handle(call('POST', '/webhook-endpoints', token, { body: { url: 'http://hooks.example.test/in' } })),
    400,
    'invalid_webhook_url'
  )
  await assertError(
    await handle(call('POST', '/webhook-endpoints', token, { body: { url: 'https://hooks.example.test/in', event_types: ['patient.exploded'] } })),
    400,
    'invalid_request'
  )
  await assertError(await handle(call('POST', '/webhook-endpoints', token, { body: {} })), 400, 'invalid_request')
})
