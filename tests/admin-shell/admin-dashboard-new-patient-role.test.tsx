// @vitest-environment jsdom
// TC-029 (a): the "New Patient" create-patient button used to live on the old
// Patient Management page (AdminDashboard, now retired), gated to physician +
// care_coordinator - which is the bug Ava reported: a physician must never see
// a create-patient button. The button now lives in the header of the real
// roster (PhysicianRoster, /admin/patients), gated to care_coordinator only.
// This is the TC-021-item-26 role-gate guarantee, moved to where the button
// now lives and strengthened (physician is now excluded, not allowed).
//
// Fail-first: on the pre-fix roster there is no "New Patient" button at all,
// so the care_coordinator case ("sees New Patient") goes red; and on the old
// AdminDashboard the physician case would have been green (button shown) -
// i.e. this file's physician assertion is strictly stronger than before.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

vi.mock('../../contexts/PortalAuthContext', () => ({
  // role comes from the explicit `role` prop in these tests; auth is unused.
  usePortalAuth: () => ({ role: null }),
}));

import PhysicianRoster from '../../pages/admin/clinic/PhysicianRoster';
import { ClinicalApi, RosterPatient } from '../../lib/clinicalApi';

const NOW = new Date('2026-10-18T10:00:00Z');

const jordan: RosterPatient = {
  patientId: 'p-jordan',
  displayName: 'Jordan Rivera',
  mrn: 'ZP-10482',
  sex: 'female',
  birthDate: '1985-03-01',
  programStartedOn: '2026-04-02T00:00:00Z',
  latestLabAt: '2026-10-14T12:00:00Z',
  lastActivityAt: '2026-10-18T09:12:00Z',
  openQuestions: 1,
  flags: ['question_waiting'],
};

function makeApi(): ClinicalApi {
  return {
    fetchRoster: vi.fn().mockResolvedValue({ rows: [jordan], totalCount: 1 }),
    fetchChipCounts: vi.fn().mockResolvedValue({ all: 1, flagged: 0, missingLabs: 0, questionsWaiting: 1 }),
    openPatientDetail: vi.fn(),
    fetchLatestResults: vi.fn(),
    fetchTrend: vi.fn(),
  };
}

function renderRoster(role: string) {
  return render(
    <MemoryRouter>
      <PhysicianRoster api={makeApi()} now={NOW} role={role} />
    </MemoryRouter>
  );
}

describe('PhysicianRoster "New Patient" button is role-gated (TC-029 a, was TC-021 item 26)', () => {
  it('care_coordinator sees "New Patient" linking to the create page', () => {
    renderRoster('care_coordinator');
    const link = screen.getByRole('link', { name: /New Patient/ });
    expect(link).toHaveAttribute('href', '/admin/patients/create');
  });

  it.each(['physician', 'read_only'])('%s does not see "New Patient"', (role) => {
    renderRoster(role);
    expect(screen.getByRole('heading', { name: 'Patients' })).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /New Patient/ })).not.toBeInTheDocument();
  });
});
