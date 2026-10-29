import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts'
import { readIntelligenceBody } from './intelligenceBody.ts'

const req = (body: string) => new Request('http://local/intelligence', { method: 'POST', body })

Deno.test('intelligence body: a JSON object is accepted', async () => {
  assertEquals(await readIntelligenceBody(req('{"messages":[]}')), { ok: true, body: { messages: [] } })
})
for (const [label, raw] of [
  ['invalid JSON', '{"messages": ['],
  ['empty body', ''],
  ['null', 'null'],
  ['an array', '[]'],
  ['a string', '"hi"'],
  ['a number', '42'],
] as const) {
  Deno.test(`intelligence body: ${label} is rejected`, async () => {
    assertEquals(await readIntelligenceBody(req(raw)), { ok: false })
  })
}
