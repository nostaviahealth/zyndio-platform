// INT-01 / INT-02 / INT-03: the /v1 partner API for the zyndio.com backend.
// Server-to-server only (no CORS). Meant to sit behind a Zyndio hostname
// (platform.zyndio.com/v1/...) that proxies to this function; the direct
// Supabase path /functions/v1/partner-api/v1/... routes the same way.
//
// Conventions (docs/PARTNER_API.md):
//   * OAuth 2.0 client credentials -> 15-minute opaque bearer token, scoped.
//   * JSON, snake_case, ISO 8601 UTC timestamps, cursor pagination.
//   * Every POST (except /v1/oauth/token) needs Idempotency-Key; a replay
//     within 7 days returns the original status and body.
//   * One error shape: {"error":{"code","message","request_id"}}.
//   * Only zyndio_patient_id ever identifies a patient; internal uuids stay
//     server side (partner_resolve_patient feeds them to GoTrue calls only).
//
// All database work goes through the service-role partner_* RPCs
// (20261104150100), which re-scope every call to the API client's org and
// environment. Dependencies are injected so handler_test.ts can run it
// without a live stack.
import { ApiError, ErrorCode, errorBody } from './errors.ts'
import {
  EVENT_TYPES,
  SCOPES,
  Scope,
  decodeCursor,
  encodeCursor,
  isIdempotencyKey,
  isScope,
  isWebhookEndpointId,
  optionalName,
  optionalPhone,
  parseLimit,
  rejectUnknownFields,
  requireEmail,
  requireZyndioPatientId,
} from './validation.ts'
import { sha256Hex } from '../_shared/webhookSignature.ts'

const CACHED_SECRET_KEYS = ['secret', 'client_secret', 'previous_secret', 'invite_token', 'token'] as const

/** Drop one-time credentials before an idempotency replay is stored. */
export function redactCachedSecrets(body: unknown): unknown {
  if (!body || typeof body !== 'object' || Array.isArray(body)) return body
  const out: Record<string, unknown> = { ...(body as Record<string, unknown>) }
  for (const key of CACHED_SECRET_KEYS) delete out[key]
  return out
}

export interface RpcResult {
  data: unknown
  error: { code?: string; message: string } | null
}

export interface PartnerApiDeps {
  rpc(fn: string, args: Record<string, unknown>): PromiseLike<RpcResult>
  // GoTrue admin calls (service role). Same createUser pattern as create-patient.
  createAuthUser(email: string): Promise<{ userId: string } | { error: 'email_unavailable' | 'internal' }>
  deleteAuthUser(userId: string): Promise<void>
  updateAuthEmail(userId: string, email: string): Promise<'ok' | 'email_unavailable' | 'internal'>
  banAuthUser(userId: string): Promise<boolean>
  // 64 hex chars of CSPRNG output.
  randomToken(): string
  requestId(): string
  log(message: string, detail?: unknown): void
}

interface Principal {
  apiClientId: string
  clientId: string
  environment: 'sandbox' | 'production'
  scopes: Scope[]
}

interface Result {
  status: number
  body: unknown
  headers?: Record<string, string>
}

const MAX_BODY_BYTES = 16 * 1024
const TOKEN_TTL_SECONDS = 900

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

function respond(result: Result, requestId: string): Response {
  return new Response(result.status === 204 ? null : JSON.stringify(result.body), {
    status: result.status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store',
      'X-Request-Id': requestId,
      ...(result.headers ?? {}),
    },
  })
}

function errorResult(err: ApiError, requestId: string): Result {
  return { status: err.status, body: errorBody(err.code, err.message, requestId), headers: err.headers }
}

async function readBody(req: Request): Promise<string> {
  const declared = Number(req.headers.get('content-length') ?? '0')
  if (Number.isFinite(declared) && declared > MAX_BODY_BYTES) {
    throw new ApiError('payload_too_large', `Request body must be at most ${MAX_BODY_BYTES} bytes.`)
  }
  const text = await req.text()
  if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) {
    throw new ApiError('payload_too_large', `Request body must be at most ${MAX_BODY_BYTES} bytes.`)
  }
  return text
}

function parseJsonBody(raw: string, contentType: string | null): Record<string, unknown> {
  if (raw.trim() === '') return {}
  if (!contentType || !contentType.toLowerCase().startsWith('application/json')) {
    throw new ApiError('unsupported_media_type', 'Content-Type must be application/json.')
  }
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch {
    throw new ApiError('invalid_request', 'Request body is not valid JSON.')
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new ApiError('invalid_request', 'Request body must be a JSON object.')
  }
  return parsed as Record<string, unknown>
}

function parseBearer(header: string | null): string | null {
  const match = /^Bearer\s+([A-Za-z0-9_\-.]{20,200})$/.exec(header ?? '')
  return match ? match[1] : null
}

// ---------------------------------------------------------------------------
// Routing
// ---------------------------------------------------------------------------

type Handler = (ctx: Ctx) => Promise<Result>

interface RouteMethod {
  scope: Scope
  handler: Handler
}

interface Route {
  pattern: string[] // ':id' marks the path parameter
  methods: Partial<Record<string, RouteMethod>>
}

interface Ctx {
  req: Request
  url: URL
  params: { id?: string }
  principal: Principal
  body: Record<string, unknown>
  requestId: string
}

function matchRoute(routes: Route[], segments: string[]): { route: Route; params: { id?: string } } | null {
  for (const route of routes) {
    if (route.pattern.length !== segments.length) continue
    const params: { id?: string } = {}
    let ok = true
    for (let i = 0; i < segments.length; i++) {
      if (route.pattern[i] === ':id') params.id = segments[i]
      else if (route.pattern[i] !== segments[i]) {
        ok = false
        break
      }
    }
    if (ok) return { route, params }
  }
  return null
}

export function createPartnerApiHandler(deps: PartnerApiDeps): (req: Request) => Promise<Response> {
  async function rpc<T>(fn: string, args: Record<string, unknown>): Promise<T> {
    const { data, error } = await deps.rpc(fn, args)
    if (error) {
      deps.log(`partner-api: ${fn} failed`, error)
      throw new ApiError('internal_error', 'An internal error occurred.')
    }
    return data as T
  }

  // Business errors from the partner_* RPCs come back as {"error": "<code>"}.
  function throwIfRpcError(data: unknown, messages: Partial<Record<string, [ErrorCode, string]>>): void {
    const code = (data as { error?: string } | null)?.error
    if (!code) return
    const mapped = messages[code]
    if (mapped) throw new ApiError(mapped[0], mapped[1])
    deps.log('partner-api: unmapped rpc error code', code)
    throw new ApiError('internal_error', 'An internal error occurred.')
  }

  const notFoundPatient: [ErrorCode, string] = ['not_found', 'No patient with this zyndio_patient_id.']
  const notFoundEndpoint: [ErrorCode, string] = ['not_found', 'No webhook endpoint with this id.']

  function patientId(ctx: Ctx): string {
    return requireZyndioPatientId(ctx.params.id, 'Path zyndio_patient_id')
  }

  function endpointId(ctx: Ctx): string {
    if (!isWebhookEndpointId(ctx.params.id)) throw new ApiError('not_found', 'No webhook endpoint with this id.')
    return ctx.params.id as string
  }

  async function newInvite(): Promise<{ token: string; hash: string }> {
    const token = deps.randomToken()
    return { token, hash: await sha256Hex(token) }
  }

  async function page(
    ctx: Ctx,
    fn: string,
    idField: string
  ): Promise<Result> {
    const limit = parseLimit(ctx.url.searchParams.get('limit'))
    const cursor = decodeCursor(ctx.url.searchParams.get('cursor'))
    const rows = await rpc<Record<string, unknown>[]>(fn, {
      p_api_client_id: ctx.principal.apiClientId,
      p_after_sort: cursor?.sort ?? null,
      p_after_id: cursor?.id ?? null,
      p_limit: limit + 1,
    })
    const items = (rows ?? []).slice(0, limit)
    const hasMore = (rows ?? []).length > limit
    const last = items[items.length - 1]
    return {
      status: 200,
      body: {
        object: 'list',
        data: items.map(({ _sort, ...rest }) => rest),
        has_more: hasMore,
        next_cursor: hasMore && last ? encodeCursor(String(last._sort), String(last[idField])) : null,
      },
    }
  }

  // --- patients ------------------------------------------------------------

  async function listPatients(ctx: Ctx): Promise<Result> {
    return page(ctx, 'partner_list_patients', 'zyndio_patient_id')
  }

  async function createPatient(ctx: Ctx): Promise<Result> {
    rejectUnknownFields(ctx.body, ['zyndio_patient_id', 'email', 'given_name', 'family_name', 'phone'])
    const zyndioPatientId = requireZyndioPatientId(ctx.body.zyndio_patient_id)
    const email = requireEmail(ctx.body.email)
    const givenName = optionalName(ctx.body.given_name, 'given_name') ?? null
    const familyName = optionalName(ctx.body.family_name, 'family_name') ?? null
    const phone = optionalPhone(ctx.body.phone) ?? null

    const existing = await rpc<unknown>('partner_resolve_patient', {
      p_api_client_id: ctx.principal.apiClientId,
      p_zyndio_patient_id: zyndioPatientId,
    })
    if (existing) throw new ApiError('patient_already_exists', 'A patient with this zyndio_patient_id is already enrolled.')

    const created = await deps.createAuthUser(email)
    if ('error' in created) {
      // Same shape for "this email already has an account" and any other
      // create failure. A distinct 409 let a sandbox client probe whether
      // an address exists on the platform, including in another environment.
      throw new ApiError('internal_error', 'An internal error occurred.')
    }

    const invite = await newInvite()
    let data: unknown
    try {
      data = await rpc<unknown>('partner_enrol_patient', {
        p_api_client_id: ctx.principal.apiClientId,
        p_user_id: created.userId,
        p_zyndio_patient_id: zyndioPatientId,
        p_given_name: givenName,
        p_family_name: familyName,
        p_phone: phone,
        p_invite_token: invite.token,
        p_invite_token_hash: invite.hash,
      })
      throwIfRpcError(data, {
        patient_already_exists: ['patient_already_exists', 'A patient with this zyndio_patient_id is already enrolled.'],
        // Account-existence refusals use the same external error as a failed create.
        email_unavailable: ['internal_error', 'An internal error occurred.'],
        invalid_request: ['invalid_request', 'One or more fields are invalid.'],
      })
    } catch (err) {
      // Never leave an orphan auth account behind (same rule as create-patient).
      await deps.deleteAuthUser(created.userId).catch((cleanupErr) =>
        deps.log('partner-api: cleanup of orphaned auth user failed', cleanupErr)
      )
      throw err
    }
    return { status: 201, body: data }
  }

  async function getPatient(ctx: Ctx): Promise<Result> {
    const data = await rpc<unknown>('partner_get_patient', {
      p_api_client_id: ctx.principal.apiClientId,
      p_zyndio_patient_id: patientId(ctx),
    })
    if (!data) throw new ApiError(...notFoundPatient)
    return { status: 200, body: data }
  }

  async function updatePatient(ctx: Ctx): Promise<Result> {
    const zyndioPatientId = patientId(ctx)
    rejectUnknownFields(ctx.body, ['email', 'given_name', 'family_name', 'phone', 'status'])
    if (Object.keys(ctx.body).length === 0) {
      throw new ApiError('invalid_request', 'Provide at least one of email, given_name, family_name, phone, status.')
    }
    const email = ctx.body.email === undefined ? undefined : requireEmail(ctx.body.email)
    const patch: Record<string, unknown> = {}
    const givenName = optionalName(ctx.body.given_name, 'given_name')
    const familyName = optionalName(ctx.body.family_name, 'family_name')
    const phone = optionalPhone(ctx.body.phone)
    if (givenName !== undefined) patch.given_name = givenName
    if (familyName !== undefined) patch.family_name = familyName
    if (phone !== undefined) patch.phone = phone
    if (ctx.body.status !== undefined) {
      if (ctx.body.status !== 'deactivated') {
        throw new ApiError('invalid_request', 'status can only be set to "deactivated".')
      }
      patch.status = 'deactivated'
    }

    const resolved = await rpc<{ user_id: string; activated: boolean; deactivated: boolean } | null>(
      'partner_resolve_patient',
      { p_api_client_id: ctx.principal.apiClientId, p_zyndio_patient_id: zyndioPatientId }
    )
    if (!resolved) throw new ApiError(...notFoundPatient)

    if (email !== undefined) {
      if (resolved.deactivated) throw new ApiError('patient_deactivated', 'The patient is deactivated.')
      if (resolved.activated) {
        throw new ApiError(
          'email_change_not_allowed',
          'The patient has signed in; only the patient can change their sign-in email.'
        )
      }
      const outcome = await deps.updateAuthEmail(resolved.user_id, email)
      if (outcome !== 'ok') {
        throw new ApiError('internal_error', 'An internal error occurred.')
      }
      patch.email = true // recorded in the audit field list; the value lives in auth.users
      // The previous invite link went to the old address: send a fresh one.
      const invite = await newInvite()
      const sent = await rpc<unknown>('partner_send_invite', {
        p_api_client_id: ctx.principal.apiClientId,
        p_zyndio_patient_id: zyndioPatientId,
        p_invite_token: invite.token,
        p_invite_token_hash: invite.hash,
        p_bypass_throttle: true,
      })
      if ((sent as { error?: string } | null)?.error) deps.log('partner-api: re-invite after email change skipped', sent)
    }

    if (patch.status === 'deactivated' && !(await deps.banAuthUser(resolved.user_id))) {
      // Ban first. If GoTrue refuses, the patient stays active in the
      // database and can still sign in — the two sides stay together.
      // A retry bans again (idempotent) and then deactivates.
      throw new ApiError('internal_error', 'An internal error occurred.')
    }

    const data = await rpc<unknown>('partner_update_patient', {
      p_api_client_id: ctx.principal.apiClientId,
      p_zyndio_patient_id: zyndioPatientId,
      p_patch: patch,
    })
    throwIfRpcError(data, {
      not_found: notFoundPatient,
      invalid_request: ['invalid_request', 'One or more fields are invalid.'],
    })
    return { status: 200, body: data }
  }

  async function sendInvite(ctx: Ctx): Promise<Result> {
    rejectUnknownFields(ctx.body, [])
    const invite = await newInvite()
    const data = await rpc<unknown>('partner_send_invite', {
      p_api_client_id: ctx.principal.apiClientId,
      p_zyndio_patient_id: patientId(ctx),
      p_invite_token: invite.token,
      p_invite_token_hash: invite.hash,
      p_bypass_throttle: false,
    })
    throwIfRpcError(data, {
      not_found: notFoundPatient,
      patient_deactivated: ['patient_deactivated', 'The patient is deactivated.'],
      patient_already_active: ['patient_already_active', 'The patient has already signed in.'],
      rate_limited: ['rate_limited', 'An invite was sent less than a minute ago.'],
    })
    return { status: 202, body: data }
  }

  async function patientSummary(ctx: Ctx): Promise<Result> {
    const data = await rpc<unknown>('partner_patient_summary', {
      p_api_client_id: ctx.principal.apiClientId,
      p_zyndio_patient_id: patientId(ctx),
    })
    throwIfRpcError(data, { not_found: notFoundPatient })
    return { status: 200, body: data }
  }

  // --- webhook endpoints ---------------------------------------------------

  async function listEndpoints(ctx: Ctx): Promise<Result> {
    return page(ctx, 'partner_list_webhook_endpoints', 'id')
  }

  async function createEndpoint(ctx: Ctx): Promise<Result> {
    rejectUnknownFields(ctx.body, ['url', 'description', 'event_types'])
    const { url, description, event_types: eventTypes } = ctx.body
    if (typeof url !== 'string' || url.length === 0 || url.length > 2048) {
      throw new ApiError('invalid_request', 'url must be an https URL of at most 2048 characters.')
    }
    if (description !== undefined && description !== null && (typeof description !== 'string' || description.length > 200)) {
      throw new ApiError('invalid_request', 'description must be a string of at most 200 characters.')
    }
    if (
      eventTypes !== undefined &&
      (!Array.isArray(eventTypes) ||
        eventTypes.length === 0 ||
        !eventTypes.every((t) => typeof t === 'string' && (EVENT_TYPES as readonly string[]).includes(t)))
    ) {
      throw new ApiError('invalid_request', `event_types must be a non-empty subset of: ${EVENT_TYPES.join(', ')}.`)
    }
    const data = await rpc<unknown>('partner_create_webhook_endpoint', {
      p_api_client_id: ctx.principal.apiClientId,
      p_url: url,
      p_description: description ?? null,
      p_event_types: eventTypes ?? null,
    })
    throwIfRpcError(data, {
      invalid_url: ['invalid_webhook_url', 'url is not a valid absolute URL (no credentials, no whitespace).'],
      https_required: ['invalid_webhook_url', 'url must use https.'],
      url_not_allowed: ['invalid_webhook_url', 'url must point at a public hostname (no IP addresses, localhost or internal names).'],
      invalid_event_types: ['invalid_request', `event_types must be a non-empty subset of: ${EVENT_TYPES.join(', ')}.`],
      invalid_request: ['invalid_request', 'One or more fields are invalid.'],
      endpoint_limit_reached: ['limit_reached', 'At most 10 webhook endpoints per environment.'],
    })
    return { status: 201, body: data }
  }

  async function deleteEndpoint(ctx: Ctx): Promise<Result> {
    const data = await rpc<unknown>('partner_delete_webhook_endpoint', {
      p_api_client_id: ctx.principal.apiClientId,
      p_endpoint_public_id: endpointId(ctx),
    })
    throwIfRpcError(data, { not_found: notFoundEndpoint })
    return { status: 200, body: data }
  }

  async function rotateEndpointSecret(ctx: Ctx): Promise<Result> {
    rejectUnknownFields(ctx.body, [])
    const data = await rpc<unknown>('partner_rotate_webhook_secret', {
      p_api_client_id: ctx.principal.apiClientId,
      p_endpoint_public_id: endpointId(ctx),
    })
    throwIfRpcError(data, { not_found: notFoundEndpoint })
    return { status: 200, body: data }
  }

  const routes: Route[] = [
    {
      pattern: ['patients'],
      methods: {
        GET: { scope: 'patients:read', handler: listPatients },
        POST: { scope: 'patients:write', handler: createPatient },
      },
    },
    {
      pattern: ['patients', ':id'],
      methods: {
        GET: { scope: 'patients:read', handler: getPatient },
        PATCH: { scope: 'patients:write', handler: updatePatient },
      },
    },
    { pattern: ['patients', ':id', 'invites'], methods: { POST: { scope: 'patients:write', handler: sendInvite } } },
    { pattern: ['patients', ':id', 'summary'], methods: { GET: { scope: 'patients:read', handler: patientSummary } } },
    {
      pattern: ['webhook-endpoints'],
      methods: {
        GET: { scope: 'webhooks:manage', handler: listEndpoints },
        POST: { scope: 'webhooks:manage', handler: createEndpoint },
      },
    },
    { pattern: ['webhook-endpoints', ':id'], methods: { DELETE: { scope: 'webhooks:manage', handler: deleteEndpoint } } },
    {
      pattern: ['webhook-endpoints', ':id', 'rotate-secret'],
      methods: { POST: { scope: 'webhooks:manage', handler: rotateEndpointSecret } },
    },
  ]

  // --- OAuth 2.0 client credentials ----------------------------------------

  function clientCredentials(req: Request, params: URLSearchParams): { clientId: string; secret: string } {
    const header = req.headers.get('Authorization')
    const bodyId = params.get('client_id')
    const bodySecret = params.get('client_secret')
    if (header?.startsWith('Basic ')) {
      if (bodyId || bodySecret) {
        throw new ApiError('invalid_request', 'Send client credentials either in Authorization: Basic or in the body, not both.')
      }
      try {
        const decoded = atob(header.slice(6).trim())
        const sep = decoded.indexOf(':')
        if (sep < 1) throw new Error('no separator')
        return {
          clientId: decodeURIComponent(decoded.slice(0, sep)),
          secret: decodeURIComponent(decoded.slice(sep + 1)),
        }
      } catch {
        throw new ApiError('invalid_client', 'Client authentication failed.', { 'WWW-Authenticate': 'Basic' })
      }
    }
    if (!bodyId || !bodySecret) {
      throw new ApiError('invalid_client', 'Client authentication failed.', { 'WWW-Authenticate': 'Basic' })
    }
    return { clientId: bodyId, secret: bodySecret }
  }

  async function issueToken(req: Request): Promise<Result> {
    const raw = await readBody(req)
    const contentType = (req.headers.get('content-type') ?? '').toLowerCase()
    let params: URLSearchParams
    if (contentType.startsWith('application/x-www-form-urlencoded')) {
      params = new URLSearchParams(raw)
    } else if (contentType.startsWith('application/json')) {
      const body = parseJsonBody(raw, contentType)
      params = new URLSearchParams()
      for (const [k, v] of Object.entries(body)) if (typeof v === 'string') params.set(k, v)
    } else {
      throw new ApiError('unsupported_media_type', 'Use application/x-www-form-urlencoded (or application/json).')
    }

    if (params.get('grant_type') !== 'client_credentials') {
      throw new ApiError('unsupported_grant_type', 'grant_type must be client_credentials.')
    }
    const { clientId, secret } = clientCredentials(req, params)
    if (clientId.length > 64 || secret.length > 128) {
      throw new ApiError('invalid_client', 'Client authentication failed.', { 'WWW-Authenticate': 'Basic' })
    }

    let requested: string[] | null = null
    const scopeParam = params.get('scope')
    if (scopeParam !== null) {
      requested = [...new Set(scopeParam.split(' ').filter(Boolean))]
      if (requested.length === 0 || !requested.every(isScope)) {
        throw new ApiError('invalid_scope', `scope must be a space-separated subset of: ${SCOPES.join(' ')}.`)
      }
    }

    const accessToken = `zyat_${deps.randomToken()}`
    const data = await rpc<{ error?: string; scopes?: string[]; expires_in?: number }>('partner_issue_token', {
      p_client_id: clientId,
      p_secret_hash: await sha256Hex(secret),
      p_requested_scopes: requested,
      p_token_hash: await sha256Hex(accessToken),
    })
    if (data?.error === 'invalid_client') {
      throw new ApiError('invalid_client', 'Client authentication failed.', { 'WWW-Authenticate': 'Basic' })
    }
    throwIfRpcError(data, { invalid_scope: ['invalid_scope', 'This client is not allowed one or more requested scopes.'] })
    return {
      status: 200,
      body: {
        access_token: accessToken,
        token_type: 'Bearer',
        expires_in: data?.expires_in ?? TOKEN_TTL_SECONDS,
        scope: (data?.scopes ?? []).join(' '),
      },
      headers: { Pragma: 'no-cache' },
    }
  }

  // --- request pipeline ------------------------------------------------------

  async function authenticate(req: Request): Promise<Principal> {
    const token = parseBearer(req.headers.get('Authorization'))
    const unauthorized = new ApiError('unauthorized', 'A valid bearer access token is required.', {
      'WWW-Authenticate': 'Bearer',
    })
    if (!token) throw unauthorized
    const data = await rpc<{ api_client_id: string; client_id: string; environment: Principal['environment']; scopes: Scope[] } | null>(
      'partner_authenticate',
      { p_token_hash: await sha256Hex(token) }
    )
    if (!data) throw unauthorized
    return { apiClientId: data.api_client_id, clientId: data.client_id, environment: data.environment, scopes: data.scopes }
  }

  async function runIdempotent(
    req: Request,
    principal: Principal,
    path: string,
    raw: string,
    requestId: string,
    run: () => Promise<Result>
  ): Promise<Result> {
    const key = req.headers.get('Idempotency-Key')
    if (key === null) {
      throw new ApiError('idempotency_key_required', 'POST requests need an Idempotency-Key header.')
    }
    if (!isIdempotencyKey(key)) {
      throw new ApiError('invalid_request', 'Idempotency-Key must be 1-255 printable ASCII characters.')
    }
    const begin = await rpc<{ state: string; response_status?: number; response_body?: unknown }>(
      'partner_idempotency_begin',
      {
        p_api_client_id: principal.apiClientId,
        p_key: key,
        p_method: req.method,
        p_path: path,
        p_request_hash: await sha256Hex(`${req.method} ${path}\n${raw}`),
      }
    )
    if (begin.state === 'replay') {
      return {
        status: begin.response_status ?? 200,
        body: begin.response_body,
        headers: { 'Idempotent-Replayed': 'true' },
      }
    }
    if (begin.state === 'in_progress') {
      throw new ApiError('idempotency_key_in_use', 'A request with this Idempotency-Key is still being processed.')
    }
    if (begin.state === 'mismatch') {
      throw new ApiError('idempotency_key_reused', 'This Idempotency-Key was already used for a different request.')
    }

    let result: Result
    try {
      result = await run()
    } catch (err) {
      if (!(err instanceof ApiError)) throw err
      result = errorResult(err, requestId)
    }
    if (result.status >= 500) {
      // Not stored: the partner retries with the same key.
      await deps.rpc('partner_idempotency_abandon', { p_api_client_id: principal.apiClientId, p_key: key })
    } else {
      await rpc('partner_idempotency_complete', {
        p_api_client_id: principal.apiClientId,
        p_key: key,
        p_response_status: result.status,
        // The live response may contain a one-time secret. The 7-day replay
        // cache must not. SQL strips the same keys again.
        p_response_body: redactCachedSecrets(result.body),
      })
    }
    return result
  }

  async function dispatch(req: Request, requestId: string): Promise<Result> {
    const url = new URL(req.url)
    // /v1/... behind the Zyndio hostname, or /functions/v1/<name>/v1/... direct.
    const match = /^(?:\/functions\/v1\/[^/]+)?\/v1(\/.*)?$/.exec(url.pathname)
    if (!match) throw new ApiError('not_found', 'Unknown endpoint.')
    let segments: string[]
    try {
      segments = (match[1] ?? '').split('/').filter(Boolean).map(decodeURIComponent)
    } catch {
      throw new ApiError('invalid_request', 'Malformed path.')
    }
    const path = segments.join('/')

    if (path === 'oauth/token') {
      if (req.method !== 'POST') throw new ApiError('method_not_allowed', 'Use POST.', { Allow: 'POST' })
      return await issueToken(req)
    }

    const matched = matchRoute(routes, segments)
    if (!matched) throw new ApiError('not_found', 'Unknown endpoint.')
    const method = matched.route.methods[req.method]
    if (!method) {
      throw new ApiError('method_not_allowed', `Use ${Object.keys(matched.route.methods).join(', ')}.`, {
        Allow: Object.keys(matched.route.methods).join(', '),
      })
    }

    const principal = await authenticate(req)
    if (!principal.scopes.includes(method.scope)) {
      throw new ApiError('insufficient_scope', `This token lacks the ${method.scope} scope.`)
    }

    const hasBody = req.method === 'POST' || req.method === 'PATCH'
    const raw = hasBody ? await readBody(req) : ''
    const ctx: Ctx = {
      req,
      url,
      params: matched.params,
      principal,
      body: hasBody ? parseJsonBody(raw, req.headers.get('content-type')) : {},
      requestId,
    }
    if (req.method === 'POST') {
      return await runIdempotent(req, principal, path, raw, requestId, () => method.handler(ctx))
    }
    return await method.handler(ctx)
  }

  return async function handle(req: Request): Promise<Response> {
    const requestId = deps.requestId()
    try {
      return respond(await dispatch(req, requestId), requestId)
    } catch (err) {
      if (err instanceof ApiError) return respond(errorResult(err, requestId), requestId)
      deps.log('partner-api: unhandled error', err)
      return respond(errorResult(new ApiError('internal_error', 'An internal error occurred.'), requestId), requestId)
    }
  }
}
