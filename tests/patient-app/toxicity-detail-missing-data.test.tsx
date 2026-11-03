// @vitest-environment jsdom
// TC-030 (19): the Toxicity vault page crashed for the QA patient when the
// report arrived without markers - the old code called `report.markers.map` /
// `.filter` on an undefined array. Value reads must be null-safe, with an
// empty/partial-data state.
//
// Fail-first: rendering with `markers: undefined` throws
// "Cannot read properties of undefined (reading 'map')" on the old component
// (the Detection Matrix). The new component tolerates it and shows an empty
// state.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

vi.mock('../../constants', () => ({
  TOXICITY_REPORT: {
    id: 'tox-missing',
    date: '2026-02-28',
    title: 'Toxic Chemical Profile',
    summary: '',
    reportType: 'toxicity',
    providerName: 'Great Plains Laboratory',
    aiInterpretation: '',
    panelMetadata: {}, // no toxinLoadScore
    markers: undefined, // not yet reported
  },
}));

import ToxicityDetail from '../../pages/panels/ToxicityDetail';

describe('TC-030 19: ToxicityDetail with missing markers', () => {
  it('renders without crashing on undefined markers and shows an empty state', () => {
    expect(() =>
      render(
        <MemoryRouter>
          <ToxicityDetail />
        </MemoryRouter>
      )
    ).not.toThrow();

    expect(screen.getByText('Toxicity Panel')).toBeInTheDocument();
    expect(screen.getByText(/no toxins reported yet/i)).toBeInTheDocument();
  });
});
