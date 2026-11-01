// @vitest-environment jsdom
// TC-018 item 3 (L35): #/admin is the shell's index route, gated today to
// physician/care_coordinator/read_only only (see require-role.test.tsx) - an
// org admin sign-in lands here first and sees 06-access-denied before ever
// reaching their real home. #/admin must resolve to the default route for
// the signed-in user's role instead, so a clinic's own admin never sees
// "You don't have access" just from signing in.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

const mockUseAdmin = vi.fn();
vi.mock('../../contexts/AdminContext', () => ({
  useAdmin: () => mockUseAdmin(),
}));

// Imported after the mocks so AdminIndex and its children resolve to them.
import AdminIndex from '../../components/admin-shell/AdminIndex';

function renderAt(role: string) {
  mockUseAdmin.mockReturnValue({ patients: [], deletePatient: vi.fn(), loading: false });
  mockUsePortalAuth.mockReturnValue({ role });
  return render(
    <MemoryRouter initialEntries={['/admin']}>
      <Routes>
        <Route path="/admin" element={<AdminIndex />} />
        <Route path="/admin/users" element={<div>USERS AND ROLES PAGE</div>} />
      </Routes>
    </MemoryRouter>
  );
}

describe('#/admin index routing by role (TC-018 item 3)', () => {
  it('org_admin never sees "You don\'t have access" - it lands on users and roles', () => {
    renderAt('org_admin');
    expect(screen.queryByText("You don't have access to this page")).not.toBeInTheDocument();
    expect(screen.getByText('USERS AND ROLES PAGE')).toBeInTheDocument();
  });

  it.each(['physician', 'care_coordinator', 'read_only'])('%s still sees the admin dashboard at #/admin', (role) => {
    renderAt(role);
    expect(screen.getByRole('heading', { name: 'Patient Management' })).toBeInTheDocument();
  });
});
