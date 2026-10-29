// @vitest-environment jsdom
// TC-019 M5 (Ava must-fix): at 1024px the page overflowed (1123px in a
// 1024px viewport), the role select shrank to 58px hiding the role name,
// Invite user and the actions column clipped off-screen, and the invited
// status badge wrapped to 4 lines. jsdom doesn't lay out real pixel widths,
// so this asserts the *classes* that produce the fix: main min-w-0, a role
// select minimum width, and whitespace-nowrap on the status badge.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

const MEMBERS = [
  {
    user_id: 'self-1',
    email: 'taylor.brooks@example.test',
    full_name: null,
    role: 'org_admin',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
  {
    user_id: 'other-1',
    email: 'morgan.ellis@example.test',
    full_name: null,
    role: 'physician',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
  {
    user_id: 'invited-1',
    email: 'sam.rivera@example.test',
    full_name: null,
    role: 'care_coordinator',
    status: 'invited',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  },
];

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => MEMBERS),
  inviteUser: vi.fn(async () => ({ ok: true })),
  cancelInvite: vi.fn(async () => ({ ok: true })),
  changeMemberRole: vi.fn(async () => ({ ok: true })),
  deactivateUser: vi.fn(async () => ({ ok: true })),
  reactivateUser: vi.fn(async () => ({ ok: true })),
  requestMfaReset: vi.fn(async () => ({ ok: true })),
  resetMfa: vi.fn(async () => ({ ok: true })),
  checkIsPlatformAdmin: vi.fn(async () => false),
}));

vi.mock('../../lib/supabase', () => ({
  supabase: {
    auth: { getUser: vi.fn(async () => ({ data: { user: { id: 'self-1' } } })) },
  },
}));

const mockUsePortalAuth = vi.fn();
vi.mock('../../contexts/PortalAuthContext', () => ({
  usePortalAuth: () => mockUsePortalAuth(),
}));

import UsersRolesPage from '../../pages/admin/UsersRoles';
import { ToastProvider } from '../../components/ui/Toast';
import AppShell from '../../components/admin-shell/AppShell';

describe('1024px layout fix (Ava M5)', () => {
  it('main column has min-w-0 so a wide table can shrink instead of overflowing the page', () => {
    mockUsePortalAuth.mockReturnValue({ role: 'org_admin', email: 'taylor@example.test', signOut: vi.fn() });
    const { container } = render(
      <MemoryRouter>
        <AppShell />
      </MemoryRouter>
    );
    const main = container.querySelector('main');
    expect(main).toBeTruthy();
    expect(main!.className).toMatch(/\bmin-w-0\b/);
  });

  it('role select has a usable minimum width so the role name stays visible', async () => {
    render(
      <ToastProvider>
        <UsersRolesPage />
      </ToastProvider>
    );
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());
    const select = screen.getByLabelText('Change role for morgan.ellis@example.test');
    const wrapper = select.closest('div');
    expect(wrapper).toBeTruthy();
    expect(wrapper!.className).toMatch(/min-w-\[168px\]/);
  });

  it('the table scrolls inside its card and the actions column is pinned right, so ⋯ stays visible at 1024', async () => {
    render(
      <ToastProvider>
        <UsersRolesPage />
      </ToastProvider>
    );
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());
    const table = screen.getByRole('table', { name: 'Users and roles' });
    expect(table.parentElement!.className).toMatch(/\boverflow-x-auto\b/);
    const trigger = screen.getByRole('button', { name: /More actions for morgan\.ellis@example\.test/ });
    const cell = trigger.closest('td')!;
    expect(cell.className).toMatch(/\bsticky\b/);
    expect(cell.className).toMatch(/\bright-0\b/);
    // Opaque in both themes so scrolled cells don't show through.
    expect(cell.className).toMatch(/\bbg-white\b/);
    expect(cell.className).toMatch(/dark:bg-\[#10141F\]/);
    const headers = screen.getAllByRole('columnheader');
    const actionsHeader = headers[headers.length - 1];
    expect(actionsHeader.className).toMatch(/\bsticky\b/);
    expect(actionsHeader.className).toMatch(/\bright-0\b/);
  });

  it('the invited status badge is whitespace-nowrap so it stays on one line', async () => {
    render(
      <ToastProvider>
        <UsersRolesPage />
      </ToastProvider>
    );
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());
    const badge = screen.getByText(/Invited · \d+ days left/);
    expect(badge.className).toMatch(/whitespace-nowrap/);
  });
});
