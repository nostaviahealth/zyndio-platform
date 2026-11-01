// @vitest-environment jsdom
// TC-026 (Henry's 1 Nov scope update): HealthJourneyPanel, on publishing the
// final protocol section, used to UPDATE `profiles.stage/is_protocol_published`
// by patient id. `profiles` is gone; the org-scoped clinical replacement is
// `patient_profiles` (data jsonb, staff RLS). Publishing must write there and
// never query `profiles`.
import React from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, act, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const tablesQueried = vi.hoisted(() => [] as string[]);
const journeyRow = vi.hoisted(() => ({
  id: 'journey-1',
  profile_id: 'fictional-patient-1',
  title: 'Health Journey',
  status: 'draft',
  phases: [
    {
      id: 'phase-1',
      phaseNumber: 1,
      status: 'active',
      durationWeeks: 8,
      goal: { type: 'longevity', description: 'Longevity phase', targetMetrics: [] },
      protocol: {
        lifestyle: { approved: true, published: true, lastUpdated: 'x' },
        diet: { approved: true, published: true, lastUpdated: 'x' },
        fitness: { approved: true, published: true, lastUpdated: 'x' },
        supplements: { approved: true, published: false, lastUpdated: 'x' },
        allApproved: true,
      },
    },
  ],
  created_at: '2026-11-01T00:00:00Z',
  updated_at: '2026-11-01T00:00:00Z',
}));

vi.mock('../../lib/supabase', () => {
  const from = (table: string) => {
    tablesQueried.push(table);
    const result =
      table === 'health_journeys' ? { data: journeyRow, error: null } : { data: null, error: null };
    const builder: Record<string, unknown> = {};
    for (const m of ['select', 'eq', 'order', 'limit', 'insert', 'update', 'delete', 'upsert']) {
      builder[m] = () => builder;
    }
    builder.single = () => Promise.resolve(result);
    builder.maybeSingle = () => Promise.resolve(result);
    builder.then = (resolve: (v: unknown) => unknown) => Promise.resolve(result).then(resolve);
    return builder;
  };
  return { supabase: { from } };
});

import HealthJourneyPanel from '../../pages/admin/HealthJourneyPanel';

beforeEach(() => {
  tablesQueried.length = 0;
  vi.spyOn(console, 'error').mockImplementation(() => {});
  vi.spyOn(console, 'log').mockImplementation(() => {});
});
afterEach(() => {
  vi.restoreAllMocks();
});

describe('HealthJourneyPanel does not touch the removed profiles table (TC-026)', () => {
  it('publishing the final section writes to patient_profiles, never to profiles', async () => {
    render(
      <MemoryRouter>
        <HealthJourneyPanel patientId="fictional-patient-1" patientName="Fictional Patient" hasAllData={true} />
      </MemoryRouter>
    );

    // Wait for the journey to load and render its one unpublished section.
    const publishBtn = await screen.findByText('Publish to User');
    await act(async () => {
      publishBtn.click();
    });
    await waitFor(() => expect(tablesQueried).toContain('patient_profiles'));

    expect(tablesQueried).not.toContain('profiles');
  });
});
