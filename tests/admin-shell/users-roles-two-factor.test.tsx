// @vitest-environment jsdom
// TC-013 Ava M5: two-factor column shows a check icon + "On", or
// "Not set up yet" as secondary text with no icon.
// TC-018 item 5 (L37): list_org_members() now returns a real mfa_enrolled
// boolean for active members - the column must show the real state ("On"/
// "Off"), not always "Unknown".
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
    last_sign_in_at: '2026-10-30T00:00:00Z',
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
  {
    user_id: 'other-active-no-mfa',
    email: 'morgan.reyes@example.test',
    full_name: null,
    role: 'physician',
    status: 'active',
    created_at: '2026-10-20T00:00:00Z',
    updated_at: '2026-10-20T00:00:00Z',
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

describe('UsersRolesPage two-factor column', () => {
  it('"Not set up yet" renders as secondary text with no check icon', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());
    const text = screen.getByText('Not set up yet');
    expect(text.className).toMatch(/text-slate-500/);
    const cell = text.closest('td') as HTMLElement;
    expect(cell.querySelector('svg')).toBeNull();
  });

  it('shows "On" with a check icon for an active member with a verified factor', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());
    const row = screen.getByText('taylor.brooks@example.test').closest('tr') as HTMLElement;
    const text = within(row).getByText('On');
    expect(text.closest('td')?.querySelector('svg')).not.toBeNull();
  });

  it('shows the real "Off" state for an active member with no factor, not "Unknown"', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());
    const row = screen.getByText('morgan.reyes@example.test').closest('tr') as HTMLElement;
    expect(within(row).getByText('Off')).toBeInTheDocument();
    expect(within(row).queryByText('Unknown')).toBeNull();
  });
});
