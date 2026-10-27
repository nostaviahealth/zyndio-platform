// @vitest-environment jsdom
// TC-013 Ava M4: status is a badge (Active=success, Invited·N days
// left=brand, Deactivated=neutral), not plain text.
import React from 'react';
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor, within } from '@testing-library/react';

const NOW = Date.now();
const daysAgo = (n: number) => new Date(NOW - n * 24 * 60 * 60 * 1000).toISOString();

const MEMBERS = [
  {
    user_id: 'self-1',
    email: 'taylor.brooks@example.test',
    role: 'org_admin',
    status: 'active',
    created_at: daysAgo(30),
    updated_at: daysAgo(30),
  },
  {
    user_id: 'other-invited',
    email: 'sam.okafor@example.test',
    role: 'care_coordinator',
    status: 'invited',
    created_at: daysAgo(2),
    updated_at: daysAgo(2),
  },
  {
    user_id: 'other-deactivated',
    email: 'jamie.ortiz@example.test',
    role: 'care_coordinator',
    status: 'deactivated',
    created_at: daysAgo(60),
    updated_at: daysAgo(10),
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

describe('UsersRolesPage status badges', () => {
  it('renders Active, Invited · N days left, and Deactivated as badges, not plain text', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('3 people')).toBeInTheDocument());

    const activeRow = screen.getByText('Taylor Brooks (you)').closest('tr') as HTMLElement;
    const activeBadge = within(activeRow).getByText('Active');
    expect(activeBadge.className).toMatch(/rounded-full/);
    expect(activeBadge.className).toMatch(/emerald/);

    const invitedRow = screen.getByText('sam.okafor@example.test').closest('tr') as HTMLElement;
    const invitedBadge = within(invitedRow).getByText('Invited · 5 days left');
    expect(invitedBadge.className).toMatch(/rounded-full/);

    const deactivatedRow = screen.getByText('jamie.ortiz@example.test').closest('tr') as HTMLElement;
    const deactivatedBadge = within(deactivatedRow).getByText('Deactivated');
    expect(deactivatedBadge.className).toMatch(/rounded-full/);
    expect(deactivatedBadge.tagName).toBe('SPAN');
  });
});
