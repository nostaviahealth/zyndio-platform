// TC-039: the analyze-lab-report Edge Function, as a testable handler.
//
// Before TC-039 the function read `record.pdf_url`, `record.title` and
// `record.profile_id` from the webhook payload and wrote `markers`, `title`,
// `summary` and `updated_at` columns. None of those exist on lab_reports
// (real columns: id, org_id, patient_id, report_type, data, created_at,
// identity_hold, pdf_path - supabase/migrations/*_tc005_schema.sql,
// *_tc015_schema.sql, *_tc036_lab_reports_private_storage.sql), so every call
// crashed and returned the raw exception text. It also accepted any caller
// the gateway let through, while running with the service role.
//
// Now:
// - service_role callers only (a Database Webhook / internal job), checked by
//   signature here as well as at the gateway (same rule as process-outbox).
// - Only `record.id` is taken from the payload. The row is re-read with the
//   real columns pinned in tests/contracts/analyze-lab-report.json, and the
//   file is downloaded by its stored object path (lab_reports.pdf_path).
// - Results are merged into the `data` payload (the report body lives there,
//   as for every other lab_reports writer); id, org_id, patient_id and
//   pdf_path are never written.
// - Nothing is ever written unless text was really extracted from the file.
//   There is no server-side PDF text extractor yet (the old code analysed a
//   hard-coded sample string), so production answers 501 analysis_unavailable
//   and leaves the report untouched rather than saving invented biomarkers.
// - Logs and responses carry fixed codes only - never an error message,
//   stack, payload, path or marker value.
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import { jsonResponse } from './cors.ts'
import { isValidUuid, parseBearerToken, parseJsonObject, verifyBearerJwt, type JwtVerifyEnv } from './validation.ts'

export const LAB_REPORTS_BUCKET = 'lab-reports'
export const ANALYZE_ROW_COLUMNS = 'id,patient_id,data,pdf_path'
export const MAX_BODY_BYTES = 64 * 1024

export type ExtractedMarker = Record<string, unknown>

export interface AnalyzeLabReportDeps {
  env: JwtVerifyEnv
  db: SupabaseClient
  /** Text of the report file, or null when it can't be extracted. */
  extractText(file: Blob): Promise<string | null>
  /** Biomarkers found in the extracted text. */
  analyzeText(text: string): Promise<ExtractedMarker[]>
  /** Fixed event codes only. */
  log(code: string): void
  now?: () => Date
}

type Row = { id: string; patient_id: string; data: unknown; pdf_path: string | null }

export async function handleAnalyzeLabReport(req: Request, deps: AnalyzeLabReportDeps): Promise<Response> {
  const fail = (code: string, status: number, error = 'internal_error') => {
    deps.log(`analyze-lab-report: ${code}`)
    return jsonResponse(req, { error }, status)
  }
  try {
    if (req.method !== 'POST') return jsonResponse(req, { error: 'method_not_allowed' }, 405)

    const token = parseBearerToken(req.headers.get('Authorization'))
    if (!token) return jsonResponse(req, { error: 'missing_bearer_token' }, 401)
    let claims: Record<string, unknown>
    try {
      claims = await verifyBearerJwt(token, deps.env)
    } catch {
      return jsonResponse(req, { error: 'invalid_token' }, 401)
    }
    if (claims.role !== 'service_role') return jsonResponse(req, { error: 'service_role_required' }, 403)

    const raw = await req.text()
    if (raw.length > MAX_BODY_BYTES) return jsonResponse(req, { error: 'invalid_request' }, 400)
    const parsed = parseJsonObject(raw)
    const record = parsed.ok ? parsed.body.record : undefined
    const reportId = record && typeof record === 'object' ? (record as Record<string, unknown>).id : undefined
    if (!isValidUuid(reportId)) return jsonResponse(req, { error: 'invalid_request' }, 400)

    const { data: rows, error: lookupError } = await deps.db
      .from('lab_reports')
      .select(ANALYZE_ROW_COLUMNS)
      .eq('id', reportId)
    if (lookupError) return fail('lookup_failed', 500)
    const row = (rows as Row[] | null)?.[0]
    if (!row) return jsonResponse(req, { error: 'not_found' }, 404)
    if (!row.pdf_path) return jsonResponse(req, { status: 'skipped', reason: 'no_file' }, 422)

    const { data: file, error: downloadError } = await deps.db.storage.from(LAB_REPORTS_BUCKET).download(row.pdf_path)
    if (downloadError || !file) return fail('download_failed', 500)

    const text = await deps.extractText(file)
    if (text === null || text.trim() === '') return fail('no_text_extracted', 501, 'analysis_unavailable')

    let markers: ExtractedMarker[]
    try {
      markers = await deps.analyzeText(text)
    } catch {
      return fail('analysis_failed', 502, 'analysis_failed')
    }
    if (!Array.isArray(markers)) return fail('analysis_failed', 502, 'analysis_failed')

    const data = analyzedData(row.data, markers, (deps.now ?? (() => new Date()))())
    const { data: updated, error: updateError } = await deps.db
      .from('lab_reports')
      .update({ data })
      .eq('id', row.id)
      .eq('patient_id', row.patient_id)
      .select('id')
    if (updateError || !Array.isArray(updated) || updated.length !== 1) return fail('update_failed', 500)

    return jsonResponse(req, { status: 'analyzed', markers: markers.length })
  } catch {
    return fail('unexpected', 500)
  }
}

/** The report's existing `data` payload with the analysis merged in. */
export function analyzedData(existing: unknown, markers: ExtractedMarker[], now: Date): Record<string, unknown> {
  const base = existing && typeof existing === 'object' && !Array.isArray(existing)
    ? { ...(existing as Record<string, unknown>) }
    : {}
  return {
    ...base,
    markers,
    summary: 'Analysis Complete. Biomarkers extracted successfully.',
    analyzed_at: now.toISOString(),
  }
}
