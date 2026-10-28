import { assert } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { padTimingTo } from './timingPad.ts'

Deno.test('padTimingTo waits up to the floor when the handler finished early', async () => {
  const start = Date.now()
  await padTimingTo(start, 60)
  const elapsed = Date.now() - start
  assert(elapsed >= 55, `expected to wait close to the 60ms floor, only waited ${elapsed}ms`)
})

Deno.test('padTimingTo is a no-op once the floor has already elapsed', async () => {
  const start = Date.now() - 1000
  const before = Date.now()
  await padTimingTo(start, 60)
  const elapsed = Date.now() - before
  assert(elapsed < 30, `expected an immediate return, took ${elapsed}ms`)
})
