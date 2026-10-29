// @vitest-environment jsdom
// TC-022 item 2 (Clara, PR #11 review): going from a not-found patient to a
// valid one by URL, with no reload, must show the valid patient - notFound
// and detail have to reset when the :id param changes.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route, useNavigate } from 'react-router-dom';

import PhysicianPatientDetail from '../../pages/admin/clinic/PhysicianPatientDetail';
import { ClinicalApi, PatientDetail } from '../../lib/clinicalApi';

const NOW = new Date('2026-10-18T10:00:00Z');

const detailFor = (patientId: string, displayName: string): PatientDetail => ({
  patientId,
  displayName,
  mrn: 'ZP-00001',
  sex: 'female',
  birthDate: '1985-03-01',
  programStartedOn: '2026-04-02T00:00:00Z',
  lastActivityAt: '2026-10-18T09:12:00Z',
  treatment: null,
});

function makeApi(): ClinicalApi {
  return {
    fetchRoster: vi.fn(),
    fetchChipCounts: vi.fn(),
    openPatientDetail: vi.fn(async (id: string) => {
      if (id === 'p-jordan') return detailFor('p-jordan', 'Jordan Rivera');
      if (id === 'p-sam') return detailFor('p-sam', 'Sam Okafor');
      return null;
    }),
    fetchLatestResults: vi.fn().mockResolvedValue([]),
    fetchTrend: vi.fn().mockResolvedValue([]),
  } as unknown as ClinicalApi;
}

// In-app navigation (no reload) driven from outside the detail component.
const Nav: React.FC = () => {
  const navigate = useNavigate();
  return (
    <>
      <button onClick={() => navigate('/admin/patients/p-jordan')}>go jordan</button>
      <button onClick={() => navigate('/admin/patients/p-sam')}>go sam</button>
    </>
  );
};

function renderAt(path: string, api: ClinicalApi) {
  return render(
    <MemoryRouter initialEntries={[path]}>
      <Nav />
      <Routes>
        <Route path="/admin/patients/:id" element={<PhysicianPatientDetail api={api} now={NOW} />} />
      </Routes>
    </MemoryRouter>
  );
}

describe('PhysicianPatientDetail resets when the patient id changes (TC-022 #2)', () => {
  it('goes from not-found to a valid patient by URL without a reload', async () => {
    const api = makeApi();
    renderAt('/admin/patients/p-missing', api);
    expect(await screen.findByRole('heading', { name: "We can't show this patient" })).toBeInTheDocument();

    screen.getByRole('button', { name: 'go jordan' }).click();

    expect(await screen.findByRole('heading', { name: 'Jordan Rivera' })).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: "We can't show this patient" })).not.toBeInTheDocument();
    expect(api.openPatientDetail).toHaveBeenCalledWith('p-jordan');
  });

  it('goes from one valid patient to another without showing the old one', async () => {
    const api = makeApi();
    renderAt('/admin/patients/p-jordan', api);
    await screen.findByRole('heading', { name: 'Jordan Rivera' });

    screen.getByRole('button', { name: 'go sam' }).click();

    expect(await screen.findByRole('heading', { name: 'Sam Okafor' })).toBeInTheDocument();
    expect(screen.queryByRole('heading', { name: 'Jordan Rivera' })).not.toBeInTheDocument();
  });
});
