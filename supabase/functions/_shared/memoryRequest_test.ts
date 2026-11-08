import { assert, assertEquals, assertNotEquals, assertRejects, assertThrows } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import type { SupabaseClient } from 'npm:@supabase/supabase-js@2.118.0'
import { sha256Hex } from './clientIp.ts'
import {
  consumeMemoryBudget,
  embeddingRequestBody,
  extractEmbedding,
  MEMORY_CONTENT_MAX_CHARS,
  MEMORY_DAILY_LIMIT,
  MEMORY_HOURLY_LIMIT,
  MEMORY_MATCH_COUNT_MAX,
  MEMORY_QUERY_MAX_CHARS,
  parseEmbedRequest,
  parseSearchRequest,
} from './memoryRequest.ts'

Deno.test('parseEmbedRequest accepts a normal memory with defaults', () => {
  const r = parseEmbedRequest({ content: 'Fictional: likes rowing' })
  assert(r.ok)
  if (r.ok) {
    assertEquals(r.value.memoryType, 'conversation_summary')
    assertEquals(r.value.metadata, {})
  }
})

Deno.test('parseEmbedRequest rejects missing, oversized, and non-string content', () => {
  assertEquals(parseEmbedRequest({}).ok, false)
  assertEquals(parseEmbedRequest({ content: '   ' }).ok, false)
  assertEquals(parseEmbedRequest({ content: 42 }).ok, false)
  assertEquals(parseEmbedRequest({ content: 'x'.repeat(MEMORY_CONTENT_MAX_CHARS + 1) }).ok, false)
  assertEquals(parseEmbedRequest({ content: 'x'.repeat(MEMORY_CONTENT_MAX_CHARS) }).ok, true)
})

Deno.test('parseEmbedRequest rejects unknown memory_type and bad metadata', () => {
  assertEquals(parseEmbedRequest({ content: 'x', memory_type: 'admin_note' }).ok, false)
  assertEquals(parseEmbedRequest({ content: 'x', metadata: [1, 2] }).ok, false)
  assertEquals(parseEmbedRequest({ content: 'x', metadata: 'str' }).ok, false)
  assertEquals(parseEmbedRequest({ content: 'x', metadata: { blob: 'y'.repeat(5000) } }).ok, false)
  assertEquals(parseEmbedRequest({ content: 'x', memory_type: 'user_fact', metadata: { a: 1 } }).ok, true)
})

Deno.test('parseSearchRequest caps match_count and query length', () => {
  const r = parseSearchRequest({ query: 'sleep', match_count: 100000 })
  assert(r.ok)
  if (r.ok) assertEquals(r.value.matchCount, MEMORY_MATCH_COUNT_MAX)
  assertEquals(parseSearchRequest({ query: 'x'.repeat(MEMORY_QUERY_MAX_CHARS + 1) }).ok, false)
  assertEquals(parseSearchRequest({ query: 'x', match_count: 0 }).ok, false)
  assertEquals(parseSearchRequest({ query: 'x', match_count: 'lots' }).ok, false)
  assertEquals(parseSearchRequest({}).ok, false)
})

Deno.test('embeddingRequestBody pins 1536 dimensions to match the column', () => {
  assertEquals(embeddingRequestBody('hi').dimensions, 1536)
})

Deno.test('extractEmbedding accepts exactly 1536 finite numbers only', () => {
  const good = { data: [{ embedding: Array(1536).fill(0.01) }] }
  assertEquals(extractEmbedding(good).length, 1536)
  assertThrows(() => extractEmbedding({ data: [{ embedding: Array(3072).fill(0.01) }] }))
  assertThrows(() => extractEmbedding({ data: [] }))
  assertThrows(() => extractEmbedding(null))
  assertThrows(() => extractEmbedding({ data: [{ embedding: Array(1536).fill('x') }] }))
})

function fakeAdmin(result: { data?: unknown; error?: unknown }, seen: unknown[] = []): SupabaseClient {
  return {
    rpc: (name: string, args: unknown) => {
      seen.push({ name, args })
      return Promise.resolve(result)
    },
  } as unknown as SupabaseClient
}

Deno.test('consumeMemoryBudget uses its own key and limits, not the chat budget', async () => {
  const seen: Array<{ name: string; args: Record<string, unknown> }> = []
  const r = await consumeMemoryBudget(fakeAdmin({ data: [{ allowed: true, retry_after_seconds: 0 }] }, seen), 'u1')
  assertEquals(r, { allowed: true })
  assertEquals(seen[0].name, 'consume_intelligence_budget')
  assertEquals(seen[0].args.p_hour_limit, MEMORY_HOURLY_LIMIT)
  assertEquals(seen[0].args.p_day_limit, MEMORY_DAILY_LIMIT)
  assertNotEquals(seen[0].args.p_key_hash, await sha256Hex('u1'))
})

Deno.test('consumeMemoryBudget returns Retry-After when over budget', async () => {
  const r = await consumeMemoryBudget(fakeAdmin({ data: [{ allowed: false, retry_after_seconds: 120 }] }), 'u1')
  assertEquals(r, { allowed: false, retryAfterSeconds: 120 })
})

Deno.test('consumeMemoryBudget fails closed on RPC error or odd shape', async () => {
  await assertRejects(() => consumeMemoryBudget(fakeAdmin({ error: { message: 'boom' } }), 'u1'))
  await assertRejects(() => consumeMemoryBudget(fakeAdmin({ data: [{}] }), 'u1'))
})
