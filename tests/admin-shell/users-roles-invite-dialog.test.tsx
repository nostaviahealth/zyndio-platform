// @vitest-environment jsdom
import React from 'react';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
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
];

const inviteUser = vi.fn(async () => ({ ok: true }));
const cancelInvite = vi.fn(async () => ({ ok: true, email: 'sam.okafor@example.test' }));

vi.mock('../../lib/usersRolesApi', () => ({
  listOrgMembers: vi.fn(async () => MEMBERS),
  inviteUser: (...args: unknown[]) => inviteUser(...args),
  cancelInvite: (...args: unknown[]) => cancelInvite(...args),
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

describe('UsersRolesPage invite dialog (TC-014)', () => {
  beforeEach(() => {
    inviteUser.mockClear();
    inviteUser.mockResolvedValue({ ok: true });
  });

  it('shows validation errors when name, email and role are empty', async () => {
    const user = userEvent.setup();
    render(<UsersRolesPage />);
    await screen.findByRole('button', { name: /invite user/i });
    await user.click(screen.getByRole('button', { name: /invite user/i }));
    await user.click(screen.getByRole('button', { name: /^send invite$/i }));
    expect(await screen.findByText('Enter their full name.')).toBeTruthy();
    expect(screen.getByText('Enter a work email.')).toBeTruthy();
    expect(screen.getByText('Choose a role.')).toBeTruthy();
    expect(inviteUser).not.toHaveBeenCalled();
  });

  it('submits full_name, email and role together', async () => {
    const user = userEvent.setup();
    render(<UsersRolesPage />);
    await screen.findByRole('button', { name: /invite user/i });
    await user.click(screen.getByRole('button', { name: /invite user/i }));
    await user.type(screen.getByLabelText(/full name/i), 'Alex Lindgren');
    await user.type(screen.getByLabelText(/work email/i), 'alex.lindgren@example.test');
    await user.click(screen.getByRole('radio', { name: /physician/i }));
    await user.click(screen.getByRole('button', { name: /^send invite$/i }));
    await waitFor(() => expect(inviteUser).toHaveBeenCalled());
    expect(inviteUser.mock.calls[0][0]).toBe('alex.lindgren@example.test');
    expect(inviteUser.mock.calls[0][1]).toBe('physician');
    expect(inviteUser.mock.calls[0][2]).toBe('Alex Lindgren');
  });

  it('shows role refused inline error from the server', async () => {
    inviteUser.mockResolvedValueOnce({ ok: false, error: 'role_not_allowed' });
    const user = userEvent.setup();
    render(<UsersRolesPage />);
    await screen.findByRole('button', { name: /invite user/i });
    await user.click(screen.getByRole('button', { name: /invite user/i }));
    await user.type(screen.getByLabelText(/full name/i), 'Alex Lindgren');
    await user.type(screen.getByLabelText(/work email/i), 'alex.lindgren@example.test');
    await user.click(screen.getByRole('radio', { name: /admin/i }));
    await user.click(screen.getByRole('button', { name: /^send invite$/i }));
    expect(await screen.findByText(/You can't give this role/i)).toBeTruthy();
  });
});
