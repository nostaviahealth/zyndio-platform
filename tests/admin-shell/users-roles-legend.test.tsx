// @vitest-environment jsdom
// TC-013 Ava M7: role legend is 4 columns in one row with a "Draft, to
// confirm with Zyndio" badge, not an inline parenthetical in a 2x2 grid.
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

describe('UsersRolesPage role legend', () => {
  it('renders the legend as a 4-column grid with a standalone Draft badge', async () => {
    renderPage();
    await waitFor(() => expect(screen.getByText('1 people')).toBeInTheDocument());

    expect(screen.queryByText('(Draft, to confirm with Zyndio)')).not.toBeInTheDocument();
    const badge = screen.getByText('Draft, to confirm with Zyndio');
    expect(badge.className).toMatch(/rounded-full/);

    const dl = screen.getByText('Physician').closest('dl');
    expect(dl).not.toBeNull();
    expect((dl as HTMLElement).className).toMatch(/lg:grid-cols-4/);
  });
});
