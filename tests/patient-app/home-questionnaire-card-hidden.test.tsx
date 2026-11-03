// @vitest-environment jsdom
// TC-030 (10): with the legacy patient screens hidden
// (VITE_FEATURE_LEGACY_PATIENT_SCREENS off), the patient Home onboarding
// "Complete Your Health Questionnaire" card is a dead end - there is no
// questionnaire to open - so the whole card is hidden, not shown button-less.
//
// Fail-first: before the fix the onboarding block always renders the next-action
// card (title "Complete Your Health Questionnaire") regardless of the flag; the
// flag only stripped the button. The "flag off -> card absent" assertion below
// goes red on the old code.
import React from 'react';
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

vi.mock('../../lib/supabase', () => ({ supabase: {} }));
const mockUseUser = vi.fn();
vi.mock('../../contexts/UserContext', () => ({ useUser: () => mockUseUser() }));
vi.mock('../../contexts/AuthContext', () => ({ useAuth: () => ({ user: { id: 'fictional-user-1' } }) }));

import Home from '../../pages/Home';

const FLAG = 'VITE_FEATURE_LEGACY_PATIENT_SCREENS';
const CARD_TITLE = 'Complete Your Health Questionnaire';

const baseUser = {
  loading: false,
  publishedIntelligence: null,
  publishedJourney: null,
  hasAnyPublishedContent: () => false,
  currentPhase: null,
  getProtocolSection: () => null,
};

afterEach(() => {
  vi.unstubAllEnvs();
  vi.clearAllMocks();
});

describe('TC-030 10: Home "Complete Your Health Questionnaire" card', () => {
  it.each(['questionnaire_pending', 'profile_creation'])(
    'flag off (%s): the questionnaire card is absent',
    (stage) => {
      mockUseUser.mockReturnValue({ ...baseUser, patientProfile: { id: 'fictional-patient-1', stage } });
      render(<MemoryRouter><Home /></MemoryRouter>);
      expect(screen.queryByText(CARD_TITLE)).not.toBeInTheDocument();
    }
  );

  it('flag on: the questionnaire card is present', () => {
    vi.stubEnv(FLAG, 'true');
    mockUseUser.mockReturnValue({
      ...baseUser,
      patientProfile: { id: 'fictional-patient-1', stage: 'questionnaire_pending' },
    });
    render(<MemoryRouter><Home /></MemoryRouter>);
    expect(screen.getByText(CARD_TITLE)).toBeInTheDocument();
  });

  it('flag off: a non-questionnaire onboarding card still renders (only the dead card is hidden)', () => {
    // lab_processing -> "Lab Results Processing", route null, not a legacy path.
    mockUseUser.mockReturnValue({
      ...baseUser,
      patientProfile: { id: 'fictional-patient-1', stage: 'lab_processing' },
    });
    render(<MemoryRouter><Home /></MemoryRouter>);
    expect(screen.getByText('Lab Results Processing')).toBeInTheDocument();
  });
});
