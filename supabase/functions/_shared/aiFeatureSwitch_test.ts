import { assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts'
import { featureFromIntelligencePath, isAiFeatureEnabled, type AiFeatureSwitchRow } from './aiFeatureSwitch.ts'

const ORG = '00000000-0000-0000-0000-00000000000a'

Deno.test('a missing switch row does not enable a feature', () => {
  assertEquals(isAiFeatureEnabled([], ORG, 'food_analysis'), false)
  assertEquals(isAiFeatureEnabled([], null, 'companion'), false)
})

Deno.test('an explicit enabled row allows the feature, and a clinic off wins over a global on', () => {
  const rows: AiFeatureSwitchRow[] = [
    { org_id: null, feature: 'food_analysis', enabled: true },
    { org_id: ORG, feature: 'food_analysis', enabled: false },
    { org_id: null, feature: 'companion', enabled: true },
  ]
  assertEquals(isAiFeatureEnabled(rows, ORG, 'food_analysis'), false)
  assertEquals(isAiFeatureEnabled(rows, ORG, 'companion'), true)
  assertEquals(isAiFeatureEnabled(rows, '00000000-0000-0000-0000-00000000000b', 'companion'), true)
})

Deno.test('a disabled wildcard blocks a feature that has its own enabled row', () => {
  const rows: AiFeatureSwitchRow[] = [
    { org_id: ORG, feature: 'companion', enabled: true },
    { org_id: null, feature: '*', enabled: false },
  ]
  assertEquals(isAiFeatureEnabled(rows, ORG, 'companion'), false)
})

Deno.test('the intelligence path chooses the feature and ignores any body label', () => {
  assertEquals(featureFromIntelligencePath('/functions/v1/intelligence'), 'companion')
  assertEquals(featureFromIntelligencePath('/functions/v1/intelligence/food-analysis'), 'food_analysis')
  assertEquals(featureFromIntelligencePath('/functions/v1/intelligence/coaching'), 'coaching')
  assertEquals(featureFromIntelligencePath('/functions/v1/intelligence/not-a-feature'), null)
})
