import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { isAiFeatureEnabled, normaliseAiFeature, type AiFeatureSwitchRow } from './aiFeatureSwitch.ts'

const CLINIC_A = '00000000-0000-0000-0000-00000000000a'
const CLINIC_B = '00000000-0000-0000-0000-00000000000b'

const row = (org_id: string | null, feature: string, enabled: boolean): AiFeatureSwitchRow =>
  ({ org_id, feature, enabled })

Deno.test('no rows: every feature is on', () => {
  assertEquals(isAiFeatureEnabled([], CLINIC_A, 'companion'), true)
})

Deno.test('a clinic switch turns off that feature for that clinic only', () => {
  const rows = [row(CLINIC_A, 'food_analysis', false)]
  assertEquals(isAiFeatureEnabled(rows, CLINIC_A, 'food_analysis'), false)
  assertEquals(isAiFeatureEnabled(rows, CLINIC_A, 'companion'), true)
  assertEquals(isAiFeatureEnabled(rows, CLINIC_B, 'food_analysis'), true)
})

Deno.test("'*' turns off every feature", () => {
  const rows = [row(CLINIC_A, '*', false)]
  for (const f of ['companion', 'food_analysis', 'lab_extraction', 'coaching', 'memory'] as const) {
    assertEquals(isAiFeatureEnabled(rows, CLINIC_A, f), false, f)
  }
})

Deno.test('an all-clinics switch applies everywhere, including patients with no clinic', () => {
  const rows = [row(null, 'memory', false)]
  assertEquals(isAiFeatureEnabled(rows, CLINIC_A, 'memory'), false)
  assertEquals(isAiFeatureEnabled(rows, null, 'memory'), false)
})

Deno.test("a clinic's own row overrides the all-clinics row for the same feature", () => {
  const rows = [row(null, 'coaching', false), row(CLINIC_A, 'coaching', true)]
  assertEquals(isAiFeatureEnabled(rows, CLINIC_A, 'coaching'), true)
  assertEquals(isAiFeatureEnabled(rows, CLINIC_B, 'coaching'), false)
})

Deno.test("a clinic re-enabling a feature does not beat an all-clinics '*' off", () => {
  const rows = [row(null, '*', false), row(CLINIC_A, 'companion', true)]
  assertEquals(isAiFeatureEnabled(rows, CLINIC_A, 'companion'), false)
})

Deno.test('unlabelled or unknown features count as companion', () => {
  assertEquals(normaliseAiFeature(undefined), 'companion')
  assertEquals(normaliseAiFeature('ads'), 'companion')
  assertEquals(normaliseAiFeature(42), 'companion')
  assertEquals(normaliseAiFeature('food_analysis'), 'food_analysis')
})
