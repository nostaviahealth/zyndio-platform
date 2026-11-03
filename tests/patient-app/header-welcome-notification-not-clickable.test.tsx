// @vitest-environment jsdom
// TC-030 (11, React part): with the legacy screens hidden, the patient header's
// "Welcome to Zyndio" notification has no action. It must not LOOK tappable -
// no pointer cursor, no hover highlight, no button role - and its copy must not
// tell the patient to "complete your health questionnaire" (there is no
// questionnaire to open).
//
// Fail-first: before the fix the notification row hard-coded `cursor-pointer
// hover:bg-slate-50` and an onClick for every notification, and the welcome
// copy always read "Complete your health questionnaire...". The no-pointer /
// no-questionnaire assertions below go red on the old code.
import React from 'react';
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const mockUseUser = vi.fn();
vi.mock('../../contexts/UserContext', () => ({ useUser: () => mockUseUser() }));

import Header from '../../components/Header';

const FLAG = 'VITE_FEATURE_LEGACY_PATIENT_SCREENS';

const baseUser = {
  publishedIntelligence: { published: true }, // avoid the "analysis in progress" extra
  publishedJourney: null,
  hasAnyPublishedContent: () => false,
  patientProfile: { stage: 'profile_creation' },
};

afterEach(() => {
  vi.unstubAllEnvs();
  vi.clearAllMocks();
});

function openNotifications() {
  mockUseUser.mockReturnValue(baseUser);
  render(
    <MemoryRouter>
      <Header title="Home" />
    </MemoryRouter>
  );
  fireEvent.click(screen.getAllByRole('button')[0]); // the notification bell
}

describe('TC-030 11: "Welcome to Zyndio" notification with no action', () => {
  it('flag off: the welcome row is not clickable (no pointer cursor, no button role)', () => {
    openNotifications();
    const title = screen.getByText('Welcome to Zyndio');
    // Walk up to the notification row container.
    const row = title.closest('div.p-4');
    expect(row).not.toBeNull();
    expect(row!.className).not.toMatch(/cursor-pointer/);
    expect(row!.className).not.toMatch(/hover:bg-slate-50/);
    expect(row!.getAttribute('role')).toBeNull();
  });

  it('flag off: the welcome copy drops the questionnaire call to action', () => {
    openNotifications();
    expect(screen.getByText('Welcome to Zyndio')).toBeInTheDocument();
    expect(screen.queryByText(/complete your health questionnaire/i)).not.toBeInTheDocument();
  });

  it('flag on: the welcome row is clickable again (it links to the questionnaire)', () => {
    vi.stubEnv(FLAG, 'true');
    openNotifications();
    const row = screen.getByText('Welcome to Zyndio').closest('div.p-4');
    expect(row!.className).toMatch(/cursor-pointer/);
    expect(row!.getAttribute('role')).toBe('button');
  });
});
