// APP-05: the analyze-lab-report handler end to end on a fake backend (real
// supabase-js, fake fetch), with the golden fixture files and a recorded
// extractor. Runs under vitest (Node); the Deno-side twin is
// supabase/functions/_shared/analyzeLabReport_test.ts. Fictional data only.
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { createClient } from '@supabase/supabase-js';
import { beforeAll, describe, expect, it } from 'vitest';
import contract from '../contracts/analyze-lab-report.json';
import type { AnalyzeLabReportDeps } from '../../supabase/functions/_shared/analyzeLabReport.ts';
import type { RawExtraction } from '../../supabase/functions/_shared/labNormalize.ts';
import { reviewedAnalyteMap } from './reviewedMap.ts';

// cors.ts reads allowed origins from Deno.env at call time.
(globalThis as { Deno?: unknown }).Deno ??= { env: { get: () => undefined } };
const { handleAnalyzeLabReport, IDENTITY_HOLD_MESSAGE } = await import('../../supabase/functions/_shared/analyzeLabReport.ts');

const DIR = fileURLToPath(new URL('../fixtures/labs/', import.meta.url));
const golden = JSON.parse(readFileSync(`${DIR}golden.json`, 'utf8')) as {
  reports: { files: string[]; collected_on: string; units: string; extraction: RawExtraction; expected: Record<string, number> }[];
};
const SECRET = crypto.randomUUID() + crypto.randomUUID();
const REPORT_ID = '11111111-1111-4111-8111-111111111111';
const PATIENT_ID = '22222222-2222-4222-8222-222222222222';
const OTHER_PATIENT = '33333333-3333-4333-8333-333333333333';
const STAFF_ID = '44444444-4444-4444-8444-444444444444';
const ERROR_TEXT = 'relation "secret_internal_table" does not exist at /srv/app.ts:42';

function b64url(s: string | Uint8Array) {
  return Buffer.from(s).toString('base64url');
}
async function jwt(claims: Record<string, unknown>, secret = SECRET) {
  const head = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = b64url(JSON.stringify({ ...claims, exp: Math.floor(Date.now() / 1000) + 600 }));
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${head}.${body}`)));
  return `${head}.${body}.${b64url(sig)}`;
}

type Seen = { method: string; path: string; query: Record<string, string>; body: unknown };
type Backend = {
  row?: Record<string, unknown> | null;
  file?: Uint8Array;
  account?: { name: string | null; dob: string | null };
  fileFails?: { code: string } | null;
  mapFails?: boolean;
};

function harness(backend: Backend, overrides: Partial<AnalyzeLabReportDeps> & { extraction?: RawExtraction } = {}) {
  const seen: Seen[] = [];
  const logs: string[] = [];
  const extracted: { bytes: number; mime: string }[] = [];
  const budget: string[] = [];
  const fakeFetch = async (input: RequestInfo | URL, init?: RequestInit) => {
    const r = new Request(input, init);
    const u = new URL(r.url);
    const text = r.method === 'GET' ? '' : await r.text();
    seen.push({ method: r.method, path: u.pathname, query: Object.fromEntries(u.searchParams), body: text ? JSON.parse(text) : undefined });
    const json = (v: unknown, status = 200) => new Response(JSON.stringify(v), { status, headers: { 'content-type': 'application/json' } });
    if (u.pathname === '/rest/v1/lab_reports') return json(backend.row ? [backend.row] : []);
    if (u.pathname.includes('/lab-reports/')) return new Response(backend.file ?? new Uint8Array([37, 80, 68, 70]), { status: 200, headers: { 'content-type': 'application/pdf' } });
    if (u.pathname === '/rest/v1/lab_analyte_loinc') {
      if (backend.mapFails) return json({ message: ERROR_TEXT, code: '42P01' }, 400);
      return json(reviewedAnalyteMap().map(({ analyte_key, loinc, aliases }) => ({ analyte_key, loinc, aliases })));
    }
    if (u.pathname === '/rest/v1/patients') return json(backend.account?.name === undefined ? [{ display_name: 'Jordan Rivera' }] : [{ display_name: backend.account.name }]);
    if (u.pathname === '/rest/v1/patient_roster_meta') return json(backend.account?.dob === undefined ? [{ birth_date: '1979-03-14' }] : [{ birth_date: backend.account.dob }]);
    if (u.pathname === '/rest/v1/rpc/lab_pipeline_file_results') {
      if (backend.fileFails) return json({ message: ERROR_TEXT, code: backend.fileFails.code }, 409);
      const b = JSON.parse(text) as { p_results: unknown[] };
      return json(b.p_results.length);
    }
    return json({ message: 'unexpected request' }, 500);
  };
  const db = createClient('https://example.test', 'fictional-service-key', {
    global: { fetch: fakeFetch },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { extraction, ...rest } = overrides;
  const deps: AnalyzeLabReportDeps = {
    env: { get: (k: string) => (k === 'JWT_SECRET' ? SECRET : undefined) },
    db: db as unknown as AnalyzeLabReportDeps['db'],
    extractor: {
      name: 'recorded-golden-extractor',
      extract: (bytes, mime) => {
        extracted.push({ bytes: bytes.byteLength, mime });
        return Promise.resolve(extraction ?? golden.reports[0].extraction);
      },
    },
    log: (code) => logs.push(code),
    now: () => new Date('2026-11-04T10:00:00.000Z'),
    loadCallerFacts: (userId) => Promise.resolve(
      userId === STAFF_ID
        ? { userId, isPatient: true, staffRole: 'physician', isPlatformAdmin: false }
        : { userId, isPatient: true, staffRole: null, isPlatformAdmin: false },
    ),
    consumeBudget: (userId) => { budget.push(userId); return Promise.resolve({ allowed: true }); },
    ...rest,
  };
  return { seen, logs, deps, extracted, budget };
}

async function call(deps: AnalyzeLabReportDeps, opts: { token?: string | null; body?: unknown } = {}) {
  const headers = new Headers({ 'content-type': 'application/json' });
  const token = opts.token === undefined ? await jwt({ role: 'service_role' }) : opts.token;
  if (token) headers.set('Authorization', `Bearer ${token}`);
  const res = await handleAnalyzeLabReport(new Request('https://example.test/functions/v1/analyze-lab-report', {
    method: 'POST', headers, body: JSON.stringify(opts.body ?? { report_id: REPORT_ID }),
  }), deps);
  const text = await res.text();
  return { status: res.status, text, json: text ? JSON.parse(text) : null, headers: res.headers };
}

const fileOf = (name: string) => new Uint8Array(readFileSync(`${DIR}${name}`));
const sha = (b: Uint8Array) => createHash('sha256').update(b).digest('hex');
const patientToken = (sub = PATIENT_ID) => jwt({ role: 'authenticated', sub });

let PDF: Uint8Array;
let ROW: Record<string, unknown>;
beforeAll(() => {
  PDF = fileOf(golden.reports[0].files[0]);
  ROW = { id: REPORT_ID, patient_id: PATIENT_ID, data: { title: 'Fictional panel', source: 'upload' }, pdf_path: `${PATIENT_ID}/0d6f8a2e-1b3c-4d5e-8f90-123456789abc.pdf`, file_sha256: sha(PDF) };
});

function filed(h: ReturnType<typeof harness>) {
  const call = h.seen.find((s) => s.path === '/rest/v1/rpc/lab_pipeline_file_results');
  return call?.body as { p_report_id: string; p_report: Record<string, any>; p_results: Record<string, any>[] } | undefined;
}

describe('analyze-lab-report handler (APP-05)', () => {
  it('golden US PDF: files every result with LOINC, canonical value, as-reported value/unit and factor (contract)', async () => {
    const h = harness({ row: ROW, file: PDF });
    const r = await call(h.deps);
    expect(r.status).toBe(200);
    expect(r.json).toMatchObject({ status: 'analyzed', extraction_status: 'extracted', identity_hold: false, results: 7, needs_review: 0, collected_on: '2026-04-02' });
    expect(h.extracted).toEqual([{ bytes: PDF.byteLength, mime: 'application/pdf' }]);

    const [lookup, download] = h.seen;
    expect([lookup.method, lookup.path, lookup.query]).toEqual([contract.row_lookup.method, contract.row_lookup.path, { select: contract.row_lookup.query.select, id: `eq.${REPORT_ID}` }]);
    expect(download.path).toContain(`/lab-reports/${ROW.pdf_path}`);
    const map = h.seen.find((s) => s.path === contract.analyte_map.path)!;
    expect(map.query).toEqual(contract.analyte_map.query);
    expect(h.seen.find((s) => s.path === contract.account_name.path)!.query).toEqual({ select: 'display_name', id: `eq.${PATIENT_ID}` });
    expect(h.seen.find((s) => s.path === contract.account_dob.path)!.query).toEqual({ select: 'birth_date', patient_id: `eq.${PATIENT_ID}` });

    const f = filed(h)!;
    expect(Object.keys(f).sort()).toEqual(contract.analysis_file.body_keys);
    expect(Object.keys(f.p_report).sort()).toEqual(contract.analysis_file.report_keys);
    expect(Object.keys(f.p_report.data).filter((k) => k !== 'date' && k !== 'lab_name').sort()).toEqual(contract.analysis_file.data_keys_added);
    for (const res of f.p_results) expect(Object.keys(res).sort()).toEqual(contract.analysis_file.result_keys);
    expect(f.p_report_id).toBe(REPORT_ID);
    expect(f.p_report).toMatchObject({ file_sha256: sha(PDF), extraction_status: 'extracted', identity_hold: false, collected_on: '2026-04-02', lab_name: 'Fictional Reference Lab' });
    // Never written: id / org / patient / file path.
    for (const k of ['id', 'org_id', 'patient_id', 'pdf_path']) expect(f.p_report).not.toHaveProperty(k);
    expect(Object.fromEntries(f.p_results.map((x) => [x.analyte_key, x.value]))).toEqual(golden.reports[0].expected);
    const a1c = f.p_results.find((x) => x.analyte_key === 'hba1c')!;
    expect(a1c).toMatchObject({ loinc: '4548-4', unit: '%', reported_value: '6.2', reported_unit: '%', conversion_kind: 'none', conversion_factor: 1, reference_range_text: '<5.7', range_high: 5.7, status: 'outside_range' });
    expect(h.logs).toEqual([]);
  });

  it('golden SI report gives the same filed canonical values as the US report', async () => {
    const si = golden.reports.find((x) => x.units === 'si' && x.collected_on === '2026-04-02')!;
    const siFile = fileOf(si.files[1]);
    const h = harness({ row: { ...ROW, pdf_path: `${PATIENT_ID}/0d6f8a2e-1b3c-4d5e-8f90-123456789abc.png`, file_sha256: sha(siFile) }, file: siFile }, { extraction: si.extraction });
    const r = await call(h.deps);
    expect(r.status).toBe(200);
    expect(h.extracted[0].mime).toBe('image/png');
    const f = filed(h)!;
    expect(Object.fromEntries(f.p_results.map((x) => [x.analyte_key, x.value]))).toEqual(golden.reports[0].expected);
    const insulin = f.p_results.find((x) => x.analyte_key === 'insulin_fasting')!;
    expect(insulin).toMatchObject({ value: 18.1, unit: 'uIU/mL', reported_value: '108.6', reported_unit: 'pmol/L', conversion_kind: 'divide', conversion_factor: 6 });
  });

  it('the patient may analyse their own report (budget spent once); returns their markers', async () => {
    const h = harness({ row: ROW, file: PDF });
    const r = await call(h.deps, { token: await patientToken() });
    expect(r.status).toBe(200);
    expect(h.budget).toEqual([PATIENT_ID]);
    expect(r.json.markers).toHaveLength(7);
    expect(r.json.markers[0]).toMatchObject({ name: 'HbA1c', value: '6.2', unit: '%', status: 'High', loinc: '4548-4', needs_review: false });
  });

  it("another patient's report is a 404 (same as missing), nothing downloaded or spent", async () => {
    const h = harness({ row: ROW, file: PDF });
    const r = await call(h.deps, { token: await patientToken(OTHER_PATIENT) });
    expect(r.status).toBe(404);
    expect(h.seen).toHaveLength(1);
    expect(h.budget).toEqual([]);
    expect(h.extracted).toEqual([]);
  });

  it('staff and anon are 403 before anything is read', async () => {
    for (const token of [await patientToken(STAFF_ID), await jwt({ role: 'anon' }), await jwt({ role: 'authenticated' })]) {
      const h = harness({ row: ROW, file: PDF });
      const r = await call(h.deps, { token });
      expect(r.status).toBe(403);
      expect(h.seen).toEqual([]);
    }
  });

  it('over budget: 429 with Retry-After, before the AI call', async () => {
    const h = harness({ row: ROW, file: PDF }, { consumeBudget: () => Promise.resolve({ allowed: false, retryAfterSeconds: 120 }) });
    const r = await call(h.deps, { token: await patientToken() });
    expect(r.status).toBe(429);
    expect(r.headers.get('Retry-After')).toBe('120');
    expect(h.extracted).toEqual([]);
    expect(filed(h)).toBeUndefined();
  });

  it('flag off (no extractor): 501 analysis_unavailable, nothing extracted or filed, no budget spent', async () => {
    const h = harness({ row: ROW, file: PDF }, { extractor: null });
    const r = await call(h.deps, { token: await patientToken() });
    expect(r.status).toBe(501);
    expect(r.json).toEqual({ error: 'analysis_unavailable' });
    expect(filed(h)).toBeUndefined();
    expect(h.budget).toEqual([]);
    expect(h.logs).toEqual(['analyze-lab-report: extractor_disabled']);
  });

  it('dedupe: a file whose SHA-256 differs from the filed one is refused; a second copy of a filed file is 409', async () => {
    let h = harness({ row: { ...ROW, file_sha256: 'f'.repeat(64) }, file: PDF });
    let r = await call(h.deps);
    expect([r.status, r.json]).toEqual([422, { error: 'file_hash_mismatch' }]);
    expect(h.extracted).toEqual([]);

    // Legacy row without a hash: it gets one; the unique index says the
    // patient already filed that file -> 409, nothing else changes.
    h = harness({ row: { ...ROW, file_sha256: null }, file: PDF, fileFails: { code: '23505' } });
    r = await call(h.deps);
    expect([r.status, r.json]).toEqual([409, { error: 'duplicate' }]);
    expect(filed(h)!.p_report.file_sha256).toBe(sha(PDF));
  });

  it('identity mismatch: report held, patient told, no values returned', async () => {
    const h = harness({ row: ROW, file: PDF, account: { name: 'Sam Okafor', dob: '1979-03-14' } });
    const r = await call(h.deps, { token: await patientToken() });
    expect(r.status).toBe(200);
    expect(r.json).toEqual({ status: 'analyzed', extraction_status: 'identity_hold', identity_hold: true, results: 7, needs_review: 0, message: IDENTITY_HOLD_MESSAGE });
    const f = filed(h)!;
    expect(f.p_report).toMatchObject({ identity_hold: true, extraction_status: 'identity_hold' });
    expect(f.p_report.data.extraction.identity).toEqual({ name: 'mismatch', dob: 'match', reasons: ['name_mismatch'] });
    expect(f.p_report.data.extraction.printed_identity).toEqual({ name: 'RIVERA, JORDAN', dob: '03/14/1979' });
  });

  it('low-confidence and implausible values are filed as needs_review with reasons', async () => {
    const ex = structuredClone(golden.reports[0].extraction);
    ex.results[0].confidence = { ...ex.results[0].confidence, value: 0.4 };
    ex.results[1].value = '10400';
    const h = harness({ row: ROW, file: PDF }, { extraction: ex });
    const r = await call(h.deps);
    expect(r.json).toMatchObject({ extraction_status: 'needs_review', needs_review: 2 });
    const f = filed(h)!;
    expect(f.p_results[0]).toMatchObject({ status: 'needs_review', review_reasons: ['low_confidence:value'], confidence: 0.4 });
    expect(f.p_results[1]).toMatchObject({ status: 'needs_review', review_reasons: ['implausible_value'], value: 10400 });
  });

  it('an unknown analyte is filed unmapped (no LOINC)', async () => {
    const ex = structuredClone(golden.reports[0].extraction);
    ex.results.push({ analyte: 'Lp-PLA2 Activity', value: '180', unit: 'nmol/min/mL', reference_range: '<225', confidence: ex.results[0].confidence });
    const h = harness({ row: ROW, file: PDF }, { extraction: ex });
    await call(h.deps);
    expect(filed(h)!.p_results.at(-1)).toMatchObject({ analyte_key: 'unmapped:lp_pla2_activity', is_unmapped: true, loinc: null, value: 180 });
  });

  it('failures answer and log fixed codes only, never error text or values', async () => {
    const cases: [Backend, Partial<AnalyzeLabReportDeps>, number, string][] = [
      [{ row: ROW, file: PDF, mapFails: true }, {}, 500, 'analyze-lab-report: reference_lookup_failed'],
      [{ row: ROW, file: PDF, fileFails: { code: '23514' } }, {}, 500, 'analyze-lab-report: file_failed'],
      [{ row: ROW, file: PDF }, { extractor: { name: 'x', extract: () => Promise.reject(new Error(ERROR_TEXT)) } }, 502, 'analyze-lab-report: analysis_failed'],
      [{ row: ROW, file: PDF }, { loadCallerFacts: () => Promise.reject(new Error(ERROR_TEXT)) }, 503, 'analyze-lab-report: access_lookup_failed'],
      [{ row: ROW, file: PDF }, { consumeBudget: () => Promise.reject(new Error(ERROR_TEXT)) }, 503, 'analyze-lab-report: rate_limit_unavailable'],
      [{ row: { ...ROW, pdf_path: `${PATIENT_ID}/x.txt` }, file: PDF, }, {}, 422, 'analyze-lab-report: unsupported_file_type'],
    ];
    for (const [backend, overrides, status, code] of cases) {
      const h = harness({ ...backend, row: { ...backend.row!, file_sha256: null } }, overrides);
      const r = await call(h.deps, { token: await patientToken() });
      expect([code, r.status]).toEqual([code, status]);
      expect(h.logs).toEqual([code]);
      for (const s of [r.text, ...h.logs]) {
        expect(s).not.toContain('secret_internal_table');
        expect(s).not.toContain('RIVERA');
        expect(s).not.toContain(String(ROW.pdf_path));
      }
    }
  });
});
