// APP-05: the AI lab-report extractor (server side). Reads the report file
// itself (PDF or image, sent inline) with Gemini's structured-output API and
// returns the text exactly as printed plus a confidence per field. It never
// converts, maps or interprets - labNormalize.ts does that, deterministically.
//
// Behind a flag: the extractor exists only when LAB_AI_EXTRACTION_ENABLED is
// exactly "true" (default OFF). With it off, analyze-lab-report answers 501
// analysis_unavailable and files nothing. No BAA is in place yet, so it may be
// switched on only where every report is fictional (local/dev/staging).
//
// No Deno/npm imports (fetch is injected), so it is typecheckable and testable
// from both runtimes.

import type { FieldConfidence, RawExtraction, RawResult } from './labNormalize.ts'

export const LAB_AI_FLAG = 'LAB_AI_EXTRACTION_ENABLED'
export const DEFAULT_LAB_MODEL = 'gemini-3.5-flash'
/** Inline request limit is ~20 MB of base64; keep well under it. */
export const MAX_EXTRACT_BYTES = 14 * 1024 * 1024
/** Bound on the provider call. A hung socket must not keep the function open. */
export const LAB_EXTRACT_TIMEOUT_MS = 20_000
export const MAX_RESULTS = 300

export interface LabExtractor {
  /** Model id, recorded with each filed report. */
  name: string
  extract(file: Uint8Array, mimeType: string): Promise<RawExtraction>
}

type Env = { get(key: string): string | undefined }
type Fetch = (input: string, init: RequestInit) => Promise<Response>

/** The configured extractor, or null when the flag is off or no key is set. */
export function labExtractorFromEnv(env: Env, fetchImpl: Fetch): LabExtractor | null {
  if (env.get(LAB_AI_FLAG) !== 'true') return null
  const apiKey = env.get('GEMINI_API_KEY') ?? ''
  if (!apiKey) return null
  const model = env.get('LAB_EXTRACTION_MODEL') || DEFAULT_LAB_MODEL
  return geminiLabExtractor({ apiKey, model, fetch: fetchImpl })
}

export const EXTRACTION_PROMPT = `You read clinical laboratory reports.
Return ONLY the JSON described by the schema. Rules:
- Copy every value, unit and reference range EXACTLY as printed. Never convert units, never round, never compute.
- One entry per test result row. Use the test name exactly as printed.
- "value" is the result only (e.g. "5.5", "<0.3"), without the unit or flag letters.
- If a field is not printed, return null. Never guess or infer a missing field.
- patient_name and patient_dob: the patient name and date of birth exactly as printed on the report.
- collection_date: the specimen collection date as printed (not the report or print date).
- lab_name: the performing laboratory's name as printed.
- confidence: for every field, a number from 0 to 1 for how certain you are that you read it correctly (legibility, alignment of the row). Use below 0.5 when the text is smudged, cut off or the row alignment is unclear.`

const CONF = (fields: string[]) => ({
  type: 'OBJECT',
  properties: Object.fromEntries(fields.map((f) => [f, { type: 'NUMBER' }])),
  required: fields,
})
const STR = { type: 'STRING', nullable: true }

export const EXTRACTION_SCHEMA = {
  type: 'OBJECT',
  properties: {
    patient_name: STR,
    patient_dob: STR,
    collection_date: STR,
    lab_name: STR,
    confidence: CONF(['patient_name', 'patient_dob', 'collection_date', 'lab_name']),
    results: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          analyte: { type: 'STRING' },
          value: { type: 'STRING' },
          unit: STR,
          reference_range: STR,
          confidence: CONF(['analyte', 'value', 'unit', 'reference_range']),
        },
        required: ['analyte', 'value', 'confidence'],
      },
    },
  },
  required: ['confidence', 'results'],
}

function base64(bytes: Uint8Array): string {
  let s = ''
  for (let i = 0; i < bytes.length; i += 0x8000) {
    s += String.fromCharCode(...bytes.subarray(i, i + 0x8000))
  }
  return btoa(s)
}

function text(v: unknown, max: number): string | null {
  if (v === null || v === undefined) return null
  const s = String(v).trim()
  return s === '' ? null : s.slice(0, max)
}

function confidence(v: unknown, fields: string[]): FieldConfidence {
  const src = v && typeof v === 'object' ? (v as Record<string, unknown>) : {}
  const out: FieldConfidence = {}
  for (const f of fields) {
    const n = Number(src[f])
    if (Number.isFinite(n)) out[f] = Math.min(1, Math.max(0, n))
  }
  return out
}

/** Coerces the model's JSON into a RawExtraction (lengths capped, junk dropped). */
export function sanitizeExtraction(json: unknown): RawExtraction {
  if (!json || typeof json !== 'object' || Array.isArray(json)) throw new Error('extraction: not an object')
  const o = json as Record<string, unknown>
  if (!Array.isArray(o.results)) throw new Error('extraction: no results array')
  const results: RawResult[] = []
  for (const item of o.results.slice(0, MAX_RESULTS)) {
    if (!item || typeof item !== 'object') continue
    const r = item as Record<string, unknown>
    const analyte = text(r.analyte, 200)
    const value = text(r.value, 64)
    if (!analyte || value === null) continue
    results.push({
      analyte,
      value,
      unit: text(r.unit, 32),
      reference_range: text(r.reference_range, 64),
      confidence: confidence(r.confidence, ['analyte', 'value', 'unit', 'reference_range']),
    })
  }
  return {
    patient_name: text(o.patient_name, 200),
    patient_dob: text(o.patient_dob, 32),
    collection_date: text(o.collection_date, 32),
    lab_name: text(o.lab_name, 200),
    confidence: confidence(o.confidence, ['patient_name', 'patient_dob', 'collection_date', 'lab_name']),
    results,
  }
}

export function geminiLabExtractor(opts: { apiKey: string; model: string; fetch: Fetch; timeoutMs?: number }): LabExtractor {
  return {
    name: opts.model,
    async extract(file, mimeType) {
      if (file.byteLength > MAX_EXTRACT_BYTES) throw new Error('extraction: file too large')
      const controller = new AbortController()
      const timer = setTimeout(() => controller.abort(), opts.timeoutMs ?? LAB_EXTRACT_TIMEOUT_MS)
      let res: Response
      try {
        res = await opts.fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(opts.model)}:generateContent`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'x-goog-api-key': opts.apiKey },
            body: JSON.stringify({
              systemInstruction: { parts: [{ text: EXTRACTION_PROMPT }] },
              contents: [{
                role: 'user',
                parts: [{ inlineData: { mimeType, data: base64(file) } }, { text: 'Extract this lab report.' }],
              }],
              generationConfig: { temperature: 0, responseMimeType: 'application/json', responseSchema: EXTRACTION_SCHEMA },
            }),
            signal: controller.signal,
          },
        )
      } catch (e) {
        const name = e instanceof Error ? e.name : ''
        if (name === 'AbortError' || name === 'TimeoutError') throw new Error('extraction: timeout')
        throw e
      } finally {
        clearTimeout(timer)
      }
      // Status only: the provider's error body is never read into logs.
      if (!res.ok) throw new Error(`extraction: provider status ${res.status}`)
      const body = await res.json() as { candidates?: { content?: { parts?: { text?: string }[] } }[] }
      const out = body.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? ''
      return sanitizeExtraction(JSON.parse(out))
    },
  }
}

export function mimeTypeForPath(path: string): string | null {
  const ext = path.slice(path.lastIndexOf('.') + 1).toLowerCase()
  return ({ pdf: 'application/pdf', jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', heic: 'image/heic', webp: 'image/webp' } as Record<string, string>)[ext] ?? null
}
