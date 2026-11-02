// @vitest-environment jsdom
// TC-026 (Henry's 1 Nov scope update): NutritionLab.loadPatientContext used to
// read `profiles.questionnaire_data, lab_report_url` by patient id. The
// `profiles` table is gone; the clinical, org-scoped replacement is
// `patient_profiles` (data jsonb, staff RLS). The screen must read from there
// and never query `profiles`.
import React from 'react';
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const tablesQueried = vi.hoisted(() => [] as string[]);

vi.mock('../../lib/supabase', () => {
  const from = (table: string) => {
    tablesQueried.push(table);
    const builder: Record<string, unknown> = {};
    for (const m of ['select', 'eq', 'order', 'limit', 'insert', 'update', 'delete', 'upsert']) {
      builder[m] = () => builder;
    }
    const result = { data: null, error: null };
    builder.single = () => Promise.resolve(result);
    builder.maybeSingle = () => Promise.resolve(result);
    builder.then = (resolve: (v: unknown) => unknown) => Promise.resolve({ data: [], error: null }).then(resolve);
    return builder;
  };
  return { supabase: { from } };
});

// Provide a found patient so the mount effect runs loadPatientContext.
vi.mock('../../contexts/AdminContext', () => ({
  useAdmin: () => ({
    getPatient: () => ({ id: 'fictional-patient-1', name: 'Fictional Patient' }),
  }),
}));

import NutritionLab from '../../pages/admin/NutritionLab';

beforeEach(() => {
  tablesQueried.length = 0;
  vi.spyOn(console, 'error').mockImplementation(() => {});
  vi.spyOn(console, 'log').mockImplementation(() => {});
});
afterEach(() => {
  vi.restoreAllMocks();
});

describe('NutritionLab does not touch the removed profiles table (TC-026)', () => {
  it('reads patient context from patient_profiles, never from profiles', async () => {
    render(
      <MemoryRouter initialEntries={['/admin/nutrition?patient=fictional-patient-1']}>
        <NutritionLab />
      </MemoryRouter>
    );

    await waitFor(() => expect(tablesQueried.length).toBeGreaterThan(0));
    await new Promise((r) => setTimeout(r, 50));

    expect(tablesQueried).not.toContain('profiles');
    expect(tablesQueried).toContain('patient_profiles');
  });
});
