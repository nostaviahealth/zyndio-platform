// @vitest-environment jsdom
// TC-021 item 26 (Clara, PR #21 hands-on, roles.log): read_only saw the
// "New Patient" button on #/admin although /admin/patients/create is gated to
// physician + care_coordinator. The button is shown only to roles that can
// create patients. (org_admin is routed to /admin/users before AdminDashboard
// ever renders - TC-018 item 3, see admin-index-routing.test.tsx.)
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
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

function renderDashboard(role: string) {
  mockUseAdmin.mockReturnValue({ patients: [], deletePatient: vi.fn(), loading: false });
  mockUsePortalAuth.mockReturnValue({ role });
  return render(
    <MemoryRouter>
      <AdminDashboard />
    </MemoryRouter>
  );
}

describe('AdminDashboard "New Patient" button is role-gated (TC-021 item 26)', () => {
  it('read_only does not see "New Patient"', () => {
    renderDashboard('read_only');
    expect(screen.getByRole('heading', { name: 'Patient Management' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /New Patient/ })).not.toBeInTheDocument();
  });

  it.each(['physician', 'care_coordinator'])('%s still sees "New Patient"', (role) => {
    renderDashboard(role);
    expect(screen.getByRole('button', { name: /New Patient/ })).toBeInTheDocument();
  });
});
