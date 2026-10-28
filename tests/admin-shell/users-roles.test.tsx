// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';

const MEMBERS = [
  {
    user_id: 'self-1',
    email: 'taylor.brooks@example.test',
    role: 'org_admin',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
  {
    user_id: 'other-1',
    email: 'morgan.ellis@example.test',
    role: 'physician',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
];

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => MEMBERS),
  inviteUser: vi.fn(async () => ({ ok: true })),
  changeMemberRole: vi.fn(async () => ({ ok: true })),
  deactivateUser: vi.fn(async () => ({ ok: true })),
  reactivateUser: vi.fn(async () => ({ ok: true })),
  requestMfaReset: vi.fn(async () => ({ ok: true })),
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

  it("hides reset-2fa and deactivate on the signed-in admin's own row, but shows them on other rows", async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());

    const selfRowActions = screen.getByLabelText('More actions for taylor.brooks@example.test (you)');
    expect(selfRowActions.querySelector('button')).toBeNull();

    const otherRowActions = screen.getByLabelText('More actions for morgan.ellis@example.test');
    expect(screen.getByRole('button', { name: 'Request 2FA reset' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Deactivate' })).toBeInTheDocument();
    expect(otherRowActions).toContainElement(screen.getByRole('button', { name: 'Deactivate' }));
  });

  it('opens the invite dialog from the page header action', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());
    screen.getByRole('button', { name: 'Invite user' }).click();
    expect(await screen.findByText('Invite a user')).toBeInTheDocument();
  });
});
