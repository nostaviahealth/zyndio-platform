// Builds the request the intelligence function sends to the model provider
// from the patient's body - an allowlist, not a pass-through.
//
// Before this, `messages`, `tools` and `response_format` went to Gemini as
// sent and `max_completion_tokens` had no ceiling, so one rate-limited call
// could still ask for an unbounded completion, stuff arbitrary structures into
// the provider request, or attach any number of images. Everything here is
// sized for what the apps actually send (flutter_app/lib/services/
// azure_openai_service.dart, pages/Chat.tsx): chat turns, JSON mode, function
// tools, and up to a handful of base64 photos / lab-report pages.

export const PROVIDER_MODEL = 'gemini-3.5-flash'

export const DEFAULT_MAX_TOKENS = 4096
export const MAX_TOKENS_CEILING = 16384 // lab-report extraction asks for this much
export const MAX_MESSAGES = 100
export const MAX_TEXT_CHARS = 200_000 // all text parts, all messages
export const MAX_IMAGES = 12
export const MAX_IMAGE_URL_CHARS = 12_000_000 // ~9 MB of base64 per image
export const MAX_TOOLS = 32
export const MAX_TOOLS_JSON_BYTES = 64 * 1024
export const MAX_TOOL_CALLS_PER_MESSAGE = 16

const ROLES = new Set(['system', 'user', 'assistant', 'tool'])
const FUNCTION_NAME = /^[A-Za-z0-9_-]{1,64}$/
const IMAGE_URL = /^(data:image\/(png|jpe?g|webp|gif|heic|heif);base64,[A-Za-z0-9+/=\s]+|https:\/\/\S+)$/

export type ProviderRequest =
  | { ok: true; body: Record<string, unknown>; stream: boolean }
  | { ok: false; error: string }

type Counters = { textChars: number; images: number }

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return v !== null && typeof v === 'object' && !Array.isArray(v)
}

function byteLength(v: unknown): number {
  return new TextEncoder().encode(JSON.stringify(v)).length
}

function cleanContent(content: unknown, counters: Counters): unknown | null {
  if (typeof content === 'string') {
    counters.textChars += content.length
    return content
  }
  if (!Array.isArray(content) || content.length === 0) return null
  const parts: unknown[] = []
  for (const part of content) {
    if (!isPlainObject(part)) return null
    if (part.type === 'text' && typeof part.text === 'string') {
      counters.textChars += part.text.length
      parts.push({ type: 'text', text: part.text })
    } else if (part.type === 'image_url' && isPlainObject(part.image_url) && typeof part.image_url.url === 'string') {
      const url = part.image_url.url
      if (url.length > MAX_IMAGE_URL_CHARS || !IMAGE_URL.test(url)) return null
      counters.images += 1
      parts.push({ type: 'image_url', image_url: { url } })
    } else {
      return null
    }
  }
  return parts
}

function cleanToolCalls(raw: unknown): unknown[] | null {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > MAX_TOOL_CALLS_PER_MESSAGE) return null
  const out: unknown[] = []
  for (const tc of raw) {
    if (!isPlainObject(tc) || typeof tc.id !== 'string' || tc.id.length > 128) return null
    const fn = tc.function
    if (!isPlainObject(fn) || typeof fn.name !== 'string' || !FUNCTION_NAME.test(fn.name)) return null
    if (typeof fn.arguments !== 'string' || fn.arguments.length > 32_000) return null
    out.push({ id: tc.id, type: 'function', function: { name: fn.name, arguments: fn.arguments } })
  }
  return out
}

function cleanMessages(raw: unknown, counters: Counters): unknown[] | null {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > MAX_MESSAGES) return null
  const out: unknown[] = []
  for (const m of raw) {
    if (!isPlainObject(m) || typeof m.role !== 'string' || !ROLES.has(m.role)) return null
    const msg: Record<string, unknown> = { role: m.role }
    const hasToolCalls = m.role === 'assistant' && m.tool_calls !== undefined && m.tool_calls !== null
    if (hasToolCalls) {
      const calls = cleanToolCalls(m.tool_calls)
      if (!calls) return null
      msg.tool_calls = calls
    }
    if (m.content === null || m.content === undefined) {
      if (!hasToolCalls) return null
      msg.content = null
    } else {
      // Images only ever come from the patient.
      if (m.role !== 'user' && typeof m.content !== 'string') return null
      const content = cleanContent(m.content, counters)
      if (content === null) return null
      msg.content = content
    }
    if (m.role === 'tool') {
      if (typeof m.tool_call_id !== 'string' || m.tool_call_id.length === 0 || m.tool_call_id.length > 128) return null
      msg.tool_call_id = m.tool_call_id
    }
    out.push(msg)
  }
  if (counters.textChars > MAX_TEXT_CHARS || counters.images > MAX_IMAGES) return null
  return out
}

function cleanTools(raw: unknown): unknown[] | null {
  if (!Array.isArray(raw) || raw.length > MAX_TOOLS) return null
  const out: unknown[] = []
  for (const t of raw) {
    if (!isPlainObject(t) || t.type !== 'function' || !isPlainObject(t.function)) return null
    const fn = t.function
    if (typeof fn.name !== 'string' || !FUNCTION_NAME.test(fn.name)) return null
    const clean: Record<string, unknown> = { name: fn.name }
    if (fn.description !== undefined) {
      if (typeof fn.description !== 'string') return null
      clean.description = fn.description
    }
    if (fn.parameters !== undefined) {
      if (!isPlainObject(fn.parameters)) return null
      clean.parameters = fn.parameters
    }
    out.push({ type: 'function', function: clean })
  }
  if (byteLength(out) > MAX_TOOLS_JSON_BYTES) return null
  return out
}

function cleanToolChoice(raw: unknown, toolNames: Set<string>): unknown | null {
  if (raw === undefined || raw === null) return 'auto'
  if (raw === 'auto' || raw === 'none' || raw === 'required') return raw
  if (isPlainObject(raw) && raw.type === 'function' && isPlainObject(raw.function) &&
      typeof raw.function.name === 'string' && toolNames.has(raw.function.name)) {
    return { type: 'function', function: { name: raw.function.name } }
  }
  return null
}

export function buildProviderRequest(body: Record<string, unknown>): ProviderRequest {
  // Same message as before for a missing array (tests/integration/intelligence-role.test.ts).
  if (!Array.isArray(body.messages)) return { ok: false, error: 'messages array is required' }
  const counters: Counters = { textChars: 0, images: 0 }
  const messages = cleanMessages(body.messages, counters)
  if (!messages) return { ok: false, error: 'invalid messages' }

  let maxTokens = DEFAULT_MAX_TOKENS
  if (body.max_completion_tokens !== undefined && body.max_completion_tokens !== null) {
    const n = Number(body.max_completion_tokens)
    if (!Number.isInteger(n) || n < 1) return { ok: false, error: 'invalid max_completion_tokens' }
    maxTokens = Math.min(n, MAX_TOKENS_CEILING)
  }

  const stream = body.stream === true
  const out: Record<string, unknown> = { model: PROVIDER_MODEL, messages, max_tokens: maxTokens }
  if (stream) out.stream = true

  if (body.response_format !== undefined && body.response_format !== null) {
    const rf = body.response_format
    if (!isPlainObject(rf) || (rf.type !== 'json_object' && rf.type !== 'text')) {
      return { ok: false, error: 'invalid response_format' }
    }
    out.response_format = { type: rf.type }
  }

  if (body.tools !== undefined && body.tools !== null) {
    const tools = cleanTools(body.tools)
    if (!tools) return { ok: false, error: 'invalid tools' }
    if (tools.length > 0) {
      const names = new Set(tools.map((t) => ((t as Record<string, Record<string, string>>).function.name)))
      const choice = cleanToolChoice(body.tool_choice, names)
      if (choice === null) return { ok: false, error: 'invalid tool_choice' }
      out.tools = tools
      out.tool_choice = choice
    }
  }

  return { ok: true, body: out, stream }
}

/**
 * What the patient sees when the provider call fails: a stable code and a
 * status that is ours, never the provider's message or raw body (which can
 * echo request content, quota/project details or internal identifiers).
 */
export function providerFailure(providerStatus: number): { status: number; body: { error: string } } {
  if (providerStatus === 429) return { status: 503, body: { error: 'ai_provider_busy' } }
  return { status: 502, body: { error: 'ai_provider_error' } }
}
