// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, afterEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const mockUseAdmin = vi.fn();
vi.mock('../../contexts/AdminContext', () => ({
  useAdmin: () => mockUseAdmin(),
}));

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

import AdminDashboard from '../../pages/admin/AdminDashboard';

const patient = {
  id: 'p1',
  name: 'Jordan Rivera',
  email: 'jordan.rivera@example.test',
  phone: '555-0100',
  age: 41,
  bioAge: 39,
  stage: 'protocol_ready' as const,
};

function renderDashboard(role: string) {
  mockUseAdmin.mockReturnValue({ patients: [patient], deletePatient: vi.fn(), loading: false });
  mockUsePortalAuth.mockReturnValue({ role });
  return render(
    <MemoryRouter>
      <AdminDashboard />
    </MemoryRouter>
  );
}

afterEach(() => {
  vi.unstubAllEnvs();
});

describe('AdminDashboard patient list - read_only gating (OVERRIDES #11)', () => {
  it('read_only rows are not links: no "View Details" action', () => {
    renderDashboard('read_only');
    expect(screen.queryByText(/View Details/)).not.toBeInTheDocument();
    expect(screen.getByText('View only')).toBeInTheDocument();
  });

  // TC-026: the legacy patient detail page is behind
  // VITE_FEATURE_LEGACY_PATIENT_SCREENS (off by default; the flag-off case is
  // covered in tests/feature-flags/legacy-patient-screens-flag.test.tsx).
  it('physician/care_coordinator rows stay links to the patient detail page (legacy flag on)', () => {
    vi.stubEnv('VITE_FEATURE_LEGACY_PATIENT_SCREENS', 'true');
    renderDashboard('physician');
    expect(screen.getByText(/View Details/)).toBeInTheDocument();
  });
});
