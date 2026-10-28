// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

// Imported after the mock so RequireRole and AccessDenied resolve usePortalAuth to the mock.
import RequireRole from '../../components/admin-shell/RequireRole';

function renderWithRole(role: string | null, roles: string[]) {
  mockUsePortalAuth.mockReturnValue({ role });
  return render(
    <MemoryRouter>
      <RequireRole roles={roles}>
        <div>protected content</div>
      </RequireRole>
    </MemoryRouter>
  );
}

describe('RequireRole', () => {
  it.each(['physician', 'care_coordinator'])('renders children for an allowed role (%s)', (role) => {
    renderWithRole(role, ['physician', 'care_coordinator']);
    expect(screen.getByText('protected content')).toBeInTheDocument();
  });

  it.each(['org_admin', 'read_only', null])('renders 06-access-denied for a disallowed role (%s)', (role) => {
    renderWithRole(role, ['physician', 'care_coordinator']);
    expect(screen.queryByText('protected content')).not.toBeInTheDocument();
    expect(screen.getByText("You don't have access to this page")).toBeInTheDocument();
  });

  it('org_admin sees a "Go to users and roles" action, other roles see "Go to patients"', () => {
    renderWithRole('read_only', ['org_admin']);
    expect(screen.getByRole('button', { name: 'Go to patients' })).toBeInTheDocument();

    renderWithRole('org_admin', ['physician']);
    expect(screen.getByRole('button', { name: 'Go to users and roles' })).toBeInTheDocument();
  });
});
