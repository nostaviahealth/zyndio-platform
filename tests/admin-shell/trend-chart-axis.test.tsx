// @vitest-environment jsdom
// TC-021 item 1 (Ava's TC-015 leftovers): the trend chart's y-axis labels read
// with one decimal ("5.0", not "5"), every grid tick is labelled, and the
// "Default range below 5.7%" legend line sits under the chart.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';

// jsdom has no layout, so ResponsiveContainer would measure 0×0 and draw
// nothing. Give the real recharts LineChart the 664×220 desktop size instead;
// everything else is the real chart.
vi.mock('recharts', async (importOriginal) => {
  const actual = await importOriginal<typeof import('recharts')>();
  return {
    ...actual,
    ResponsiveContainer: ({ children }: { children: React.ReactElement }) =>
      React.cloneElement(children, { width: 664, height: 220 } as Record<string, unknown>),
  };
});

import TrendChart from '../../components/clinical/TrendChart';
import { TrendPoint } from '../../lib/clinicalApi';

const HBA1C: TrendPoint[] = [
  { takenAt: '2026-04-02T00:00:00Z', value: 6.2, originalValue: null, unit: '%', status: 'baseline', rangeLow: null, rangeHigh: 5.7 },
  { takenAt: '2026-06-04T00:00:00Z', value: 5.9, originalValue: null, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7 },
  { takenAt: '2026-08-06T00:00:00Z', value: 5.7, originalValue: null, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7 },
  { takenAt: '2026-10-14T12:00:00Z', value: 5.5, originalValue: null, unit: '%', status: 'within_range', rangeLow: null, rangeHigh: 5.7 },
];

function yTickLabels(container: HTMLElement): string[] {
  return Array.from(container.querySelectorAll('.recharts-yAxis .recharts-cartesian-axis-tick-value')).map(
    (n) => n.textContent ?? ''
  );
}

describe('TrendChart (C59) y-axis and legend', () => {
  it.each(['light', 'dark'] as const)('labels every y tick with one decimal (%s)', (mode) => {
    const { container } = render(<TrendChart points={HBA1C} analyteLabel="HbA1c" unit="%" mode={mode} />);
    expect(yTickLabels(container)).toEqual(['5.0', '5.5', '6.0', '6.5']);
  });

  it('shows "Default range below 5.7%" under the chart', () => {
    const { container } = render(<TrendChart points={HBA1C} analyteLabel="HbA1c" unit="%" />);
    const caption = screen.getByText('Default range below 5.7%');
    const figcaption = container.querySelector('figcaption');
    expect(figcaption).toContainElement(caption);
    // Under the plot: the caption follows the chart surface in document order.
    const svg = container.querySelector('svg.recharts-surface');
    expect(svg).not.toBeNull();
    expect(svg!.compareDocumentPosition(figcaption!) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });
});
