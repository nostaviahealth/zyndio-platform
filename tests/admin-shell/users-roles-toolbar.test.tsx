// @vitest-environment jsdom
// TC-013 Ava L8: search field has a leading search icon in a pill shape,
// and the Invite user button has a + icon.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
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
];

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => MEMBERS),
  inviteUser: vi.fn(async () => ({ ok: true })),
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

describe('UsersRolesPage toolbar', () => {
  it('search field is a pill with a leading icon, and Invite user has a + icon', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('1 people')).toBeInTheDocument());

    const search = screen.getByLabelText('Search by name or email');
    expect(search.className).toMatch(/rounded-full/);
    const searchWrapper = search.parentElement as HTMLElement;
    expect(searchWrapper.querySelector('svg')).not.toBeNull();

    const inviteButton = screen.getByRole('button', { name: /Invite user/ });
    expect(inviteButton.querySelector('svg')).not.toBeNull();
  });
});
