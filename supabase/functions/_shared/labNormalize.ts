// APP-05: turns what the extractor read off a lab report into lab_results
// rows - LOINC mapping (from the reviewed table), US canonical units, printed
// reference ranges, plausibility limits, per-field confidence - plus the
// report-level identity check.
//
// Pure functions, no Deno/npm imports: the root vitest suite
// (tests/lab-pipeline/*) covers every conversion factor and the golden
// fixtures (tests/fixtures/labs/*) through this module.
//
// Rules that are easy to get wrong:
//   * A result is never dropped, guessed or "corrected". Anything doubtful is
//     stored as reported and marked needs_review with a reason code.
//   * The original value, unit and the conversion used are always kept.
//   * Unknown analytes are stored as unmapped (no LOINC, is_unmapped).

import { catalogAnalyte, type CatalogAnalyte, type ConversionKind } from './labCatalog.ts'

export const DEFAULT_CONFIDENCE_THRESHOLD = 0.85

/** One row of public.lab_analyte_loinc (the reviewed mapping). */
export interface AnalyteMapRow {
  analyte_key: string
  loinc: string
  aliases: string[]
}

/** A per-field confidence score, 0..1, from the extractor. */
export type FieldConfidence = Record<string, number>

/** One result as the extractor read it (all text, exactly as printed). */
export interface RawResult {
  analyte: string
  value: string
  unit?: string | null
  reference_range?: string | null
  confidence?: FieldConfidence
}

/** What the extractor read off one report. */
export interface RawExtraction {
  patient_name?: string | null
  patient_dob?: string | null
  collection_date?: string | null
  lab_name?: string | null
  confidence?: FieldConfidence
  results: RawResult[]
}

export type ResultStatus = 'within_range' | 'outside_range' | 'needs_review' | 'no_range'

export interface NormalizedResult {
  analyte_key: string
  analyte_label: string
  loinc: string | null
  is_unmapped: boolean
  reported_name: string
  reported_value: string
  reported_unit: string | null
  value: number | null
  value_comparator: '<' | '<=' | '>' | '>=' | null
  unit: string | null
  conversion_kind: ConversionKind | 'none' | null
  conversion_factor: number | null
  reference_range_text: string | null
  range_low: number | null
  range_high: number | null
  field_confidence: FieldConfidence
  confidence: number
  status: ResultStatus
  review_reasons: string[]
}

// ---------------------------------------------------------------------------
// Text helpers
// ---------------------------------------------------------------------------

function stripAccents(s: string): string {
  return s.normalize('NFKD').replace(/[̀-ͯ]/g, '')
}

/** Analyte names and aliases compare on this form. */
export function analyteNameKey(name: string): string {
  return stripAccents(name).toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim()
}

/**
 * Units compare on this form: case-folded, no spaces, micro sign / Greek mu /
 * "mc" all read as "u", superscript two as "2". "µmol/L", "umol/l" and
 * "mcmol/L" are the same unit; "mL/min/1.73 m²" is "ml/min/1.73m2".
 */
export function unitKey(unit: string): string {
  return unit
    .normalize('NFKC')
    .replace(/[µμ]/g, 'u')
    .replace(/\s+/g, '')
    .toLowerCase()
    .replace(/^mc(?=[a-z])/, 'u')
    .replace(/\/mc(?=[a-z])/, '/u')
    .replace(/^percent$/, '%')
}

function sameUnit(a: string, b: string): boolean {
  return unitKey(a) === unitKey(b)
}

function round(value: number, decimals: number): number {
  const f = 10 ** decimals
  return Math.round((value + Number.EPSILON) * f) / f
}

// ---------------------------------------------------------------------------
// Values and ranges
// ---------------------------------------------------------------------------

export interface ParsedValue {
  value: number
  comparator: NormalizedResult['value_comparator']
  ambiguous: boolean
}

function parseNumber(text: string): { value: number; ambiguous: boolean } | null {
  let t = text.trim()
  let ambiguous = false
  if (t.includes(',') && t.includes('.')) {
    t = t.replace(/,/g, '')
  } else if (t.includes(',')) {
    // "5,5" is a decimal comma; "1,234" could be either - read as thousands
    // and flag it.
    if (/^\d{1,3}(,\d{3})+$/.test(t)) {
      ambiguous = true
      t = t.replace(/,/g, '')
    } else {
      t = t.replace(',', '.')
    }
  }
  if (!/^[-+]?(\d+(\.\d*)?|\.\d+)$/.test(t)) return null
  const value = Number(t)
  return Number.isFinite(value) ? { value, ambiguous } : null
}

/** "5.5", "<0.3", "≥ 90", "6,2", "5.5 H" (trailing flag letters dropped). */
export function parseReportedValue(text: string): ParsedValue | null {
  const m = text
    .trim()
    .replace(/≤/g, '<=')
    .replace(/≥/g, '>=')
    .match(/^(<=|>=|<|>)?\s*([-+]?[\d.,]+)\s*(?:\(?(?:H|L|HH|LL|High|Low|A|\*)\)?)?$/i)
  if (!m) return null
  const n = parseNumber(m[2])
  if (!n) return null
  return { value: n.value, comparator: (m[1] as ParsedValue['comparator']) ?? null, ambiguous: n.ambiguous }
}

/** "3.5-5.0", "3.5 – 5.0", "<5.7", "≥40", "> 40". Bounds in reported units. */
export function parseReferenceRange(text: string): { low: number | null; high: number | null } | null {
  const t = text.trim().replace(/≤/g, '<=').replace(/≥/g, '>=').replace(/[–—]/g, '-')
  const between = t.match(/^([\d.,]+)\s*(?:-|to)\s*([\d.,]+)$/i)
  if (between) {
    const low = parseNumber(between[1])
    const high = parseNumber(between[2])
    if (!low || !high || low.value > high.value) return null
    return { low: low.value, high: high.value }
  }
  const bound = t.match(/^(<=|>=|<|>)\s*([\d.,]+)$/)
  if (bound) {
    const n = parseNumber(bound[2])
    if (!n) return null
    return bound[1].startsWith('<') ? { low: null, high: n.value } : { low: n.value, high: null }
  }
  return null
}

// ---------------------------------------------------------------------------
// Unit conversion
// ---------------------------------------------------------------------------

export interface Conversion {
  value: number
  unit: string
  kind: ConversionKind | 'none'
  factor: number
}

/** Raw (unrounded) conversion to the canonical unit; null = not convertible. */
export function convertToCanonical(analyte: CatalogAnalyte, value: number, unit: string): Conversion | null {
  if (analyte.neverConvert) {
    // Stored exactly as reported, in whichever unit family it came in.
    const known = [analyte.canonicalUnit, ...Object.keys(analyte.loincByUnit ?? {})]
    const u = known.find((k) => sameUnit(k, unit))
    return u ? { value, unit: u, kind: 'none', factor: 1 } : null
  }
  if (sameUnit(unit, analyte.canonicalUnit) || analyte.sameAs.some((s) => sameUnit(s, unit))) {
    return { value, unit: analyte.canonicalUnit, kind: 'none', factor: 1 }
  }
  const c = analyte.conversions.find((x) => sameUnit(x.from, unit))
  if (!c) return null
  const converted = c.kind === 'multiply'
    ? value * c.factor
    : c.kind === 'divide'
      ? value / c.factor
      : value / c.factor + 2.15
  return { value: converted, unit: analyte.canonicalUnit, kind: c.kind, factor: c.factor }
}

// ---------------------------------------------------------------------------
// Mapping
// ---------------------------------------------------------------------------

export function buildAliasIndex(rows: AnalyteMapRow[]): Map<string, AnalyteMapRow> {
  const index = new Map<string, AnalyteMapRow>()
  for (const row of rows) {
    for (const alias of [row.analyte_key, ...row.aliases]) {
      const k = analyteNameKey(alias)
      if (k) index.set(k, row)
    }
  }
  return index
}

function unmappedKey(name: string): string {
  const slug = analyteNameKey(name).replace(/ /g, '_').slice(0, 80)
  return `unmapped:${slug || 'unnamed'}`
}

function clampConfidence(v: unknown): number {
  return typeof v === 'number' && Number.isFinite(v) ? Math.min(1, Math.max(0, v)) : 0
}

const RESULT_CONFIDENCE_FIELDS = ['analyte', 'value', 'unit', 'reference_range'] as const

// ---------------------------------------------------------------------------
// One result
// ---------------------------------------------------------------------------

export function normalizeResult(
  raw: RawResult,
  aliases: Map<string, AnalyteMapRow>,
  threshold = DEFAULT_CONFIDENCE_THRESHOLD,
): NormalizedResult {
  const reasons: string[] = []
  const reportedName = String(raw.analyte ?? '').trim()
  const reportedValue = String(raw.value ?? '').trim()
  const reportedUnit = raw.unit && String(raw.unit).trim() ? String(raw.unit).trim() : null
  const rangeText = raw.reference_range && String(raw.reference_range).trim() ? String(raw.reference_range).trim() : null

  // Confidence: every field gets a score. A field the extractor did not
  // score counts as 0. A field that is absent on the report (no unit, no
  // range) is not penalised for being absent.
  const fieldConfidence: FieldConfidence = {}
  for (const f of RESULT_CONFIDENCE_FIELDS) {
    if (f === 'unit' && reportedUnit === null) continue
    if (f === 'reference_range' && rangeText === null) continue
    fieldConfidence[f] = clampConfidence(raw.confidence?.[f])
    if (fieldConfidence[f] < threshold) reasons.push(`low_confidence:${f}`)
  }
  const confidence = Math.min(...Object.values(fieldConfidence))

  const mapRow = aliases.get(analyteNameKey(reportedName))
  const analyte = mapRow ? catalogAnalyte(mapRow.analyte_key) : undefined
  const parsed = parseReportedValue(reportedValue)
  if (!parsed) reasons.push('value_not_numeric')
  if (parsed?.ambiguous) reasons.push('ambiguous_number')
  if (parsed?.comparator) reasons.push('value_is_bound')

  const base = {
    reported_name: reportedName,
    reported_value: reportedValue,
    reported_unit: reportedUnit,
    value_comparator: parsed?.comparator ?? null,
    reference_range_text: rangeText,
    field_confidence: fieldConfidence,
    confidence,
  }

  if (!mapRow || !analyte) {
    // Unknown analyte: stored as unmapped, as reported, no conversion.
    const range = rangeText ? parseReferenceRange(rangeText) : null
    return finish({
      ...base,
      analyte_key: unmappedKey(reportedName),
      analyte_label: reportedName || 'Unnamed result',
      loinc: null,
      is_unmapped: true,
      value: parsed?.value ?? null,
      unit: reportedUnit,
      conversion_kind: null,
      conversion_factor: null,
      range_low: range?.low ?? null,
      range_high: range?.high ?? null,
    }, reasons)
  }

  let conversion: Conversion | null = null
  if (reportedUnit === null) {
    reasons.push('unit_missing')
  } else {
    conversion = convertToCanonical(analyte, parsed?.value ?? 0, reportedUnit)
    if (!conversion) reasons.push('unit_not_convertible')
  }

  const decimals = conversion && conversion.kind !== 'none' ? analyte.decimals : null
  const toCanonical = (v: number): number => {
    if (!conversion || !reportedUnit) return v
    const c = convertToCanonical(analyte, v, reportedUnit)!
    return decimals === null ? c.value : round(c.value, decimals + 1)
  }

  let value: number | null = parsed?.value ?? null
  if (value !== null && conversion) {
    value = decimals === null ? conversion.value : round(conversion.value, decimals)
  }

  let rangeLow: number | null = null
  let rangeHigh: number | null = null
  if (rangeText) {
    const range = parseReferenceRange(rangeText)
    if (!range) {
      reasons.push('range_not_parsed')
    } else {
      rangeLow = range.low === null ? null : toCanonical(range.low)
      rangeHigh = range.high === null ? null : toCanonical(range.high)
    }
  }

  // Plausibility only applies to a value in the canonical unit.
  if (value !== null && conversion && conversion.unit === analyte.canonicalUnit) {
    if (value < analyte.plausible.min || value > analyte.plausible.max) reasons.push('implausible_value')
  }

  const unit = conversion ? conversion.unit : reportedUnit
  const loinc = conversion && analyte.loincByUnit?.[conversion.unit] ? analyte.loincByUnit[conversion.unit] : mapRow.loinc

  return finish({
    ...base,
    analyte_key: analyte.key,
    analyte_label: analyte.label,
    loinc,
    is_unmapped: false,
    value,
    unit,
    conversion_kind: conversion ? conversion.kind : null,
    conversion_factor: conversion ? conversion.factor : null,
    range_low: rangeLow,
    range_high: rangeHigh,
  }, reasons)
}

function finish(
  r: Omit<NormalizedResult, 'status' | 'review_reasons'>,
  reasons: string[],
): NormalizedResult {
  let status: ResultStatus
  if (reasons.length > 0 || r.value === null) {
    status = 'needs_review'
    if (r.value === null && !reasons.includes('value_not_numeric')) reasons.push('value_not_numeric')
  } else if (r.range_low === null && r.range_high === null) {
    status = 'no_range'
  } else {
    const below = r.range_low !== null && r.value! < r.range_low
    const above = r.range_high !== null && r.value! > r.range_high
    status = below || above ? 'outside_range' : 'within_range'
  }
  return { ...r, status, review_reasons: reasons }
}

// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

/**
 * A printed date as an ISO date (YYYY-MM-DD), or null when it can't be read
 * without guessing. Accepts ISO; slash dates are US month-first (M/D/YYYY),
 * as US labs print them, unless the first number can only be a day (> 12).
 * Dotted or dashed D.M.YYYY dates are accepted only when unambiguous (one
 * number > 12, or both equal) - that style is usually day-first.
 */
export function parsePrintedDate(text: string | null | undefined): string | null {
  if (!text) return null
  const t = String(text).trim()
  let y: number, mo: number, d: number
  let m = t.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  if (m) {
    ;[y, mo, d] = [Number(m[1]), Number(m[2]), Number(m[3])]
  } else if ((m = t.match(/^(\d{1,2})([/.-])(\d{1,2})\2(\d{4})$/))) {
    const a = Number(m[1])
    const b = Number(m[3])
    y = Number(m[4])
    if (a > 12 && b <= 12) {
      ;[d, mo] = [a, b]
    } else if (m[2] === '/' || a === b || b > 12) {
      ;[mo, d] = [a, b]
    } else {
      return null
    }
  } else {
    return null
  }
  const date = new Date(Date.UTC(y, mo - 1, d))
  if (date.getUTCFullYear() !== y || date.getUTCMonth() !== mo - 1 || date.getUTCDate() !== d) return null
  return `${String(y).padStart(4, '0')}-${String(mo).padStart(2, '0')}-${String(d).padStart(2, '0')}`
}

// ---------------------------------------------------------------------------
// Identity check
// ---------------------------------------------------------------------------

export type IdentityFieldResult = 'match' | 'mismatch' | 'not_printed' | 'unreadable' | 'account_missing'

export interface IdentityCheck {
  hold: boolean
  name: IdentityFieldResult
  dob: IdentityFieldResult
  reasons: string[]
}

function nameTokens(name: string): string[] {
  return stripAccents(name).toLowerCase().replace(/[^a-z\s,'-]/g, ' ').replace(/[,'-]/g, ' ').split(/\s+/).filter(Boolean)
}

/**
 * Printed name vs the account name. Order and case don't matter ("RIVERA,
 * JORDAN" = "Jordan Rivera"), middle names are ignored, and the first name may
 * be an initial ("J RIVERA"). The account's first and last name must both be
 * there.
 */
export function namesMatch(printed: string, account: string): boolean {
  const p = nameTokens(printed)
  const a = nameTokens(account)
  if (p.length === 0 || a.length === 0) return false
  const first = a[0]
  const last = a[a.length - 1]
  if (a.length === 1) return p.includes(first)
  const hasLast = p.includes(last)
  const hasFirst = p.some((t) => t !== last && (t === first || (t.length === 1 && t === first[0])))
  return hasLast && hasFirst
}

/**
 * APP-05 identity check: a report whose printed name or date of birth does
 * not match the account is held (lab_reports.identity_hold) until reviewed.
 * Also held: an identity field the extractor could not read confidently, and
 * a report that prints nothing we could compare (no name and no DOB, or the
 * account has neither) - nothing then ties the report to this patient.
 */
export function checkIdentity(
  printed: { name?: string | null; dob?: string | null; confidence?: FieldConfidence },
  account: { name?: string | null; dob?: string | null },
  threshold = DEFAULT_CONFIDENCE_THRESHOLD,
): IdentityCheck {
  const reasons: string[] = []

  let name: IdentityFieldResult
  const printedName = printed.name?.trim() ?? ''
  if (!printedName) name = 'not_printed'
  else if (clampConfidence(printed.confidence?.patient_name) < threshold) name = 'unreadable'
  else if (!account.name?.trim()) name = 'account_missing'
  else name = namesMatch(printedName, account.name) ? 'match' : 'mismatch'

  let dob: IdentityFieldResult
  const printedDobText = printed.dob?.trim() ?? ''
  const printedDob = parsePrintedDate(printedDobText)
  if (!printedDobText) dob = 'not_printed'
  else if (!printedDob || clampConfidence(printed.confidence?.patient_dob) < threshold) dob = 'unreadable'
  else if (!account.dob) dob = 'account_missing'
  else dob = printedDob === account.dob ? 'match' : 'mismatch'

  if (name === 'mismatch') reasons.push('name_mismatch')
  if (dob === 'mismatch') reasons.push('dob_mismatch')
  if (name === 'unreadable') reasons.push('name_unreadable')
  if (dob === 'unreadable') reasons.push('dob_unreadable')
  if (name !== 'match' && name !== 'mismatch' && dob !== 'match' && dob !== 'mismatch') {
    reasons.push('nothing_to_compare')
  }
  return { hold: reasons.length > 0, name, dob, reasons }
}

// ---------------------------------------------------------------------------
// One report
// ---------------------------------------------------------------------------

export type ReportStatus = 'extracted' | 'needs_review' | 'identity_hold'

export interface NormalizedReport {
  status: ReportStatus
  identity: IdentityCheck
  collected_on: string | null
  lab_name: string | null
  report_reasons: string[]
  field_confidence: FieldConfidence
  results: NormalizedResult[]
}

export function normalizeExtraction(
  raw: RawExtraction,
  mapRows: AnalyteMapRow[],
  account: { name?: string | null; dob?: string | null },
  opts: { threshold?: number; today: string },
): NormalizedReport {
  const threshold = opts.threshold ?? DEFAULT_CONFIDENCE_THRESHOLD
  const aliases = buildAliasIndex(mapRows)
  const reasons: string[] = []

  const fieldConfidence: FieldConfidence = {}
  for (const f of ['patient_name', 'patient_dob', 'collection_date', 'lab_name']) {
    fieldConfidence[f] = clampConfidence(raw.confidence?.[f])
  }

  let collectedOn = parsePrintedDate(raw.collection_date)
  if (!raw.collection_date) reasons.push('collection_date_missing')
  else if (!collectedOn) reasons.push('collection_date_unreadable')
  else if (fieldConfidence.collection_date < threshold) reasons.push('low_confidence:collection_date')
  if (collectedOn && (collectedOn > opts.today || collectedOn < '1900-01-01')) {
    reasons.push('collection_date_implausible')
    collectedOn = null
  }

  const labName = raw.lab_name?.trim() || null
  if (labName && fieldConfidence.lab_name < threshold) reasons.push('low_confidence:lab_name')

  const identity = checkIdentity(
    { name: raw.patient_name, dob: raw.patient_dob, confidence: raw.confidence },
    account,
    threshold,
  )
  const results = (Array.isArray(raw.results) ? raw.results : [])
    .filter((r) => r && String(r.analyte ?? '').trim() !== '')
    .map((r) => normalizeResult(r, aliases, threshold))
  if (results.length === 0) reasons.push('no_results')

  const status: ReportStatus = identity.hold
    ? 'identity_hold'
    : reasons.length > 0 || results.some((r) => r.status === 'needs_review')
      ? 'needs_review'
      : 'extracted'

  return {
    status,
    identity,
    collected_on: collectedOn,
    lab_name: labName,
    report_reasons: reasons,
    field_confidence: fieldConfidence,
    results,
  }
}
