// TC-021 item 12: per-patient rate limit for the intelligence function.
// A fixed budget per hour AND per day, enforced atomically in Postgres by
// public.consume_intelligence_budget (service-role only; pgTAP 725). Over
// budget the function answers 429 with Retry-After = seconds until the
// blocking window resets, before any call to the AI provider.
import type { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { sha256Hex } from './clientIp.ts'

export const INTELLIGENCE_HOURLY_LIMIT = 30
export const INTELLIGENCE_DAILY_LIMIT = 200

export type IntelligenceBudget = { allowed: true } | { allowed: false; retryAfterSeconds: number }

// Throws on any RPC error or unexpected shape: the caller answers 503 and
// never lets an unmetered request through to the provider.
export async function consumeIntelligenceBudget(admin: SupabaseClient, userId: string): Promise<IntelligenceBudget> {
  const { data, error } = await admin.rpc('consume_intelligence_budget', {
    p_key_hash: await sha256Hex(userId),
    p_hour_limit: INTELLIGENCE_HOURLY_LIMIT,
    p_day_limit: INTELLIGENCE_DAILY_LIMIT,
  })
  if (error) throw new Error('intelligence budget check failed')
  const row = (Array.isArray(data) ? data[0] : data) as { allowed?: unknown; retry_after_seconds?: unknown } | null
  if (!row || typeof row.allowed !== 'boolean') throw new Error('intelligence budget check: unexpected result')
  if (row.allowed) return { allowed: true }
  const seconds = Number(row.retry_after_seconds)
  return { allowed: false, retryAfterSeconds: Number.isFinite(seconds) && seconds >= 1 ? Math.ceil(seconds) : 1 }
}

// Retry-After must be readable by the web client too (CORS).
export function rateLimitedHeaders(retryAfterSeconds: number): Record<string, string> {
  return {
    'Retry-After': String(retryAfterSeconds),
    'Access-Control-Expose-Headers': 'Retry-After',
  }
}
