// @vitest-environment jsdom
// TC-018 item 5 (L37): list_org_members() now returns last_sign_in_at -
// the column must show "Never" for a member with no sign-in and a real
// date otherwise, not always "Unknown".
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';

const MEMBERS = [
  {
    user_id: 'self-1',
    email: 'taylor.brooks@example.test',
    full_name: null,
    role: 'org_admin',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    mfa_enrolled: true,
    last_sign_in_at: '2026-10-30T12:00:00Z',
  },
  {
    user_id: 'other-active-never',
    email: 'morgan.reyes@example.test',
    full_name: null,
    role: 'physician',
    status: 'active',
    created_at: '2026-10-20T00:00:00Z',
    updated_at: '2026-10-20T00:00:00Z',
    mfa_enrolled: false,
    last_sign_in_at: null,
  },
  {
    user_id: 'other-invited',
    email: 'sam.okafor@example.test',
    full_name: null,
    role: 'care_coordinator',
    status: 'invited',
    created_at: '2026-10-25T00:00:00Z',
    updated_at: '2026-10-25T00:00:00Z',
    mfa_enrolled: false,
    last_sign_in_at: null,
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

describe('UsersRolesPage last sign-in column', () => {
  it('shows "Never" for an invited member', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());
    const row = screen.getByText('sam.okafor@example.test').closest('tr') as HTMLElement;
    expect(within(row).getByText('Never')).toBeInTheDocument();
  });

  it('shows "Never" for an active member who has never signed in, not "Unknown"', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());
    const row = screen.getByText('morgan.reyes@example.test').closest('tr') as HTMLElement;
    expect(within(row).getByText('Never')).toBeInTheDocument();
    expect(within(row).queryByText('Unknown')).toBeNull();
  });

  it('shows the real last-sign-in date for an active member, not "Unknown"', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());
    const row = screen.getByText('taylor.brooks@example.test').closest('tr') as HTMLElement;
    const expected = new Date('2026-10-30T12:00:00Z').toLocaleDateString();
    expect(within(row).getByText(expected)).toBeInTheDocument();
    expect(within(row).queryByText('Unknown')).toBeNull();
  });
});
