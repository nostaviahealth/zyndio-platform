// @vitest-environment jsdom
// TC-030 (19): the Biological Age vault page crashed for the QA patient with
// "Cannot read properties of undefined (reading 'toFixed')". The old code read
// `panelMetadata.bioAge` / `.paceOfAging` and called `.toFixed()` on them
// unconditionally; a report whose metadata is missing those fields (or whose
// panelMetadata is absent entirely) blows up at render.
//
// Fail-first: rendering with a partial panelMetadata (no biologicalAge /
// paceOfAging) throws the toFixed TypeError on the old component. The new
// component is null-safe and shows an empty/partial-data state instead.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

// A report with metadata present but the core epigenetic metrics missing -
// mirrors a QA/real panel that hasn't been fully processed.
vi.mock('../../constants', () => ({
  METHYLATION_REPORT: {
    id: 'meth-missing',
    date: '2026-06-01',
    title: 'Epigenetic Report',
    summary: '',
    reportType: 'methylation',
    providerName: 'TruDiagnostic',
    aiInterpretation: '',
    panelMetadata: {}, // no biologicalAge, chronologicalAge, paceOfAging, clockScores
    markers: [],
  },
}));

import BiologicalAgeDetail from '../../pages/panels/BiologicalAgeDetail';

describe('TC-030 19: BiologicalAgeDetail with missing metadata', () => {
  it('renders without crashing on undefined.toFixed and shows a pending state', () => {
    expect(() =>
      render(
        <MemoryRouter>
          <BiologicalAgeDetail />
        </MemoryRouter>
      )
    ).not.toThrow();

    expect(screen.getByText('Biological Age')).toBeInTheDocument();
    expect(screen.getByText(/pending/i)).toBeInTheDocument();
  });
});
