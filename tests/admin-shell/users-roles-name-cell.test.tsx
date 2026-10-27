// @vitest-environment jsdom
// TC-013 Ava M6: Name cell shows avatar initials + name + email stacked in
// one cell; there is no separate Email column.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';

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

describe('UsersRolesPage name cell', () => {
  it('shows avatar initials, name, and email stacked, with no separate Email column header', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());

    expect(screen.getByText('Morgan Ellis')).toBeInTheDocument();
    expect(screen.getByText('morgan.ellis@example.test')).toBeInTheDocument();
    expect(screen.getByText('ME')).toBeInTheDocument();

    expect(screen.getByText('Taylor Brooks (you)')).toBeInTheDocument();
    expect(screen.getByText('TB')).toBeInTheDocument();

    expect(screen.queryByRole('columnheader', { name: 'Email' })).not.toBeInTheDocument();
  });
});
