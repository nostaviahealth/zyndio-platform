// TC-039 / APP-05: analyze-lab-report handler. Real supabase-js on a fake
// fetch, so the exact PostgREST / Storage / RPC requests are checked against
// tests/contracts/analyze-lab-report.json. The full APP-05 behaviour (golden
// fixtures, patient access, dedupe, identity hold, confidence) is covered by
// tests/lab-pipeline/analyze-handler.test.ts (vitest). Fictional data only.
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import contract from '../../../tests/contracts/analyze-lab-report.json' with { type: 'json' }
import { handleAnalyzeLabReport, type AnalyzeLabReportDeps } from './analyzeLabReport.ts'

// Random per run: no fixed key material in the repo (gitleaks-clean).
const SECRET = crypto.randomUUID() + crypto.randomUUID()
const REPORT_ID = '11111111-1111-4111-8111-111111111111'
const PATIENT_ID = '22222222-2222-4222-8222-222222222222'
const PDF_PATH = `${PATIENT_ID}/fictional-report.pdf`
const PDF_BYTES = new Uint8Array([37, 80, 68, 70])
// SHA-256 of PDF_BYTES ("%PDF").
const PDF_SHA256 = '315d429b7714cedb6ad04ac31240145257692630457f3c88253c5beceac76027'
const ERROR_TEXT = 'relation "secret_internal_table" does not exist at /srv/app.ts:42'

function b64url(bytes: Uint8Array | string): string {
  const s = typeof bytes === 'string' ? bytes : String.fromCharCode(...bytes)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
}

async function jwt(role: string, secret = SECRET): Promise<string> {
  const head = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }))
  const body = b64url(JSON.stringify({ role, exp: Math.floor(Date.now() / 1000) + 600 }))
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${head}.${body}`)))
  return `${head}.${body}.${b64url(sig)}`
}

type Seen = { method: string; path: string; query: Record<string, string>; body: unknown }
type Backend = {
  row?: Record<string, unknown> | null
  lookupFails?: boolean
  downloadFails?: boolean
  fileBytes?: Uint8Array
  updateFails?: boolean
}

const EXTRACTION = {
  patient_name: 'Fictional Patient',
  patient_dob: '1980-01-02',
  collection_date: '2026-10-30',
  lab_name: 'Fictional Reference Lab',
  confidence: { patient_name: 0.99, patient_dob: 0.99, collection_date: 0.99, lab_name: 0.99 },
  results: [{ analyte: 'HbA1c', value: '5.4', unit: '%', reference_range: '<5.7', confidence: { analyte: 0.99, value: 0.99, unit: 0.99, reference_range: 0.99 } }],
}

function harness(backend: Backend, overrides: Partial<AnalyzeLabReportDeps> = {}) {
  const seen: Seen[] = []
  const logs: string[] = []
  const fakeFetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const r = new Request(input, init)
    const u = new URL(r.url)
    const text = r.method === 'GET' ? '' : await r.text()
    seen.push({ method: r.method, path: u.pathname, query: Object.fromEntries(u.searchParams), body: text ? JSON.parse(text) : undefined })
    const json = (v: unknown, status = 200) => new Response(JSON.stringify(v), { status, headers: { 'content-type': 'application/json' } })
    if (u.pathname === '/rest/v1/lab_reports' && r.method === 'GET') {
      if (backend.lookupFails) return json({ message: ERROR_TEXT, code: '42P01' }, 400)
      return json(backend.row ? [backend.row] : [])
    }
    if (u.pathname.startsWith('/storage/v1/object/lab-reports/')) {
      if (backend.downloadFails) return json({ statusCode: '404', error: 'not_found', message: ERROR_TEXT }, 400)
      const bytes = backend.fileBytes ?? PDF_BYTES
      const body = new ArrayBuffer(bytes.byteLength)
      new Uint8Array(body).set(bytes)
      return new Response(body, { status: 200, headers: { 'content-type': 'application/pdf' } })
    }
    if (u.pathname === '/rest/v1/lab_analyte_loinc') return json([{ analyte_key: 'hba1c', loinc: '4548-4', aliases: ['HbA1c'] }])
    if (u.pathname === '/rest/v1/patients') return json([{ display_name: 'Fictional Patient' }])
    if (u.pathname === '/rest/v1/patient_roster_meta') return json([{ birth_date: '1980-01-02' }])
    if (u.pathname === '/rest/v1/rpc/lab_pipeline_file_results') {
      if (backend.updateFails) return json({ message: ERROR_TEXT, code: '42703' }, 400)
      return json(1)
    }
    return json({ message: 'unexpected request' }, 500)
  }
  const db = createClient('https://example.test', 'fictional-service-key', {
    global: { fetch: fakeFetch },
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const deps: AnalyzeLabReportDeps = {
    env: { get: (k: string) => (k === 'JWT_SECRET' ? SECRET : undefined) },
    db,
    extractor: { name: 'fictional-extractor', extract: () => Promise.resolve(structuredClone(EXTRACTION)) },
    log: (code) => logs.push(code),
    now: () => new Date('2026-11-04T10:00:00.000Z'),
    // Kill switch on by default here; the switch itself has its own tests.
    featureAllowed: () => Promise.resolve(true),
    ...overrides,
  }
  return { seen, logs, deps }
}

const ROW = { id: REPORT_ID, patient_id: PATIENT_ID, data: { report_name: 'Fictional CBC', source: 'upload' }, pdf_path: PDF_PATH, file_sha256: null }

async function call(deps: AnalyzeLabReportDeps, opts: { token?: string | null; body?: unknown; method?: string } = {}) {
  const headers = new Headers({ 'content-type': 'application/json' })
  const token = opts.token === undefined ? await jwt('service_role') : opts.token
  if (token) headers.set('Authorization', `Bearer ${token}`)
  const method = opts.method ?? 'POST'
  const body = method === 'GET' ? undefined : JSON.stringify(opts.body ?? { type: 'INSERT', table: 'lab_reports', record: { id: REPORT_ID } })
  const res = await handleAnalyzeLabReport(new Request('https://example.test/functions/v1/analyze-lab-report', { method, headers, body }), deps)
  const text = await res.text()
  return { status: res.status, text, json: text ? JSON.parse(text) : null }
}

function fill(q: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {}
  for (const [k, v] of Object.entries(q)) out[k] = v.replace('{report_id}', REPORT_ID).replace('{patient_id}', PATIENT_ID)
  return out
}

function assertNoLeak(text: string, logs: string[]) {
  for (const s of [text, ...logs]) {
    assert(!s.includes('secret_internal_table'), `leaked error text: ${s}`)
    assert(!s.includes(PDF_PATH), `leaked file path: ${s}`)
    assert(!s.includes('HbA1c'), `leaked marker: ${s}`)
    assert(!s.includes('Fictional Patient'), `leaked name: ${s}`)
  }
  for (const l of logs) assert(/^analyze-lab-report: [a-z_]+$/.test(l), `log is not a fixed code: ${l}`)
}

Deno.test('analyze-lab-report: reads the real columns, downloads by pdf_path, files results atomically (contract)', async () => {
  const h = harness({ row: ROW })
  const r = await call(h.deps)
  assertEquals(r.status, 200)
  assertEquals(r.json.status, 'analyzed')
  assertEquals(r.json.extraction_status, 'extracted')
  assertEquals(r.json.results, 1)
  assertEquals(h.seen.length, 6)

  const [lookup, download] = h.seen
  assertEquals(lookup.method, contract.row_lookup.method)
  assertEquals(lookup.path, contract.row_lookup.path)
  assertEquals(lookup.query, fill(contract.row_lookup.query))

  assertEquals(download.method, contract.file_download.method)
  assertEquals(download.path, contract.file_download.path.replace('{pdf_path}', PDF_PATH))

  for (const key of ['analyte_map', 'account_name', 'account_dob'] as const) {
    const c = contract[key]
    const req = h.seen.find((s) => s.path === c.path)
    assert(req, key)
    assertEquals(req.method, c.method)
    assertEquals(req.query, fill(c.query))
  }

  const file = h.seen.find((s) => s.path === contract.analysis_file.path)!
  assertEquals(file.method, contract.analysis_file.method)
  const body = file.body as { p_report_id: string; p_report: Record<string, Record<string, unknown>>; p_results: Record<string, unknown>[] }
  assertEquals(Object.keys(body).sort(), contract.analysis_file.body_keys)
  assertEquals(body.p_report_id, REPORT_ID)
  assertEquals(Object.keys(body.p_report).sort(), contract.analysis_file.report_keys)
  const added = Object.keys(body.p_report.data).filter((k) => !(k in ROW.data) && k !== 'date' && k !== 'lab_name').sort()
  assertEquals(added, contract.analysis_file.data_keys_added)
  assertEquals(body.p_report.data.analyzed_at, '2026-11-04T10:00:00.000Z')
  assertEquals(body.p_report.file_sha256 as unknown, PDF_SHA256)
  for (const res of body.p_results) assertEquals(Object.keys(res).sort(), contract.analysis_file.result_keys)
  assertEquals(body.p_results[0].loinc, '4548-4')
  assertEquals(body.p_results[0].value, 5.4)
  assertEquals(h.logs, [])
})

Deno.test('analyze-lab-report: ignores pdf_url/profile_id/title in the payload (never trusts it)', async () => {
  const h = harness({ row: ROW })
  const r = await call(h.deps, {
    body: { record: { id: REPORT_ID, pdf_url: 'https://evil.example/x.pdf', profile_id: 'someone-else', title: 'x', pdf_path: 'other/x.pdf' } },
  })
  assertEquals(r.status, 200)
  assertEquals(h.seen[1].path, `/storage/v1/object/lab-reports/${PDF_PATH}`)
  // The account looked up is the ROW's patient, not anything in the payload.
  assertEquals(h.seen.find((x) => x.path === '/rest/v1/patients')!.query.id, `eq.${PATIENT_ID}`)
})

// APP-05: a signed-in patient may analyse their OWN report (covered in
// tests/lab-pipeline/analyze-handler.test.ts); a token with no user (`sub`)
// or the anon role is still 403 before anything is read.
Deno.test('analyze-lab-report: auth - missing 401, bad signature 401, no-user/anon 403, nothing read', async () => {
  for (const [token, status] of [[null, 401], ['not-a-jwt', 401], [await jwt('service_role', 'wrong-secret-wrong-secret-wrong-secret'), 401], [await jwt('authenticated'), 403], [await jwt('anon'), 403]] as const) {
    const h = harness({ row: ROW })
    const r = await call(h.deps, { token })
    assertEquals(r.status, status, String(token))
    assertEquals(h.seen.length, 0)
  }
})

Deno.test('analyze-lab-report: method and payload validation', async () => {
  let h = harness({ row: ROW })
  assertEquals((await call(h.deps, { method: 'GET' })).status, 405)
  for (const body of [{}, { record: null }, { record: { id: 'not-a-uuid' } }, [1], 'x']) {
    h = harness({ row: ROW })
    const r = await call(h.deps, { body })
    assertEquals(r.status, 400, JSON.stringify(body))
    assertEquals(h.seen.length, 0)
  }
})

Deno.test('analyze-lab-report: unknown report 404; report with no file 422; nothing written', async () => {
  let h = harness({ row: null })
  assertEquals((await call(h.deps)).status, 404)
  assertEquals(h.seen.length, 1)
  h = harness({ row: { ...ROW, pdf_path: null } })
  const r = await call(h.deps)
  assertEquals(r.status, 422)
  assertEquals(r.json, { status: 'skipped', reason: 'no_file' })
  assertEquals(h.seen.length, 1)
})

Deno.test('analyze-lab-report: non-PDF bytes named .pdf are rejected before extraction', async () => {
  let extracted = false
  const h = harness(
    { row: ROW, fileBytes: new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]) },
    { extractor: { name: 'x', extract: () => { extracted = true; return Promise.resolve(EXTRACTION) } } },
  )
  const r = await call(h.deps)
  assertEquals(r.status, 422)
  assertEquals(r.json, { error: 'invalid_file_content' })
  assertEquals(extracted, false)
})

Deno.test('analyze-lab-report: files over 14MB are rejected before extraction', async () => {
  let extracted = false
  const big = new Uint8Array(14 * 1024 * 1024 + 1)
  big.set([37, 80, 68, 70])
  const h = harness(
    { row: ROW, fileBytes: big },
    { extractor: { name: 'x', extract: () => { extracted = true; return Promise.resolve(EXTRACTION) } } },
  )
  const r = await call(h.deps)
  assertEquals(r.status, 422)
  assertEquals(r.json, { error: 'file_too_large' })
  assertEquals(extracted, false)
})

Deno.test('analyze-lab-report: lab_extraction kill switch off -> 503, model never called, nothing written', async () => {
  let extracted = false
  let askedFor = ''
  const h = harness(
    { row: ROW },
    {
      extractor: { name: 'x', extract: () => { extracted = true; return Promise.resolve(EXTRACTION) } },
      featureAllowed: (id) => { askedFor = id; return Promise.resolve(false) },
    },
  )
  const r = await call(h.deps)
  assertEquals(r.status, 503)
  assertEquals(r.json, { error: 'ai_feature_disabled', feature: 'lab_extraction' })
  assertEquals(askedFor, PATIENT_ID)
  assertEquals(extracted, false)
  assertEquals(h.seen.filter((s) => s.method !== 'GET').length, 0)
})

Deno.test('analyze-lab-report: kill switch unreadable -> 503 fail closed, model never called', async () => {
  let extracted = false
  const h = harness(
    { row: ROW },
    {
      extractor: { name: 'x', extract: () => { extracted = true; return Promise.resolve(EXTRACTION) } },
      featureAllowed: () => Promise.reject(new Error('db down')),
    },
  )
  const r = await call(h.deps)
  assertEquals(r.status, 503)
  assertEquals(r.json, { error: 'ai_switch_check_unavailable' })
  assertEquals(extracted, false)
})

Deno.test('analyze-lab-report: extractor switched off -> 501, nothing analysed or written (no invented results)', async () => {
  const h = harness({ row: ROW }, { extractor: null })
  const r = await call(h.deps)
  assertEquals(r.status, 501)
  assertEquals(r.json, { error: 'analysis_unavailable' })
  assertEquals(h.seen.map((s) => s.method), ['GET', 'GET'])
  assertEquals(h.logs, ['analyze-lab-report: extractor_disabled'])
})

Deno.test('analyze-lab-report: every failure answers and logs a fixed code, never error text', async () => {
  const cases: Array<[Backend, Partial<AnalyzeLabReportDeps>, number, string]> = [
    [{ row: ROW, lookupFails: true }, {}, 500, 'analyze-lab-report: lookup_failed'],
    [{ row: ROW, downloadFails: true }, {}, 500, 'analyze-lab-report: download_failed'],
    [{ row: ROW, updateFails: true }, {}, 500, 'analyze-lab-report: file_failed'],
    [{ row: ROW }, { extractor: { name: 'x', extract: () => Promise.reject(new Error(ERROR_TEXT)) } }, 502, 'analyze-lab-report: analysis_failed'],
    // Malformed extractor output is caught by the outer guard.
    [{ row: ROW }, { extractor: { name: 'x', extract: () => Promise.resolve(null as unknown as typeof EXTRACTION) } }, 500, 'analyze-lab-report: unexpected'],
  ]
  for (const [backend, overrides, status, code] of cases) {
    const h = harness(backend, overrides)
    const r = await call(h.deps)
    assertEquals(r.status, status, code)
    assertEquals(h.logs, [code])
    assertNoLeak(r.text, h.logs)
    if (backend.lookupFails || backend.downloadFails) assert(!h.seen.some((s) => s.path.startsWith('/rest/v1/rpc/')))
  }
})
