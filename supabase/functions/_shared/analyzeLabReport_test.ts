// TC-039: analyze-lab-report handler. Real supabase-js on a fake fetch, so the
// exact PostgREST / Storage requests are checked against
// tests/contracts/analyze-lab-report.json. Fictional data only.
import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { createClient } from 'npm:@supabase/supabase-js@2.118.0'
import contract from '../../../tests/contracts/analyze-lab-report.json' with { type: 'json' }
import { handleAnalyzeLabReport, type AnalyzeLabReportDeps } from './analyzeLabReport.ts'

// Random per run: no fixed key material in the repo (gitleaks-clean).
const SECRET = crypto.randomUUID() + crypto.randomUUID()
const REPORT_ID = '11111111-1111-4111-8111-111111111111'
const PATIENT_ID = '22222222-2222-4222-8222-222222222222'
const PDF_PATH = `${PATIENT_ID}/fictional-report.pdf`
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
  updateFails?: boolean
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
      return new Response(new Uint8Array([37, 80, 68, 70]), { status: 200, headers: { 'content-type': 'application/pdf' } })
    }
    if (u.pathname === '/rest/v1/lab_reports' && r.method === 'PATCH') {
      if (backend.updateFails) return json({ message: ERROR_TEXT, code: '42703' }, 400)
      return json([{ id: REPORT_ID }])
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
    extractText: () => Promise.resolve('Hemoglobin 13.1 g/dL'),
    analyzeText: () => Promise.resolve([{ name: 'Hemoglobin', value: '13.1 g/dL' }]),
    log: (code) => logs.push(code),
    now: () => new Date('2026-11-04T10:00:00.000Z'),
    ...overrides,
  }
  return { seen, logs, deps }
}

const ROW = { id: REPORT_ID, patient_id: PATIENT_ID, data: { report_name: 'Fictional CBC', source: 'upload' }, pdf_path: PDF_PATH }

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
    assert(!s.includes('Hemoglobin'), `leaked marker: ${s}`)
  }
  for (const l of logs) assert(/^analyze-lab-report: [a-z_]+$/.test(l), `log is not a fixed code: ${l}`)
}

Deno.test('analyze-lab-report: reads the real columns, downloads by pdf_path, merges into data only (contract)', async () => {
  const h = harness({ row: ROW })
  const r = await call(h.deps)
  assertEquals(r.status, 200)
  assertEquals(r.json, { status: 'analyzed', markers: 1 })
  assertEquals(h.seen.length, 3)

  const [lookup, download, update] = h.seen
  assertEquals(lookup.method, contract.row_lookup.method)
  assertEquals(lookup.path, contract.row_lookup.path)
  assertEquals(lookup.query, fill(contract.row_lookup.query))

  assertEquals(download.method, contract.file_download.method)
  assertEquals(download.path, contract.file_download.path.replace('{pdf_path}', PDF_PATH))

  assertEquals(update.method, contract.analysis_update.method)
  assertEquals(update.path, contract.analysis_update.path)
  assertEquals(update.query, fill(contract.analysis_update.query))
  const body = update.body as Record<string, Record<string, unknown>>
  assertEquals(Object.keys(body), contract.analysis_update.body_keys)
  const added = Object.keys(body.data).filter((k) => !(k in ROW.data)).sort()
  assertEquals(added, [...contract.analysis_update.data_keys_added].sort())
  assertEquals(body.data.report_name, 'Fictional CBC')
  assertEquals(body.data.source, 'upload')
  assertEquals(body.data.markers, [{ name: 'Hemoglobin', value: '13.1 g/dL' }])
  assertEquals(body.data.analyzed_at, '2026-11-04T10:00:00.000Z')
  assertEquals(h.logs, [])
})

Deno.test('analyze-lab-report: ignores pdf_url/profile_id/title in the payload (never trusts it)', async () => {
  const h = harness({ row: ROW })
  const r = await call(h.deps, {
    body: { record: { id: REPORT_ID, pdf_url: 'https://evil.example/x.pdf', profile_id: 'someone-else', title: 'x', pdf_path: 'other/x.pdf' } },
  })
  assertEquals(r.status, 200)
  assertEquals(h.seen[1].path, `/storage/v1/object/lab-reports/${PDF_PATH}`)
  assertEquals(h.seen[2].query.patient_id, `eq.${PATIENT_ID}`)
})

Deno.test('analyze-lab-report: auth - missing 401, bad signature 401, non-service role 403, nothing read', async () => {
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

Deno.test('analyze-lab-report: no extracted text -> 501, nothing analysed or written (no invented results)', async () => {
  let analysed = false
  const h = harness({ row: ROW }, {
    extractText: () => Promise.resolve(null),
    analyzeText: () => { analysed = true; return Promise.resolve([]) },
  })
  const r = await call(h.deps)
  assertEquals(r.status, 501)
  assertEquals(r.json, { error: 'analysis_unavailable' })
  assertEquals(analysed, false)
  assertEquals(h.seen.map((s) => s.method), ['GET', 'GET'])
  assertEquals(h.logs, ['analyze-lab-report: no_text_extracted'])
})

Deno.test('analyze-lab-report: every failure answers and logs a fixed code, never error text', async () => {
  const cases: Array<[Backend, Partial<AnalyzeLabReportDeps>, number, string]> = [
    [{ row: ROW, lookupFails: true }, {}, 500, 'analyze-lab-report: lookup_failed'],
    [{ row: ROW, downloadFails: true }, {}, 500, 'analyze-lab-report: download_failed'],
    [{ row: ROW, updateFails: true }, {}, 500, 'analyze-lab-report: update_failed'],
    [{ row: ROW }, { analyzeText: () => Promise.reject(new Error(ERROR_TEXT)) }, 502, 'analyze-lab-report: analysis_failed'],
    [{ row: ROW }, { extractText: () => Promise.reject(new Error(ERROR_TEXT)) }, 500, 'analyze-lab-report: unexpected'],
  ]
  for (const [backend, overrides, status, code] of cases) {
    const h = harness(backend, overrides)
    const r = await call(h.deps)
    assertEquals(r.status, status, code)
    assertEquals(h.logs, [code])
    assertNoLeak(r.text, h.logs)
    if (backend.lookupFails || backend.downloadFails) assert(!h.seen.some((s) => s.method === 'PATCH'))
  }
})
