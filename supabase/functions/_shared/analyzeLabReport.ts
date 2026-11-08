// TC-039 / APP-05: the analyze-lab-report Edge Function, as a testable
// handler. This is the ONE lab extraction path: the patient app files the
// upload (lab_reports row + private file, with the file's SHA-256) and calls
// this function; a Database Webhook / internal job may call it too.
//
// TC-039 rules kept:
// - Only the report id comes from the request. The row is re-read with the
//   real columns pinned in tests/contracts/analyze-lab-report.json, and the
//   file is downloaded by its stored object path (lab_reports.pdf_path).
// - id, org_id, patient_id and pdf_path are never written.
// - Nothing is filed unless the file was really read. With the AI extractor
//   switched off (LAB_AI_EXTRACTION_ENABLED != "true", the default) the answer
//   is 501 analysis_unavailable and the report is left untouched.
// - Logs and responses carry fixed codes only - never an error message,
//   stack, payload, path, name or value.
//
// APP-05:
// - Callers: service_role, or the signed-in PATIENT whose report it is
//   (JWT verified here; staff and Zyndio admins 403 - the TC-021 patients-only
//   rule; someone else's report answers 404, same as a missing one). Patient
//   calls spend the per-patient intelligence budget before the AI call (429).
// - Dedupe: the downloaded file's SHA-256 must equal lab_reports.file_sha256
//   (set by the app; unique per patient). A legacy row without one gets it
//   filled; if the patient already has that file filed -> 409 duplicate.
// - Extraction -> labNormalize.ts: reviewed LOINC table, US canonical units
//   (original value/unit/factor kept), printed ranges, plausibility limits,
//   per-field confidence (below the threshold -> needs_review), identity check
//   against the account (patients.display_name, patient_roster_meta.birth_date)
//   -> identity_hold. A hold is never cleared here (that's a person's call).
// - Filing is atomic: public.lab_pipeline_file_results() replaces the
//   report's lab_results and updates the report in one transaction.
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import { jsonResponse } from './cors.ts'
import { isValidUuid, parseBearerToken, parseJsonObject, verifyBearerJwt, type JwtVerifyEnv } from './validation.ts'
import {
  decideIntelligenceAccess,
  loadIntelligenceCallerFacts,
  type IntelligenceCallerFacts,
} from './intelligenceAccess.ts'
import { consumeIntelligenceBudget, rateLimitedHeaders, type IntelligenceBudget } from './intelligenceRateLimit.ts'
import { MAX_EXTRACT_BYTES, bytesMatchDeclaredType, mimeTypeForPath, type LabExtractor } from './labExtractor.ts'
import {
  DEFAULT_CONFIDENCE_THRESHOLD,
  normalizeExtraction,
  type AnalyteMapRow,
  type NormalizedReport,
  type NormalizedResult,
  type RawExtraction,
} from './labNormalize.ts'

export const LAB_REPORTS_BUCKET = 'lab-reports'
export const ANALYZE_ROW_COLUMNS = 'id,patient_id,data,pdf_path,file_sha256'
export const ANALYTE_MAP_COLUMNS = 'analyte_key,loinc,aliases'
export const MAX_BODY_BYTES = 64 * 1024

/** Shown to the patient when their report is held (APP-05 identity check). */
export const IDENTITY_HOLD_MESSAGE =
  "The name or date of birth on this report doesn't match your account, so it's on hold. Your care team will check it before any results are added to your record."

export interface AnalyzeLabReportDeps {
  env: JwtVerifyEnv
  db: SupabaseClient
  /** The AI extractor, or null when it is switched off (labExtractorFromEnv). */
  extractor: LabExtractor | null
  /** Fields below this confidence need review. */
  confidenceThreshold?: number
  /** Fixed event codes only. */
  log(code: string): void
  now?: () => Date
  loadCallerFacts?(userId: string): Promise<IntelligenceCallerFacts>
  consumeBudget?(userId: string): Promise<IntelligenceBudget>
}

type Row = { id: string; patient_id: string; data: unknown; pdf_path: string | null; file_sha256: string | null }

async function sha256Hex(bytes: Uint8Array<ArrayBuffer>): Promise<string> {
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))
  return [...digest].map((b) => b.toString(16).padStart(2, '0')).join('')
}

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

    // Who is asking: the service role, or a patient (for their own report).
    let patientId: string | null = null
    if (claims.role !== 'service_role') {
      if (claims.role !== 'authenticated' || !isValidUuid(claims.sub)) {
        return jsonResponse(req, { error: 'service_role_or_patient_required' }, 403)
      }
      let facts: IntelligenceCallerFacts
      try {
        facts = await (deps.loadCallerFacts ?? ((id) => loadIntelligenceCallerFacts(deps.db, id)))(claims.sub)
      } catch {
        return fail('access_lookup_failed', 503, 'access_check_unavailable')
      }
      const access = decideIntelligenceAccess(facts, undefined)
      if (!access.ok) return jsonResponse(req, { error: 'service_role_or_patient_required' }, 403)
      patientId = claims.sub
    }

    const raw = await req.text()
    if (raw.length > MAX_BODY_BYTES) return jsonResponse(req, { error: 'invalid_request' }, 400)
    const parsed = parseJsonObject(raw)
    // Webhook shape { record: { id } } or the app's { report_id }.
    const record = parsed.ok ? parsed.body.record : undefined
    const reportId = parsed.ok && parsed.body.report_id !== undefined
      ? parsed.body.report_id
      : record && typeof record === 'object' ? (record as Record<string, unknown>).id : undefined
    if (!isValidUuid(reportId)) return jsonResponse(req, { error: 'invalid_request' }, 400)

    const { data: rows, error: lookupError } = await deps.db
      .from('lab_reports')
      .select(ANALYZE_ROW_COLUMNS)
      .eq('id', reportId)
    if (lookupError) return fail('lookup_failed', 500)
    const row = (rows as Row[] | null)?.[0]
    // Someone else's report looks exactly like a missing one.
    if (!row || (patientId !== null && row.patient_id !== patientId)) return jsonResponse(req, { error: 'not_found' }, 404)
    if (!row.pdf_path) return jsonResponse(req, { status: 'skipped', reason: 'no_file' }, 422)

    const { data: file, error: downloadError } = await deps.db.storage.from(LAB_REPORTS_BUCKET).download(row.pdf_path)
    if (downloadError || !file) return fail('download_failed', 500)
    const bytes = new Uint8Array(await file.arrayBuffer())
    const sha256 = await sha256Hex(bytes)
    if (row.file_sha256 && row.file_sha256 !== sha256) return fail('file_hash_mismatch', 422, 'file_hash_mismatch')
    const mimeType = mimeTypeForPath(row.pdf_path)
    if (!mimeType) return fail('unsupported_file_type', 422, 'unsupported_file_type')
    if (bytes.byteLength > MAX_EXTRACT_BYTES) return fail('file_too_large', 422, 'file_too_large')
    if (!bytesMatchDeclaredType(bytes, mimeType)) return fail('invalid_file_content', 422, 'invalid_file_content')

    // Flag off: nothing is sent to a model and nothing is written.
    if (!deps.extractor) return fail('extractor_disabled', 501, 'analysis_unavailable')

    if (patientId !== null) {
      let budget: IntelligenceBudget
      try {
        budget = await (deps.consumeBudget ?? ((id) => consumeIntelligenceBudget(deps.db, id)))(patientId)
      } catch {
        return fail('rate_limit_unavailable', 503, 'rate_limit_check_unavailable')
      }
      if (!budget.allowed) {
        const res = jsonResponse(req, { error: 'rate_limited', retry_after_seconds: budget.retryAfterSeconds }, 429)
        for (const [k, v] of Object.entries(rateLimitedHeaders(budget.retryAfterSeconds))) res.headers.set(k, v)
        return res
      }
    }

    let extraction: RawExtraction
    try {
      extraction = await deps.extractor.extract(bytes, mimeType)
    } catch {
      return fail('analysis_failed', 502, 'analysis_failed')
    }

    const [{ data: mapRows, error: mapError }, account] = await Promise.all([
      deps.db.from('lab_analyte_loinc').select(ANALYTE_MAP_COLUMNS),
      loadAccountIdentity(deps.db, row.patient_id),
    ])
    if (mapError || !Array.isArray(mapRows) || account === null) return fail('reference_lookup_failed', 500)

    const now = (deps.now ?? (() => new Date()))()
    const threshold = deps.confidenceThreshold ?? DEFAULT_CONFIDENCE_THRESHOLD
    const report = normalizeExtraction(extraction, mapRows as AnalyteMapRow[], account, {
      threshold,
      today: now.toISOString().slice(0, 10),
    })

    const { error: fileError } = await deps.db.rpc('lab_pipeline_file_results', {
      p_report_id: row.id,
      p_report: reportPatch(report, extraction, sha256, deps.extractor.name, threshold, now),
      p_results: report.results.map(resultRow),
    })
    if (fileError) {
      return fileError.code === '23505'
        ? fail('duplicate_file', 409, 'duplicate')
        : fail('file_failed', 500)
    }

    const needsReview = report.results.filter((r) => r.status === 'needs_review').length
    return jsonResponse(req, {
      status: 'analyzed',
      extraction_status: report.status,
      identity_hold: report.identity.hold,
      results: report.results.length,
      needs_review: needsReview,
      // A held report may not be this patient's: none of its values go back.
      ...(report.identity.hold
        ? { message: IDENTITY_HOLD_MESSAGE }
        : { collected_on: report.collected_on, markers: report.results.map(displayMarker) }),
    })
  } catch {
    return fail('unexpected', 500)
  }
}

/** The account's name and DOB to compare a report against; null on error. */
async function loadAccountIdentity(db: SupabaseClient, patientId: string): Promise<{ name: string | null; dob: string | null } | null> {
  const [patient, meta] = await Promise.all([
    db.from('patients').select('display_name').eq('id', patientId),
    db.from('patient_roster_meta').select('birth_date').eq('patient_id', patientId),
  ])
  if (patient.error || meta.error) return null
  const name = (patient.data as { display_name: string | null }[] | null)?.[0]?.display_name ?? null
  const dob = (meta.data as { birth_date: string | null }[] | null)?.[0]?.birth_date ?? null
  return { name, dob }
}

function rangeText(r: NormalizedResult): string {
  if (r.range_low !== null && r.range_high !== null) return `${r.range_low}-${r.range_high}`
  if (r.range_high !== null) return `<${r.range_high}`
  if (r.range_low !== null) return `>${r.range_low}`
  return '--'
}

function displayStatus(r: NormalizedResult): string {
  switch (r.status) {
    case 'needs_review': return 'Needs review'
    case 'no_range': return 'No range'
    case 'within_range': return 'Normal'
    case 'outside_range': return r.range_low !== null && r.value !== null && r.value < r.range_low ? 'Low' : 'High'
  }
}

/** A result in the app's existing marker shape (lab_reports.data.markers). */
export function displayMarker(r: NormalizedResult): Record<string, unknown> {
  return {
    name: r.analyte_label,
    value: r.value === null ? r.reported_value : `${r.value_comparator ?? ''}${r.value}`,
    unit: r.unit ?? '',
    range: rangeText(r),
    status: displayStatus(r),
    category: 'General',
    insight: '',
    analyte_key: r.analyte_key,
    loinc: r.loinc,
    needs_review: r.status === 'needs_review',
    reported_value: r.reported_value,
    reported_unit: r.reported_unit,
  }
}

function resultRow(r: NormalizedResult): Record<string, unknown> {
  return {
    analyte_key: r.analyte_key,
    analyte_label: r.analyte_label,
    loinc: r.loinc,
    is_unmapped: r.is_unmapped,
    value: r.value,
    value_comparator: r.value_comparator,
    unit: r.unit,
    status: r.status,
    range_low: r.range_low,
    range_high: r.range_high,
    reported_name: r.reported_name,
    reported_value: r.reported_value,
    reported_unit: r.reported_unit,
    conversion_kind: r.conversion_kind,
    conversion_factor: r.conversion_factor,
    reference_range_text: r.reference_range_text,
    field_confidence: r.field_confidence,
    confidence: r.confidence,
    review_reasons: r.review_reasons,
  }
}

/** p_report for lab_pipeline_file_results(). */
export function reportPatch(
  report: NormalizedReport,
  extraction: RawExtraction,
  sha256: string,
  extractor: string,
  threshold: number,
  now: Date,
): Record<string, unknown> {
  const needsReview = report.results.filter((r) => r.status === 'needs_review').length
  return {
    file_sha256: sha256,
    extraction_status: report.status,
    identity_hold: report.identity.hold,
    collected_on: report.collected_on,
    lab_name: report.lab_name,
    data: {
      ...(report.collected_on ? { date: report.collected_on } : {}),
      ...(report.lab_name ? { lab_name: report.lab_name } : {}),
      // Kept even when held: the patient app's list hides held reports, and
      // clearing a hold must not lose the results.
      markers: report.results.map(displayMarker),
      summary: report.identity.hold
        ? 'On hold: the name or date of birth on this report does not match the account.'
        : `${report.results.length} results extracted${needsReview ? `, ${needsReview} need review` : ''}.`,
      analyzed_at: now.toISOString(),
      extraction: {
        extractor,
        confidence_threshold: threshold,
        status: report.status,
        report_reasons: report.report_reasons,
        field_confidence: report.field_confidence,
        // As printed, so staff can resolve a hold.
        printed_identity: { name: extraction.patient_name ?? null, dob: extraction.patient_dob ?? null },
        identity: { name: report.identity.name, dob: report.identity.dob, reasons: report.identity.reasons },
      },
    },
  }
}
