// @vitest-environment jsdom
// TC-018 item 2 (L34): before sending an invite, check the members already
// on screen in the caller's own clinic (list_org_members() is already
// scoped to own-org) and show "Already a member of your clinic" instead of
// round-tripping to the server. The server's identical cross-clinic
// responses are unchanged - this is a client-only pre-check against data
// already on screen, so it can never be used to probe other clinics.
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

const MEMBERS = [
  {
    user_id: 'self-1',
    email: 'taylor.brooks@example.test',
    full_name: 'Taylor Brooks',
    role: 'org_admin',
    status: 'active',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
  {
    user_id: 'existing-1',
    email: 'sam.okafor@example.test',
    full_name: 'Sam Okafor',
    role: 'physician',
    status: 'active',
    created_at: '2026-01-02T00:00:00Z',
    updated_at: '2026-01-02T00:00:00Z',
  },
];

const inviteUser = vi.fn(async () => ({ ok: true }));

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => MEMBERS),
  inviteUser: (...args: unknown[]) => inviteUser(...args),
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

vi.mock('../../components/ui/Toast', () => ({
  useToast: () => ({ showToast: vi.fn() }),
}));

import UsersRolesPage from '../../pages/admin/UsersRoles';

describe('UsersRolesPage invite dialog already-a-member pre-check (TC-018 item 2, L34)', () => {
  beforeEach(() => {
    inviteUser.mockClear();
    inviteUser.mockResolvedValue({ ok: true });
  });

  it('shows "Already a member of your clinic" and never calls inviteUser for an on-screen email', async () => {
    const user = userEvent.setup();
    render(<UsersRolesPage />);
    await screen.findByRole('button', { name: /invite user/i });
    await user.click(screen.getByRole('button', { name: /invite user/i }));
    await user.type(screen.getByLabelText(/full name/i), 'Sam Okafor');
    // Case/whitespace-insensitive match against the on-screen roster.
    await user.type(screen.getByLabelText(/work email/i), ' Sam.Okafor@example.test ');
    await user.click(screen.getByRole('radio', { name: /physician/i }));
    await user.click(screen.getByRole('button', { name: /^send invite$/i }));
    expect(await screen.findByText('Already a member of your clinic.')).toBeTruthy();
    expect(inviteUser).not.toHaveBeenCalled();
  });

  it('still invites an email that is not already on the roster', async () => {
    const user = userEvent.setup();
    render(<UsersRolesPage />);
    await screen.findByRole('button', { name: /invite user/i });
    await user.click(screen.getByRole('button', { name: /invite user/i }));
    await user.type(screen.getByLabelText(/full name/i), 'Alex Lindgren');
    await user.type(screen.getByLabelText(/work email/i), 'alex.lindgren@example.test');
    await user.click(screen.getByRole('radio', { name: /physician/i }));
    await user.click(screen.getByRole('button', { name: /^send invite$/i }));
    expect(inviteUser).toHaveBeenCalledWith('alex.lindgren@example.test', 'physician', 'Alex Lindgren');
  });
});
