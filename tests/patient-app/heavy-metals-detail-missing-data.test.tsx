// @vitest-environment jsdom
// TC-030 (19): the Heavy Metals vault page crashed for the QA patient when the
// report arrived without markers - the old code called `report.markers.map` /
// `.filter` on an undefined array and parsed string values off undefined
// markers. Reading values must be null-safe, with an empty/partial-data state.
//
// Fail-first: rendering with `markers: undefined` throws
// "Cannot read properties of undefined (reading 'filter')" on the old
// component. The new component tolerates it and shows an empty state.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

vi.mock('../../constants', () => ({
  HEAVY_METALS_REPORT: {
    id: 'metals-missing',
    date: '2026-04-15',
    title: 'Heavy Metals Panel',
    summary: '',
    reportType: 'heavy_metals',
    providerName: "Doctor's Data",
    aiInterpretation: '',
    panelMetadata: {}, // no specimenType / provocationAgent
    markers: undefined, // not yet reported
  },
}));

import HeavyMetalsDetail from '../../pages/panels/HeavyMetalsDetail';

describe('TC-030 19: HeavyMetalsDetail with missing markers', () => {
  it('renders without crashing on undefined markers and shows an empty state', () => {
    expect(() =>
      render(
        <MemoryRouter>
          <HeavyMetalsDetail />
        </MemoryRouter>
      )
    ).not.toThrow();

    expect(screen.getByText('Heavy Metals')).toBeInTheDocument();
    expect(screen.getByText(/no metals reported yet/i)).toBeInTheDocument();
  });
});
