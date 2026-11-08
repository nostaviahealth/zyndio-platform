// Input limits and rate budget for the patient memory functions
// (embed-memory, search-memory). Both call the embedding provider on every
// request, so before this a signed-in caller could loop them without limit
// and with arbitrarily large text, running up provider cost.
//
// Budget: same atomic Postgres counter as intelligence
// (public.consume_intelligence_budget, pgTAP 725), keyed separately so memory
// traffic neither spends nor is blocked by the chat budget.
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import { sha256Hex } from './clientIp.ts'
import type { IntelligenceBudget } from './intelligenceRateLimit.ts'

export const MEMORY_HOURLY_LIMIT = 60
export const MEMORY_DAILY_LIMIT = 400

export const MEMORY_CONTENT_MAX_CHARS = 4000 // matches chat_memories_content_length_check
export const MEMORY_QUERY_MAX_CHARS = 1000
export const MEMORY_METADATA_MAX_BYTES = 2048 // under chat_memories_metadata_size_check
export const MEMORY_MATCH_COUNT_MAX = 10
export const MEMORY_EMBEDDING_DIMENSIONS = 1536 // chat_memories.embedding vector(1536)

export const MEMORY_TYPES = ['conversation_summary', 'user_fact', 'health_event'] as const
export type MemoryType = (typeof MEMORY_TYPES)[number]

export type Parsed<T> = { ok: true; value: T } | { ok: false; error: string }

export function parseEmbedRequest(
  body: Record<string, unknown>,
): Parsed<{ content: string; memoryType: MemoryType; metadata: Record<string, unknown> }> {
  const { content, memory_type, metadata } = body
  if (typeof content !== 'string' || content.trim().length === 0) {
    return { ok: false, error: 'content is required' }
  }
  if (content.length > MEMORY_CONTENT_MAX_CHARS) return { ok: false, error: 'content too long' }

  let memoryType: MemoryType = 'conversation_summary'
  if (memory_type !== undefined && memory_type !== null) {
    if (typeof memory_type !== 'string' || !(MEMORY_TYPES as readonly string[]).includes(memory_type)) {
      return { ok: false, error: 'invalid memory_type' }
    }
    memoryType = memory_type as MemoryType
  }

  let meta: Record<string, unknown> = {}
  if (metadata !== undefined && metadata !== null) {
    if (typeof metadata !== 'object' || Array.isArray(metadata)) {
      return { ok: false, error: 'metadata must be an object' }
    }
    if (new TextEncoder().encode(JSON.stringify(metadata)).length > MEMORY_METADATA_MAX_BYTES) {
      return { ok: false, error: 'metadata too large' }
    }
    meta = metadata as Record<string, unknown>
  }
  return { ok: true, value: { content, memoryType, metadata: meta } }
}

export function parseSearchRequest(
  body: Record<string, unknown>,
): Parsed<{ query: string; matchCount: number }> {
  const { query, match_count } = body
  if (typeof query !== 'string' || query.trim().length === 0) {
    return { ok: false, error: 'query is required' }
  }
  if (query.length > MEMORY_QUERY_MAX_CHARS) return { ok: false, error: 'query too long' }
  let matchCount = 5
  if (match_count !== undefined && match_count !== null) {
    const n = Number(match_count)
    if (!Number.isInteger(n) || n < 1) return { ok: false, error: 'invalid match_count' }
    matchCount = Math.min(n, MEMORY_MATCH_COUNT_MAX)
  }
  return { ok: true, value: { query, matchCount } }
}

/** Body for the OpenAI-compatible embeddings call, pinned to the column size. */
export function embeddingRequestBody(input: string): Record<string, unknown> {
  return { input, model: 'gemini-embedding-001', dimensions: MEMORY_EMBEDDING_DIMENSIONS }
}

/** Throws unless the provider returned exactly one 1536-d numeric vector. */
export function extractEmbedding(data: unknown): number[] {
  const vec = (data as { data?: Array<{ embedding?: unknown }> } | null)?.data?.[0]?.embedding
  if (
    !Array.isArray(vec) ||
    vec.length !== MEMORY_EMBEDDING_DIMENSIONS ||
    !vec.every((x) => typeof x === 'number' && Number.isFinite(x))
  ) {
    throw new Error('unexpected embedding shape')
  }
  return vec as number[]
}

// Throws on any RPC error or unexpected shape: the caller answers 503 and
// never lets an unmetered request through to the provider.
export async function consumeMemoryBudget(admin: SupabaseClient, userId: string): Promise<IntelligenceBudget> {
  const { data, error } = await admin.rpc('consume_intelligence_budget', {
    p_key_hash: await sha256Hex(`memory:${userId}`),
    p_hour_limit: MEMORY_HOURLY_LIMIT,
    p_day_limit: MEMORY_DAILY_LIMIT,
  })
  if (error) throw new Error('memory budget check failed')
  const row = (Array.isArray(data) ? data[0] : data) as { allowed?: unknown; retry_after_seconds?: unknown } | null
  if (!row || typeof row.allowed !== 'boolean') throw new Error('memory budget check: unexpected result')
  if (row.allowed) return { allowed: true }
  const seconds = Number(row.retry_after_seconds)
  return { allowed: false, retryAfterSeconds: Number.isFinite(seconds) && seconds >= 1 ? Math.ceil(seconds) : 1 }
}
