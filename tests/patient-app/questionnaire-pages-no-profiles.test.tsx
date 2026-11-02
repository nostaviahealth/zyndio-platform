// @vitest-environment jsdom
// TC-026 (Henry's 1 Nov scope update): the legacy patient web portal screens
// HealthQuestionnaire.tsx and LabTestUpload.tsx used to UPDATE the removed
// `profiles` table on submit. There is no replacement patient-profile table
// backing this legacy portal (TC-018 made UserContext.patientProfile
// permanently null), so the fix removes the dead write. Neither screen must
// ever query `profiles`, even when the submit handler runs to completion.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, act } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const tablesQueried = vi.hoisted(() => [] as string[]);

vi.mock('../../lib/supabase', () => {
  const from = (table: string) => {
    tablesQueried.push(table);
    const builder: Record<string, unknown> = {};
    for (const m of ['select', 'eq', 'order', 'limit', 'insert', 'update', 'delete', 'upsert', 'single', 'maybeSingle']) {
      builder[m] = () => builder;
    }
    builder.then = (resolve: (v: unknown) => unknown) => Promise.resolve({ data: null, error: null }).then(resolve);
    return builder;
  };
  return { supabase: { from } };
});

// Supply a non-null patientProfile so the submit handlers run past their
// `if (!patientProfile) return` guard - we are testing the data access of the
// screens, not the (now always-null) context.
const refreshProfile = vi.fn(async () => {});
vi.mock('../../contexts/UserContext', () => ({
  useUser: () => ({ patientProfile: { id: 'fictional-patient-1' }, refreshProfile }),
}));

import HealthQuestionnaire from '../../pages/HealthQuestionnaire';
import LabTestUpload from '../../pages/LabTestUpload';

beforeEach(() => {
  tablesQueried.length = 0;
  refreshProfile.mockClear();
});

describe('legacy patient questionnaire screens no longer touch the removed profiles table', () => {
  it('HealthQuestionnaire submit never queries profiles', async () => {
    const { container } = render(
      <MemoryRouter>
        <HealthQuestionnaire />
      </MemoryRouter>
    );

    // Step 1: valid basic info so submit-time validation can pass.
    fireEvent.change(screen.getByPlaceholderText('30'), { target: { value: '30' } });
    fireEvent.change(container.querySelector('select')!, { target: { value: 'male' } });
    fireEvent.change(screen.getByPlaceholderText('175'), { target: { value: '175' } });
    fireEvent.change(screen.getByPlaceholderText('70'), { target: { value: '70' } });

    // Advance to the final step and submit.
    fireEvent.click(screen.getByText('Next Step'));
    fireEvent.click(screen.getByText('Next Step'));
    fireEvent.click(screen.getByText('Next Step'));
    await act(async () => {
      fireEvent.click(screen.getByText('Submit'));
    });

    expect(tablesQueried).not.toContain('profiles');
  });

  it('LabTestUpload submit never queries profiles', async () => {
    const { container } = render(
      <MemoryRouter>
        <LabTestUpload />
      </MemoryRouter>
    );

    // Fill the fields that gate the submit button (age, gender, preferred date).
    fireEvent.change(screen.getByPlaceholderText('Enter your age'), { target: { value: '30' } });
    fireEvent.change(container.querySelector('select')!, { target: { value: 'male' } });
    fireEvent.change(container.querySelector('input[type="date"]')!, { target: { value: '2026-12-01' } });

    await act(async () => {
      fireEvent.click(screen.getByText('Submit Questionnaire'));
    });

    expect(tablesQueried).not.toContain('profiles');
  });
});
