// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

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

import UsersRolesPage from '../../pages/admin/UsersRoles';
import { ToastProvider } from '../../components/ui/Toast';

function renderPage() {
  return render(
    <ToastProvider>
      <UsersRolesPage />
    </ToastProvider>
  );
}

describe('UsersRolesPage', () => {
  beforeEach(() => vi.clearAllMocks());

  it('lists every member once loaded', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());
    expect(screen.getByLabelText('More actions for taylor.brooks@example.test (you)')).toBeInTheDocument();
    expect(screen.getByLabelText('More actions for morgan.ellis@example.test')).toBeInTheDocument();
  });

  it('shows a role select for other active members but plain text for yourself', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());

    expect(screen.getByLabelText('Change role for morgan.ellis@example.test')).toBeInTheDocument();
    expect(screen.queryByLabelText('Change role for taylor.brooks@example.test')).not.toBeInTheDocument();
    const nameCell = screen.getByText('Taylor Brooks (you)').closest('tr');
    expect(nameCell).not.toBeNull();
    expect(within(nameCell as HTMLElement).getByText('Admin')).toBeInTheDocument();
  });

  it("hides the ··· menu on the signed-in admin's own row, but shows Request two-factor reset and Deactivate via the menu on other rows", async () => {
    const user = userEvent.setup();
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());

    const selfRowActions = screen.getByLabelText('More actions for taylor.brooks@example.test (you)');
    expect(selfRowActions.querySelector('button')).toBeNull();

    await user.click(screen.getByLabelText('More actions for morgan.ellis@example.test'));
    const menu = screen.getByRole('menu');
    expect(within(menu).getByRole('menuitem', { name: 'Request two-factor reset' })).toBeInTheDocument();
    expect(within(menu).getByRole('menuitem', { name: 'Deactivate' })).toBeInTheDocument();
  });

  it('opens the invite dialog from the page header action', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());
    screen.getByRole('button', { name: 'Invite user' }).click();
    expect(await screen.findByText('Invite a user')).toBeInTheDocument();
  });
});
