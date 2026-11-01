// @vitest-environment jsdom
// TC-018 item 8 (L38): pluralise the member count ("1 person" / "0 people")
// and show a "No results" empty state with the search term when a search
// matches nothing, instead of a table with no rows and no explanation.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

const ONE_MEMBER = [
  {
    user_id: 'self-1',
    email: 'taylor.brooks@example.test',
    full_name: null,
    role: 'org_admin',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
];

const TWO_MEMBERS = [
  ...ONE_MEMBER,
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

const mockListOrgMembers = vi.fn();

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: (...args: unknown[]) => mockListOrgMembers(...args),
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

describe('UsersRolesPage member count + search-empty state (TC-018 item 8)', () => {
  beforeEach(() => vi.clearAllMocks());

  it('shows "1 person" (not "1 people") for a single member', async () => {
    mockListOrgMembers.mockResolvedValue(ONE_MEMBER);
    renderPage();
    await waitFor(() => expect(screen.getByText('1 person')).toBeInTheDocument());
    expect(screen.queryByText('1 people')).not.toBeInTheDocument();
  });

  it('shows a "No results" empty state naming the search term when nothing matches', async () => {
    const user = userEvent.setup();
    mockListOrgMembers.mockResolvedValue(TWO_MEMBERS);
    renderPage();
    await waitFor(() => expect(screen.getByText('2 people')).toBeInTheDocument());

    await user.type(screen.getByLabelText('Search by name or email'), 'nobody-like-this');

    await waitFor(() => expect(screen.getByText(/No results/)).toBeInTheDocument());
    expect(screen.getByText(/nobody-like-this/)).toBeInTheDocument();
    expect(screen.queryByLabelText('More actions for taylor.brooks@example.test (you)')).not.toBeInTheDocument();
    expect(screen.queryByLabelText('More actions for morgan.ellis@example.test')).not.toBeInTheDocument();
  });
});
