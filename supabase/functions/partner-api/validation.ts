// Input rules for the partner API. The database re-checks the same limits
// (table checks in 20261104150000), these just give the partner a precise
// 400 instead of a generic one.
import { ApiError } from './errors.ts'
import { MAX_EMAIL_LENGTH, isValidEmail, normalizeEmail } from '../_shared/validation.ts'

export const SCOPES = ['patients:write', 'patients:read', 'webhooks:manage'] as const
export type Scope = (typeof SCOPES)[number]

export const EVENT_TYPES = ['patient.enrolled', 'patient.activated', 'patient.deactivated', 'consent.updated'] as const

const ZYNDIO_PATIENT_ID = /^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$/
const WEBHOOK_ENDPOINT_ID = /^whe_[0-9a-f]{24}$/
const E164 = /^\+[1-9][0-9]{6,14}$/
const IDEMPOTENCY_KEY = /^[\x21-\x7e]{1,255}$/
// Postgres timestamptz text, as the list RPCs return it in _sort.
const SORT_KEY = /^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(\.\d{1,6})?([+-]\d{2}(:?\d{2})?|Z)?$/

export const DEFAULT_PAGE_SIZE = 25
export const MAX_PAGE_SIZE = 100

export function isScope(value: string): value is Scope {
  return (SCOPES as readonly string[]).includes(value)
}

export function isZyndioPatientId(value: unknown): value is string {
  return typeof value === 'string' && ZYNDIO_PATIENT_ID.test(value)
}

export function isWebhookEndpointId(value: unknown): value is string {
  return typeof value === 'string' && WEBHOOK_ENDPOINT_ID.test(value)
}

export function isIdempotencyKey(value: unknown): value is string {
  return typeof value === 'string' && IDEMPOTENCY_KEY.test(value)
}

export function rejectUnknownFields(body: Record<string, unknown>, allowed: readonly string[]): void {
  for (const key of Object.keys(body)) {
    if (!allowed.includes(key)) throw new ApiError('invalid_request', `Unknown field: ${key}.`)
  }
}

export function requireZyndioPatientId(value: unknown, field = 'zyndio_patient_id'): string {
  if (!isZyndioPatientId(value)) {
    throw new ApiError('invalid_request', `${field} must be 1-128 characters: letters, digits, _ . : - (starting with a letter or digit).`)
  }
  return value
}

export function requireEmail(value: unknown): string {
  const email = normalizeEmail(value)
  if (!email || email.length > MAX_EMAIL_LENGTH || !isValidEmail(email)) {
    throw new ApiError('invalid_request', 'email must be a valid email address.')
  }
  return email
}

// Optional name: absent -> undefined, null -> null (clear), else 1-100 chars trimmed.
export function optionalName(value: unknown, field: string): string | null | undefined {
  if (value === undefined) return undefined
  if (value === null) return null
  if (typeof value !== 'string' || value.trim().length === 0 || value.trim().length > 100) {
    throw new ApiError('invalid_request', `${field} must be a string of 1-100 characters, or null.`)
  }
  return value.trim()
}

export function optionalPhone(value: unknown): string | null | undefined {
  if (value === undefined) return undefined
  if (value === null) return null
  if (typeof value !== 'string' || !E164.test(value.trim())) {
    throw new ApiError('invalid_request', 'phone must be in E.164 format, e.g. +15555550123, or null.')
  }
  return value.trim()
}

export function parseLimit(raw: string | null): number {
  if (raw === null) return DEFAULT_PAGE_SIZE
  if (!/^\d{1,3}$/.test(raw) || Number(raw) < 1 || Number(raw) > MAX_PAGE_SIZE) {
    throw new ApiError('invalid_request', `limit must be an integer from 1 to ${MAX_PAGE_SIZE}.`)
  }
  return Number(raw)
}

// Opaque cursor: base64url of {"s": <sort key>, "i": <public id>}.
export function encodeCursor(sort: string, id: string): string {
  const bytes = new TextEncoder().encode(JSON.stringify({ s: sort, i: id }))
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

export function decodeCursor(raw: string | null): { sort: string; id: string } | null {
  if (raw === null) return null
  try {
    if (raw.length > 512 || !/^[A-Za-z0-9_-]+$/.test(raw)) throw new Error('bad cursor')
    const b64 = raw.replace(/-/g, '+').replace(/_/g, '/')
    const text = new TextDecoder().decode(Uint8Array.from(atob(b64), (c) => c.charCodeAt(0)))
    const parsed = JSON.parse(text)
    if (typeof parsed?.s !== 'string' || typeof parsed?.i !== 'string' || !SORT_KEY.test(parsed.s)) {
      throw new Error('bad cursor')
    }
    return { sort: parsed.s, id: parsed.i }
  } catch {
    throw new ApiError('invalid_request', 'cursor is not valid; pass next_cursor from the previous page unchanged.')
  }
}
