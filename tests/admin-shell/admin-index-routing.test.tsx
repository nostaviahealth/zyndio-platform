// @vitest-environment jsdom
// TC-029 (a): #/admin is the app shell's index route. It used to render the
// old "Patient Management" page (AdminDashboard) for every clinical role, so
// coordinators and physicians landed on an empty roster with a stray "New
// Patient" button; the real roster is /admin/patients. The index now
// redirects each signed-in role to its own home (the same targets the Sidebar
// nav links to). This asserts the landing route per role, one case each.
//
// Fail-first: on the pre-fix AdminIndex (RequireRole(['physician',
// 'care_coordinator','read_only']) wrapping AdminDashboard) the three clinical
// roles render "Patient Management" in place instead of redirecting to
// /admin/patients, so each physician/care_coordinator/read_only case here goes
// red. (org_admin already redirected pre-fix.)
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

// Imported after the mock so AdminIndex (and AccessDenied, used for the
// unknown-role fallback) resolve usePortalAuth to the mock.
import AdminIndex from '../../components/admin-shell/AdminIndex';

function renderAt(role: string | null) {
  mockUsePortalAuth.mockReturnValue({ role });
  return render(
    <MemoryRouter initialEntries={['/admin']}>
      <Routes>
        <Route path="/admin" element={<AdminIndex />} />
        <Route path="/admin/users" element={<div>USERS AND ROLES PAGE</div>} />
        <Route path="/admin/patients" element={<div>PATIENTS ROSTER PAGE</div>} />
      </Routes>
    </MemoryRouter>
  );
}

describe('#/admin index routing by role (TC-029 a)', () => {
  it('org_admin lands on Users and roles', () => {
    renderAt('org_admin');
    expect(screen.getByText('USERS AND ROLES PAGE')).toBeInTheDocument();
    expect(screen.queryByText("You don't have access to this page")).not.toBeInTheDocument();
  });

  it.each(['physician', 'care_coordinator', 'read_only'])(
    '%s lands on the real patients roster (/admin/patients), not the old Patient Management page',
    (role) => {
      renderAt(role);
      expect(screen.getByText('PATIENTS ROSTER PAGE')).toBeInTheDocument();
      expect(screen.queryByText('Patient Management')).not.toBeInTheDocument();
    }
  );

  it('an unknown/absent role falls through to 06-access-denied, not a roster it cannot open', () => {
    renderAt(null);
    expect(screen.getByText("You don't have access to this page")).toBeInTheDocument();
    expect(screen.queryByText('PATIENTS ROSTER PAGE')).not.toBeInTheDocument();
    expect(screen.queryByText('USERS AND ROLES PAGE')).not.toBeInTheDocument();
  });
});
