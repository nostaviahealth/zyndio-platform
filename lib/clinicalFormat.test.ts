import { describe, it, expect } from 'vitest';
import { yAxisTicks } from './clinicalFormat';

// physician/components.md L13 + components.md L134: grid at 0.5 steps over
// the rounded domain. recharts never renders real SVG geometry under jsdom
// (see vitest.setup.ts), so the tick math is unit-tested directly here and
// TrendChart just passes the result through as an explicit `ticks` prop.
describe('yAxisTicks', () => {
  it('rounds HbA1c values (5.5-6.2, range high 5.7) out to 5-6.5 and ticks every 0.5', () => {
    expect(yAxisTicks([6.2, 5.7, 5.5, 5.7])).toEqual([5, 5.5, 6, 6.5]);
  });

  it('handles a tight cluster without collapsing to a single tick', () => {
    expect(yAxisTicks([98, 98])).toEqual([97.5, 98, 98.5]);
  });

  it('falls back to a default range with no values', () => {
    expect(yAxisTicks([])).toEqual([0, 1]);
  });
});
