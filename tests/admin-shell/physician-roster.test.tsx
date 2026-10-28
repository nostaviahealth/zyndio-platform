// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

vi.mock('../../contexts/PortalAuthContext', () => ({
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

function makeApi(over: Partial<ClinicalApi> = {}): ClinicalApi {
  return {
    fetchRoster: vi.fn().mockResolvedValue({ rows: [jordan], totalCount: 42 }),
    fetchChipCounts: vi.fn().mockResolvedValue({ all: 42, flagged: 6, missingLabs: 9, questionsWaiting: 3 }),
    openPatientDetail: vi.fn(),
    fetchLatestResults: vi.fn(),
    fetchTrend: vi.fn(),
    ...over,
  };
}

function renderRoster(props: Partial<React.ComponentProps<typeof PhysicianRoster>> = {}) {
  return render(
    <MemoryRouter>
      <PhysicianRoster api={makeApi()} now={NOW} role="physician" {...props} />
    </MemoryRouter>
  );
}

describe('PhysicianRoster', () => {
  it('renders the default state: header, chips with counts, pagination, computed cells', async () => {
    renderRoster();
    expect(await screen.findByRole('radio', { name: /All/ })).toHaveTextContent('42');
    expect(screen.getByText('Jordan Rivera')).toBeInTheDocument();
    expect(screen.getByText('ZP-10482')).toBeInTheDocument();
    expect(screen.getByText('41 · F')).toBeInTheDocument();
    expect(screen.getByText('Week 28')).toBeInTheDocument();
    expect(screen.getByText('Today, 9:12 AM')).toBeInTheDocument();
    expect(screen.getByText('Showing 1–1 of 42')).toBeInTheDocument();
  });

  it('whole row is a link named "Open <name>" for physician/care_coordinator', async () => {
    renderRoster({ role: 'physician' });
    const link = await screen.findByRole('link', { name: 'Open Jordan Rivera' });
    expect(link).toHaveAttribute('href', '/admin/roster/p-jordan');
  });

  it('read_only rows are NOT links (Henry 26 Oct)', async () => {
    renderRoster({ role: 'read_only' });
    await screen.findByText('Jordan Rivera');
    expect(screen.queryByRole('link', { name: 'Open Jordan Rivera' })).not.toBeInTheDocument();
  });

  it('shows the no-results state with the query kept and a Clear button', async () => {
    const api = makeApi({ fetchRoster: vi.fn().mockResolvedValue({ rows: [], totalCount: 0 }) });
    render(
      <MemoryRouter>
        <PhysicianRoster api={api} now={NOW} role="physician" initialSearch="Rivra" />
      </MemoryRouter>
    );
    expect(await screen.findByText('No patients match "Rivra"')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Clear search' })).toBeInTheDocument();
  });

  it('shows the empty-roster state (no search, no flags, total 0) with no chips', async () => {
    const api = makeApi({
      fetchRoster: vi.fn().mockResolvedValue({ rows: [], totalCount: 0 }),
      fetchChipCounts: vi.fn().mockResolvedValue({ all: 0, flagged: 0, missingLabs: 0, questionsWaiting: 0 }),
    });
    render(
      <MemoryRouter>
        <PhysicianRoster api={api} now={NOW} role="physician" />
      </MemoryRouter>
    );
    expect(await screen.findByText('No patients yet')).toBeInTheDocument();
    expect(screen.queryByRole('radio', { name: /All/ })).not.toBeInTheDocument();
  });

  it('filtered (questions_waiting) shows the explanatory line', async () => {
    renderRoster({ initialFilter: 'questions_waiting', initialSort: 'questions_waiting' });
    expect(
      await screen.findByText(/companion question that needs a reply from the care team, oldest first/)
    ).toBeInTheDocument();
  });

  it('error state shows the banner + Try again and keeps the toolbar', async () => {
    const fetchRoster = vi.fn().mockRejectedValueOnce(new Error('boom')).mockResolvedValue({ rows: [jordan], totalCount: 42 });
    render(
      <MemoryRouter>
        <PhysicianRoster api={makeApi({ fetchRoster })} now={NOW} role="physician" />
      </MemoryRouter>
    );
    expect(await screen.findByText(/We couldn't load your patients/)).toBeInTheDocument();
    expect(screen.getByLabelText('Search by name or patient ID')).toBeInTheDocument();
    fireEvent.click(screen.getByRole('button', { name: 'Try again' }));
    await waitFor(() => expect(screen.getByText('Jordan Rivera')).toBeInTheDocument());
  });
});
