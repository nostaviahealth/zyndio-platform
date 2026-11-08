import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import {
  buildProviderRequest,
  MAX_IMAGES,
  MAX_MESSAGES,
  MAX_TEXT_CHARS,
  MAX_TOKENS_CEILING,
  PROVIDER_MODEL,
  providerFailure,
} from './intelligenceProviderRequest.ts'

const chat = [
  { role: 'system', content: 'You are a health assistant.' },
  { role: 'user', content: 'Fictional: how did I sleep?' },
]

function ok(body: Record<string, unknown>) {
  const r = buildProviderRequest(body)
  if (!r.ok) throw new Error(`expected ok, got ${r.error}`)
  return r
}

Deno.test('a plain chat request becomes a pinned-model provider body', () => {
  const r = ok({ messages: chat, max_completion_tokens: 2048 })
  assertEquals(r.body.model, PROVIDER_MODEL)
  assertEquals(r.body.max_tokens, 2048)
  assertEquals(r.body.messages, chat)
  assertEquals(r.stream, false)
  assertEquals('stream' in r.body, false)
})

Deno.test('max_completion_tokens is capped, defaulted, and validated', () => {
  assertEquals(ok({ messages: chat, max_completion_tokens: 10_000_000 }).body.max_tokens, MAX_TOKENS_CEILING)
  assertEquals(ok({ messages: chat, max_completion_tokens: 16384 }).body.max_tokens, 16384)
  assertEquals(ok({ messages: chat }).body.max_tokens, 4096)
  assertEquals(buildProviderRequest({ messages: chat, max_completion_tokens: -1 }).ok, false)
  assertEquals(buildProviderRequest({ messages: chat, max_completion_tokens: 'lots' }).ok, false)
})

Deno.test('unknown top-level fields are dropped, not forwarded', () => {
  const r = ok({ messages: chat, model: 'some-expensive-model', temperature: 2, n: 50, patient_id: 'x' })
  assertEquals(Object.keys(r.body).sort(), ['max_tokens', 'messages', 'model'])
  assertEquals(r.body.model, PROVIDER_MODEL)
})

Deno.test('unknown message fields are dropped', () => {
  const r = ok({ messages: [{ role: 'user', content: 'hi', name: 'x', extra: { a: 1 } }] })
  assertEquals(r.body.messages, [{ role: 'user', content: 'hi' }])
})

Deno.test('messages must be a non-empty, bounded array of known roles', () => {
  assertEquals(buildProviderRequest({}), { ok: false, error: 'messages array is required' })
  assertEquals(buildProviderRequest({ messages: [] }).ok, false)
  assertEquals(buildProviderRequest({ messages: 'hi' }).ok, false)
  assertEquals(buildProviderRequest({ messages: [{ role: 'developer', content: 'x' }] }).ok, false)
  assertEquals(buildProviderRequest({ messages: [{ role: 'user' }] }).ok, false)
  const many = Array.from({ length: MAX_MESSAGES + 1 }, () => ({ role: 'user', content: 'x' }))
  assertEquals(buildProviderRequest({ messages: many }).ok, false)
})

Deno.test('total text is capped', () => {
  const big = [{ role: 'user', content: 'x'.repeat(MAX_TEXT_CHARS + 1) }]
  assertEquals(buildProviderRequest({ messages: big }).ok, false)
})

Deno.test('user images: base64 data URLs pass, count is capped, odd parts rejected', () => {
  const img = { type: 'image_url', image_url: { url: 'data:image/jpeg;base64,AAAA' } }
  const r = ok({ messages: [{ role: 'user', content: [{ type: 'text', text: 'read this' }, img] }] })
  assertEquals((r.body.messages as unknown[]).length, 1)
  const tooMany = [{ role: 'user', content: Array.from({ length: MAX_IMAGES + 1 }, () => img) }]
  assertEquals(buildProviderRequest({ messages: tooMany }).ok, false)
  const badUrl = [{ role: 'user', content: [{ type: 'image_url', image_url: { url: 'file:///etc/passwd' } }] }]
  assertEquals(buildProviderRequest({ messages: badUrl }).ok, false)
  const audio = [{ role: 'user', content: [{ type: 'input_audio', input_audio: {} }] }]
  assertEquals(buildProviderRequest({ messages: audio }).ok, false)
  const sysImage = [{ role: 'system', content: [img] }]
  assertEquals(buildProviderRequest({ messages: sysImage }).ok, false)
})

Deno.test('response_format allows json_object / text only', () => {
  assertEquals(ok({ messages: chat, response_format: { type: 'json_object' } }).body.response_format, { type: 'json_object' })
  assertEquals(buildProviderRequest({ messages: chat, response_format: { type: 'json_schema', json_schema: {} } }).ok, false)
  assertEquals(buildProviderRequest({ messages: chat, response_format: 'json' }).ok, false)
})

Deno.test('function tools pass through cleaned; tool_choice defaults to auto', () => {
  const tools = [{ type: 'function', function: { name: 'log_water', description: 'Log water', parameters: { type: 'object' }, x: 1 } }]
  const r = ok({ messages: chat, tools })
  assertEquals(r.body.tools, [{ type: 'function', function: { name: 'log_water', description: 'Log water', parameters: { type: 'object' } } }])
  assertEquals(r.body.tool_choice, 'auto')
  assertEquals(ok({ messages: chat, tools: [] }).body.tools, undefined)
  assertEquals(buildProviderRequest({ messages: chat, tools: [{ type: 'code_interpreter' }] }).ok, false)
  assertEquals(buildProviderRequest({ messages: chat, tools: [{ type: 'function', function: { name: 'bad name!' } }] }).ok, false)
  assertEquals(buildProviderRequest({ messages: chat, tools, tool_choice: { type: 'function', function: { name: 'other' } } }).ok, false)
  assertEquals(buildProviderRequest({ messages: chat, tools, tool_choice: 'whatever' }).ok, false)
})

Deno.test('assistant tool_calls and tool results are kept in shape', () => {
  const r = ok({
    messages: [
      { role: 'user', content: 'log 1 glass' },
      { role: 'assistant', content: null, tool_calls: [{ id: 'c1', type: 'function', function: { name: 'log_water', arguments: '{}' } }] },
      { role: 'tool', tool_call_id: 'c1', content: 'done' },
    ],
  })
  assertEquals((r.body.messages as unknown[]).length, 3)
  assertEquals(buildProviderRequest({ messages: [{ role: 'tool', content: 'done' }] }).ok, false)
})

Deno.test('stream is only on when explicitly true', () => {
  assert(ok({ messages: chat, stream: true }).stream)
  assertEquals(ok({ messages: chat, stream: 'yes' }).stream, false)
})

Deno.test('providerFailure never carries provider text', () => {
  assertEquals(providerFailure(400), { status: 502, body: { error: 'ai_provider_error' } })
  assertEquals(providerFailure(500), { status: 502, body: { error: 'ai_provider_error' } })
  assertEquals(providerFailure(429), { status: 503, body: { error: 'ai_provider_busy' } })
})
